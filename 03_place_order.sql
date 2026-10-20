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