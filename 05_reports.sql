-- ============================================
-- PHASE 3: Reports (questions the shop owner asks)
-- These are only SELECT queries: they READ data, they change nothing,
-- so this file is safe to run again.
-- ============================================

USE inventory_db;

-- ============================================
-- Report 1: Order summary
-- Question: for each order, who bought, when, how many items, and the total?
-- ============================================

SELECT
    orders.order_id,
    customers.customer_name,
    orders.order_date,
    SUM(order_details.quantity) AS total_items,   -- add up the items in the order
    orders.total_amount
FROM orders
-- JOIN = connect two tables using the column they share
JOIN customers     ON orders.customer_id = customers.customer_id
JOIN order_details ON orders.order_id    = order_details.order_id
-- GROUP BY = one result row per order (SUM adds the lines of each order)
GROUP BY orders.order_id, customers.customer_name, orders.order_date, orders.total_amount
-- Newest orders first
ORDER BY orders.order_date DESC;

-- ============================================
-- Report 2: Low stock products
-- Question: which products must the pharmacy reorder?
-- A product is "low" when its stock is BELOW its reorder_level
-- ============================================

SELECT
    product_id,
    product_name,
    category,
    stock_quantity,
    reorder_level
FROM products
-- WHERE keeps only the rows where the condition is true
WHERE stock_quantity < reorder_level
-- Lowest stock first, so the most urgent product is at the top
ORDER BY stock_quantity ASC;

-- ============================================
-- Report 3: Customer tiers
-- Question: how much has each customer spent, and which tier are they in?
-- Tiers (in RWF):  Gold   = 2000 or more
--                  Silver = 500 to 1999
--                  Bronze = less than 500 (or no orders yet)
-- ============================================

SELECT
    customers.customer_id,
    customers.customer_name,
    -- IFNULL(..., 0): if the customer has no orders, show 0 instead of empty (NULL)
    IFNULL(SUM(orders.total_amount), 0) AS total_spent,
    -- CASE works like if / elif / else in Python
    CASE
        WHEN IFNULL(SUM(orders.total_amount), 0) >= 2000 THEN 'Gold'
        WHEN IFNULL(SUM(orders.total_amount), 0) >= 500  THEN 'Silver'
        ELSE 'Bronze'
    END AS customer_tier
FROM customers
-- LEFT JOIN keeps ALL customers, even those who have not ordered yet
LEFT JOIN orders ON customers.customer_id = orders.customer_id
-- One result row per customer
GROUP BY customers.customer_id, customers.customer_name
-- Biggest spenders first
ORDER BY total_spent DESC;

-- ============================================
-- Report 4: Bulk discounts
-- Question: which orders get a discount for buying in large quantities?
-- My discount rule (based on the number of items in the order):
--     10 items or more -> 10% discount
--      5 to 9 items    ->  5% discount
--     less than 5      ->  no discount
-- ============================================

SELECT
    orders.order_id,
    customers.customer_name,
    SUM(order_details.quantity) AS total_items,
    orders.total_amount,
    -- CASE works like if / elif / else: choose the discount percent
    CASE
        WHEN SUM(order_details.quantity) >= 10 THEN 10
        WHEN SUM(order_details.quantity) >= 5  THEN 5
        ELSE 0
    END AS discount_percent,
    -- Price after discount = total - (total x percent / 100)
    -- ROUND(..., 2) keeps only 2 decimals, like money
    ROUND(orders.total_amount - (orders.total_amount *
        CASE
            WHEN SUM(order_details.quantity) >= 10 THEN 10
            WHEN SUM(order_details.quantity) >= 5  THEN 5
            ELSE 0
        END / 100), 2) AS amount_after_discount
FROM orders
JOIN customers     ON orders.customer_id = customers.customer_id
JOIN order_details ON orders.order_id    = order_details.order_id
-- One result row per order
GROUP BY orders.order_id, customers.customer_name, orders.total_amount
ORDER BY total_items DESC;
