-- ============================================
-- TESTS for the triggers (file 12)
-- Run this file ONLY ONCE: it places real orders.
-- The LAST test gives an error ON PURPOSE (Not enough stock).
-- ============================================

USE inventory_db;

-- ============================================
-- TEST 1: an order typed BY HAND (no procedure)
-- Prince (customer 4) buys 1 Omeprazole (product 2, price 1500)
-- Expected: stock of Omeprazole goes down by 1, one ORDER line in the
-- history, order total 1500, Prince becomes Silver (500 to 1999)
-- ============================================

-- BEFORE
SELECT product_name, stock_quantity FROM products WHERE product_id = 2;
SELECT customer_name, total_spent, customer_tier FROM customers WHERE customer_id = 4;

INSERT INTO orders (customer_id) VALUES (4);
SET @prince_order = LAST_INSERT_ID();

-- I only add the line: the triggers do everything else
INSERT INTO order_details (order_id, product_id, quantity, unit_price)
VALUES (@prince_order, 2, 1, 1500);

-- AFTER
SELECT product_name, stock_quantity FROM products WHERE product_id = 2;
SELECT order_id, total_amount FROM orders WHERE order_id = @prince_order;
SELECT customer_name, total_spent, customer_tier FROM customers WHERE customer_id = 4;
SELECT * FROM inventory_logs ORDER BY log_id DESC LIMIT 1;

-- ============================================
-- TEST 2: an order with the procedures
-- Vedaste (customer 3) buys 2 Paidoterin (product 6, price 2000)
-- Expected: stock goes down by 2 (only ONCE, not twice),
-- total 4000, Vedaste becomes Gold (2000 or more)
-- ============================================

-- BEFORE
SELECT product_name, stock_quantity FROM products WHERE product_id = 6;

CALL create_order(3);
SET @vedaste_order = LAST_INSERT_ID();
CALL add_product_to_order(@vedaste_order, 6, 2);

-- AFTER
SELECT product_name, stock_quantity FROM products WHERE product_id = 6;
SELECT order_id, total_amount FROM orders WHERE order_id = @vedaste_order;
SELECT customer_name, total_spent, customer_tier FROM customers WHERE customer_id = 3;

-- ============================================
-- TEST 3: a delivery arrives
-- 30 boxes of Amoxicillin (product 5)
-- Expected: stock goes up by 30, one REPLENISHMENT line (+30)
-- ============================================
SELECT product_name, stock_quantity FROM products WHERE product_id = 5;

CALL restock_product(5, 30);

SELECT product_name, stock_quantity FROM products WHERE product_id = 5;
SELECT * FROM inventory_logs ORDER BY log_id DESC LIMIT 1;

-- Wrong values are refused
CALL restock_product(5, 0);     -- expected 'Quantity must be at least 1'
CALL restock_product(99, 10);   -- expected 'Product not found'

-- ============================================
-- TEST 4: Gold customers who have purchased
-- Expected: Vedaste is in the list, Prince is not (he is Silver)
-- ============================================
SELECT * FROM customer_tiers_view;
SELECT * FROM gold_customers_view;

-- ============================================
-- TEST 5 (LAST, error on purpose): too many items typed BY HAND
-- Omnibionta (product 8): ask for 1000
-- Expected: Error Code 1644 'Not enough stock', nothing saved
-- ============================================
INSERT INTO order_details (order_id, product_id, quantity, unit_price)
VALUES (@prince_order, 8, 1000, 8000);
