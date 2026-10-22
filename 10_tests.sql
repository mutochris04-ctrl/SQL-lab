-- ============================================
-- TESTS: proving the system works
-- 1. An order that asks for MORE than the stock is refused
-- 2. A product that does not exist is refused
-- 3. A big order gets a bulk discount
-- 4. The full inventory history (ORDER + REPLENISHMENT)
-- Run this file ONLY ONCE: it places a real order for Molo Jean.
-- ============================================

USE inventory_db;

-- Create a new empty order for Molo Jean (customer_id = 2)
CALL create_order(2);

-- @order_id = a variable that remembers the new order's ID
-- LAST_INSERT_ID() = the ID MySQL just gave to the new order
SET @order_id = LAST_INSERT_ID();

-- ============================================
-- TEST 1: not enough stock
-- Sekrol (product 7) has only 10 in stock; Molo asks for 50
-- Expected: 'Not enough stock', and the stock stays 10
-- ============================================
CALL add_product_to_order(@order_id, 7, 50);

SELECT product_name, stock_quantity
FROM products
WHERE product_id = 7;

-- ============================================
-- TEST 2: product that does not exist
-- Expected: 'Product not found'
-- ============================================
CALL add_product_to_order(@order_id, 99, 1);

-- ============================================
-- TEST 3: a big order gets a bulk discount
-- Molo buys 10 x Sekalgic (product 1, price 2000)
-- Expected: total 20000.00, 10 items -> 10% discount -> 18000.00
-- ============================================
CALL add_product_to_order(@order_id, 1, 10);

SELECT
    orders.order_id,
    customers.customer_name,
    SUM(order_details.quantity) AS total_items,
    orders.total_amount,
    CASE
        WHEN SUM(order_details.quantity) >= 10 THEN 10
        WHEN SUM(order_details.quantity) >= 5  THEN 5
        ELSE 0
    END AS discount_percent,
    ROUND(orders.total_amount - (orders.total_amount *
        CASE
            WHEN SUM(order_details.quantity) >= 10 THEN 10
            WHEN SUM(order_details.quantity) >= 5  THEN 5
            ELSE 0
        END / 100), 2) AS amount_after_discount
FROM orders
JOIN customers     ON orders.customer_id = customers.customer_id
JOIN order_details ON orders.order_id    = order_details.order_id
WHERE orders.order_id = @order_id
GROUP BY orders.order_id, customers.customer_name, orders.total_amount;

-- Molo spent 20000, so the tiers view now shows her as Gold
SELECT * FROM customer_tiers_view;

-- ============================================
-- TEST 4: full inventory history (for auditing)
-- every stock change, oldest first, with the product name
-- negative = stock went DOWN (order), positive = UP (replenishment)
-- ============================================
SELECT
    inventory_logs.log_id,
    inventory_logs.change_date,
    products.product_name,
    inventory_logs.quantity_change,
    inventory_logs.change_type
FROM inventory_logs
JOIN products ON inventory_logs.product_id = products.product_id
ORDER BY inventory_logs.change_date, inventory_logs.log_id;
