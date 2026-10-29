-- ============================================
-- IMPROVEMENTS (teacher feedback): triggers and business logic
-- A trigger = SQL that MySQL runs BY ITSELF when something happens
-- to a table (for example: a new line is added to order_details).
--
-- What this file adds:
--   1. Two new columns on customers: total_spent and customer_tier
--   2. Trigger: check the stock BEFORE an order line is saved
--   3. Trigger: AFTER an order line is saved -> reduce stock,
--      write the history, add to the order total
--   4. Trigger: when an order total changes -> update the
--      customer's total_spent and tier
--   5. A simpler add_product_to_order (the triggers do the work now)
--   6. restock_product: refill ONE product when a delivery arrives
--   7. Gold customers who have purchased (view)
--   8. Index on customer_tier
--
-- Tiers (RWF):  Gold   = 2000 or more
--               Silver = 500 to 1999
--               Bronze = less than 500 (or no orders yet)
--
-- Run this file ONLY ONCE, after files 01 to 11
-- (the new columns and the index can only be added once).
-- ============================================

USE inventory_db;

-- ============================================
-- 1. New columns on customers
-- total_spent   = all the money this customer has spent
-- customer_tier = Gold, Silver or Bronze
-- ============================================
ALTER TABLE customers
ADD COLUMN total_spent   DECIMAL(10,2) NOT NULL DEFAULT 0,
ADD COLUMN customer_tier VARCHAR(10)   NOT NULL DEFAULT 'Bronze';

-- Fill the new columns ONE time for the orders that already exist
-- (WHERE customer_id > 0 = all customers; Workbench safe mode needs a key in WHERE)
UPDATE customers
SET total_spent = (
    SELECT IFNULL(SUM(orders.total_amount), 0)
    FROM orders
    WHERE orders.customer_id = customers.customer_id
)
WHERE customer_id > 0;

UPDATE customers
SET customer_tier = CASE
        WHEN total_spent >= 2000 THEN 'Gold'
        WHEN total_spent >= 500  THEN 'Silver'
        ELSE 'Bronze'
    END
WHERE customer_id > 0;

SELECT customer_id, customer_name, total_spent, customer_tier FROM customers;

-- ============================================
-- 2. Trigger: check the stock BEFORE an order line is saved
-- If the stock is too small, SIGNAL stops the INSERT with an error,
-- so nothing is saved. This protects the data even when someone
-- types an INSERT by hand (without the procedure).
-- ============================================
DROP TRIGGER IF EXISTS check_stock_before_order_line;

DELIMITER $$

CREATE TRIGGER check_stock_before_order_line
BEFORE INSERT ON order_details
FOR EACH ROW
BEGIN
    DECLARE v_stock INT;

    -- NEW = the line that is about to be saved
    SELECT stock_quantity
    INTO v_stock
    FROM products
    WHERE product_id = NEW.product_id;

    IF v_stock < NEW.quantity THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Not enough stock';
    END IF;
END$$

DELIMITER ;

-- ============================================
-- 3. Trigger: AFTER an order line is saved
--    a) reduce the stock
--    b) write the change in the history (negative = stock went down)
--    c) add this line to the order total (business logic: total_amount)
-- ============================================
DROP TRIGGER IF EXISTS update_after_order_line;

DELIMITER $$

CREATE TRIGGER update_after_order_line
AFTER INSERT ON order_details
FOR EACH ROW
BEGIN
    -- a) reduce the stock
    UPDATE products
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE product_id = NEW.product_id;

    -- b) history
    INSERT INTO inventory_logs (product_id, quantity_change, change_type)
    VALUES (NEW.product_id, -NEW.quantity, 'ORDER');

    -- c) order total = old total + (quantity x price of this line)
    UPDATE orders
    SET total_amount = total_amount + (NEW.quantity * NEW.unit_price)
    WHERE order_id = NEW.order_id;
END$$

DELIMITER ;

-- ============================================
-- 4. Trigger: when an order total changes,
--    update the customer's total_spent and tier
-- OLD = the order before the change, NEW = the order after
-- ============================================
DROP TRIGGER IF EXISTS update_customer_after_order;

DELIMITER $$

CREATE TRIGGER update_customer_after_order
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    -- add only the difference (new total - old total)
    UPDATE customers
    SET total_spent = total_spent + (NEW.total_amount - OLD.total_amount)
    WHERE customer_id = NEW.customer_id;

    -- choose the tier again with the new total_spent
    UPDATE customers
    SET customer_tier = CASE
            WHEN total_spent >= 2000 THEN 'Gold'
            WHEN total_spent >= 500  THEN 'Silver'
            ELSE 'Bronze'
        END
    WHERE customer_id = NEW.customer_id;
