-- ============================================
-- PHASE 5a: Views
-- A view = a saved SELECT query with a name.
-- It stores no data: every time I open it, it runs again on the
-- real tables, so it is ALWAYS up to date (automatic).
-- CREATE OR REPLACE lets me run this file again safely.
-- ============================================

USE inventory_db;

-- ============================================
-- View 1: order summary
-- customer name, order date, total amount, number of items per order
-- ============================================
CREATE OR REPLACE VIEW order_summary_view AS
SELECT
    orders.order_id,
    customers.customer_name,
    orders.order_date,
    SUM(order_details.quantity) AS total_items,
    orders.total_amount
FROM orders
JOIN customers     ON orders.customer_id = customers.customer_id
JOIN order_details ON orders.order_id    = order_details.order_id
GROUP BY orders.order_id, customers.customer_name, orders.order_date, orders.total_amount;

-- ============================================
-- View 2: low stock
-- products whose stock is below their reorder_level
-- ============================================
CREATE OR REPLACE VIEW low_stock_view AS
SELECT
    product_id,
    product_name,
    category,
    stock_quantity,
    reorder_level
FROM products
WHERE stock_quantity < reorder_level;

-- ============================================
-- View 3: customer tiers
-- Automates tier categorization: the tier is recalculated
-- every time the view is opened, so it is never out of date.
-- ============================================
CREATE OR REPLACE VIEW customer_tiers_view AS
SELECT
    customers.customer_id,
    customers.customer_name,
    IFNULL(SUM(orders.total_amount), 0) AS total_spent,
    CASE
        WHEN IFNULL(SUM(orders.total_amount), 0) >= 2000 THEN 'Gold'
        WHEN IFNULL(SUM(orders.total_amount), 0) >= 500  THEN 'Silver'
        ELSE 'Bronze'
    END AS customer_tier
FROM customers
LEFT JOIN orders ON customers.customer_id = orders.customer_id
GROUP BY customers.customer_id, customers.customer_name;

-- ============================================
-- Test: use the views like tables
-- ============================================
SELECT * FROM order_summary_view;
SELECT * FROM low_stock_view;       -- empty now, because I just replenished
SELECT * FROM customer_tiers_view;
