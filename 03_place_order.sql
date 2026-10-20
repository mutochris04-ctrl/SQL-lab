-- ============================================
-- PHASE 2b: Placing an order 
-- Justine Mukamana buys 2 Sekalgic + 1 Nexium
-- ============================================

USE inventory_db;

-- Part 1: create the order for Justine (customer_id = 5)
-- order_date and total_amount fill in automatically (now, and 0)
INSERT INTO orders (customer_id)
VALUES (5);

-- Check the result
SELECT * FROM orders;

-- Part 2: what is inside order 1
-- unit_price = the product price today (Sekalgic 2000, Nexium 6000)
INSERT INTO order_details (order_id, product_id, quantity, unit_price)
VALUES
    (1, 1, 2, 2000),   -- 2 x Sekalgic
    (1, 3, 1, 6000);   -- 1 x Nexium

-- Check the result
SELECT * FROM order_details;

-- Part 3: reduce the stock of each product Justine bought
-- stock_quantity - 2 means "take away 2 from what is there now"
UPDATE products
SET stock_quantity = stock_quantity - 2
WHERE product_id = 1;   -- Sekalgic: 40 -> 38

UPDATE products
SET stock_quantity = stock_quantity - 1
WHERE product_id = 3;   -- Nexium: 15 -> 14

-- Check the result
SELECT product_id, product_name, stock_quantity FROM products;
-- Part 4: write each stock change in the history (inventory_logs)
-- negative number = stock went DOWN because of an order
INSERT INTO inventory_logs (product_id, quantity_change, change_type)
VALUES
    (1, -2, 'ORDER'),   -- Sekalgic: 2 sold to Justine
    (3, -1, 'ORDER');   -- Nexium: 1 sold to Justine

-- Check the result
SELECT * FROM inventory_logs;

-- Part 5: calculate the total amount of order 1
-- SUM(quantity * unit_price) adds up the price of every line in the order
UPDATE orders
SET total_amount = (
    SELECT SUM(quantity * unit_price)
    FROM order_details
    WHERE order_id = 1
)
WHERE order_id = 1;

-- Check the result: total_amount should be 10000.00
SELECT * FROM orders;