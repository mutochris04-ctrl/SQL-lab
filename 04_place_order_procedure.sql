-- ============================================
-- PHASE 2c: Placing orders with procedures
-- A procedure = a saved set of SQL steps I can reuse with CALL
-- This file only CREATES procedures (no data changes),
-- so it is safe to run again.
-- ============================================

USE inventory_db;

-- Remove the old version first, so I can run this file again
DROP PROCEDURE IF EXISTS create_order;

-- DELIMITER $$ tells MySQL: "the procedure ends at $$, not at the first ;"
DELIMITER $$

-- Procedure 1: create a new, empty order for a customer
CREATE PROCEDURE create_order(IN p_customer_id INT)
BEGIN
    -- Add the order (date and total fill in automatically)
    INSERT INTO orders (customer_id)
    VALUES (p_customer_id);

    -- Show the ID MySQL just gave to this new order
    SELECT LAST_INSERT_ID() AS new_order_id;
END$$

-- Go back to the normal ; delimiter
DELIMITER ;

-- Remove the old version first, so I can run this file again
DROP PROCEDURE IF EXISTS add_product_to_order;

DELIMITER $$

-- Procedure 2: add one product to an order, safely
CREATE PROCEDURE add_product_to_order(
    IN p_order_id   INT,   -- which order
    IN p_product_id INT,   -- which product
    IN p_quantity   INT    -- how many
)
BEGIN
    -- Variables: small boxes to keep values inside the procedure
    DECLARE v_stock INT;
    DECLARE v_price DECIMAL(10,2);

    -- If the product is not found, remember "nothing" (NULL) and keep going
    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_stock = NULL;

    -- Safety net: if ANY error happens (for example the order does not exist),
    -- cancel all the changes and show a message
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Something went wrong, nothing was saved' AS message;
    END;

    -- 1. Check the quantity first: 0 or negative is never allowed
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        SELECT 'Quantity must be at least 1' AS message;

    ELSE
        -- 2. Start the transaction BEFORE reading the stock
        START TRANSACTION;

        -- 3. Read the stock and price, and LOCK this product row (FOR UPDATE)
        --    so another order cannot buy the same stock at the same time
        SELECT stock_quantity, price
        INTO v_stock, v_price
        FROM products
        WHERE product_id = p_product_id
        FOR UPDATE;

        -- 4. Check before changing anything (like if / elif / else in Python)
        IF v_stock IS NULL THEN
            ROLLBACK;   -- nothing changed, just release the lock
            SELECT 'Product not found' AS message;

        ELSEIF v_stock < p_quantity THEN
            ROLLBACK;   -- nothing changed, just release the lock
            SELECT 'Not enough stock' AS message;

        ELSE
            -- 5. Do all the changes together: all succeed, or none are saved

            -- Add the product to the order, with the price from the products table
            INSERT INTO order_details (order_id, product_id, quantity, unit_price)
            VALUES (p_order_id, p_product_id, p_quantity, v_price);

            -- Reduce the stock
            UPDATE products
            SET stock_quantity = stock_quantity - p_quantity
            WHERE product_id = p_product_id;

            -- Write the change in the history (negative = stock went down)
            INSERT INTO inventory_logs (product_id, quantity_change, change_type)
            VALUES (p_product_id, -p_quantity, 'ORDER');

            -- Recalculate the order total from all its lines
            -- (total_amount = the amount BEFORE any bulk discount; see Report 4)
            UPDATE orders
            SET total_amount = (
                SELECT SUM(quantity * unit_price)
                FROM order_details
                WHERE order_id = p_order_id
            )
            WHERE order_id = p_order_id;

            -- Save all the changes (this also releases the lock)
            COMMIT;

            SELECT 'Product added to order' AS message;
        END IF;
    END IF;
END$$

DELIMITER ;
