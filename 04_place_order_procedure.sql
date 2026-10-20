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

    -- 1. Read the product's current stock and price from the products table
    SELECT stock_quantity, price
    INTO v_stock, v_price
    FROM products
    WHERE product_id = p_product_id;

    -- 2. Check before changing anything (like if / elif / else in Python)
    IF v_stock IS NULL THEN
        SELECT 'Product not found' AS message;

    ELSEIF v_stock < p_quantity THEN
        SELECT 'Not enough stock' AS message;

    ELSE
        -- 3. Do all the changes together: all succeed, or none are saved
        START TRANSACTION;

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
        UPDATE orders
        SET total_amount = (
            SELECT SUM(quantity * unit_price)
            FROM order_details
            WHERE order_id = p_order_id
        )
        WHERE order_id = p_order_id;

        -- Save all the changes
        COMMIT;

        SELECT 'Product added to order' AS message;
    END IF;
END$$

DELIMITER ;