END$$

DELIMITER ;

-- ============================================
-- 5. Simpler add_product_to_order
-- Same checks as before (quantity, product found, enough stock),
-- but now it only INSERTS the line: the triggers do the rest.
-- (If I kept the old version, the stock would go down TWICE.)
-- ============================================
DROP PROCEDURE IF EXISTS add_product_to_order;

DELIMITER $$

CREATE PROCEDURE add_product_to_order(
    IN p_order_id   INT,
    IN p_product_id INT,
    IN p_quantity   INT
)
BEGIN
    DECLARE v_stock INT;
    DECLARE v_price DECIMAL(10,2);

    -- If the product is not found, remember "nothing" (NULL) and keep going
    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_stock = NULL;

    -- Safety net: any error -> cancel everything
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Something went wrong, nothing was saved' AS message;
    END;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        SELECT 'Quantity must be at least 1' AS message;

    ELSE
        START TRANSACTION;

        -- Read stock and price, and lock the product row
        SELECT stock_quantity, price
        INTO v_stock, v_price
        FROM products
        WHERE product_id = p_product_id
        FOR UPDATE;

        IF v_stock IS NULL THEN
            ROLLBACK;
            SELECT 'Product not found' AS message;

        ELSEIF v_stock < p_quantity THEN
            ROLLBACK;
            SELECT 'Not enough stock' AS message;

        ELSE
            -- Only this INSERT: the triggers reduce the stock,
            -- write the history and update the totals and tier
            INSERT INTO order_details (order_id, product_id, quantity, unit_price)
            VALUES (p_order_id, p_product_id, p_quantity, v_price);

            COMMIT;
            SELECT 'Product added to order' AS message;
        END IF;
    END IF;
END$$

DELIMITER ;

-- ============================================
-- 6. restock_product: a delivery of ONE product arrives
-- Example: 30 boxes of Amoxicillin arrive -> CALL restock_product(5, 30);
-- (replenish_low_stock from file 06 still refills ALL low products at once)
-- ============================================
DROP PROCEDURE IF EXISTS restock_product;

DELIMITER $$

CREATE PROCEDURE restock_product(
    IN p_product_id INT,
    IN p_quantity   INT
)
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        SELECT 'Quantity must be at least 1' AS message;

    ELSEIF NOT EXISTS (SELECT 1 FROM products WHERE product_id = p_product_id) THEN
        SELECT 'Product not found' AS message;

    ELSE
        START TRANSACTION;

        -- increase the stock
        UPDATE products
        SET stock_quantity = stock_quantity + p_quantity
        WHERE product_id = p_product_id;

        -- history (positive = stock went up)
        INSERT INTO inventory_logs (product_id, quantity_change, change_type)
        VALUES (p_product_id, p_quantity, 'REPLENISHMENT');

        COMMIT;
        SELECT 'Product restocked' AS message;
    END IF;
END$$

DELIMITER ;

-- ============================================
-- 7. Views that use the new columns
-- ============================================

-- customer tiers: now read from the columns the trigger keeps up to date
CREATE OR REPLACE VIEW customer_tiers_view AS
SELECT
    customer_id,
    customer_name,
    total_spent,
    customer_tier
FROM customers;

-- Gold customers who have purchased: at least one order AND tier Gold
CREATE OR REPLACE VIEW gold_customers_view AS
SELECT
    customers.customer_id,
    customers.customer_name,
    customers.total_spent,
    COUNT(orders.order_id) AS number_of_orders
FROM customers
JOIN orders ON customers.customer_id = orders.customer_id   -- JOIN keeps only people with orders
WHERE customers.customer_tier = 'Gold'
GROUP BY customers.customer_id, customers.customer_name, customers.total_spent
ORDER BY customers.total_spent DESC;

SELECT * FROM customer_tiers_view;
SELECT * FROM gold_customers_view;

-- ============================================
-- 8. Index for the Gold query (WHERE customer_tier = 'Gold')
-- ============================================
CREATE INDEX idx_customers_tier ON customers(customer_tier);

-- Check: the "key" column should show idx_customers_tier
EXPLAIN
SELECT * FROM customers
WHERE customer_tier = 'Gold';

-- List all my triggers
SHOW TRIGGERS;
