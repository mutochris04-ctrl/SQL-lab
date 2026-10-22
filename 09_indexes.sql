-- ============================================
-- PHASE 5b: Optimization with indexes
-- An index is like the index at the back of a book:
-- MySQL jumps straight to the rows it needs instead of reading
-- the whole table. This matters when the tables become big.
--
-- Good to know: MySQL ALREADY made indexes for me on
--   - every PRIMARY KEY (product_id, customer_id, order_id...)
--   - every FOREIGN KEY column (orders.customer_id,
--     order_details.order_id, order_details.product_id,
--     inventory_logs.product_id)
-- So here I only add indexes on other columns my queries use
-- in WHERE or ORDER BY.
--
-- Run this file ONLY ONCE (creating the same index twice gives an error).
-- ============================================

USE inventory_db;

-- My reports sort orders by date (ORDER BY order_date)
CREATE INDEX idx_orders_order_date ON orders(order_date);

-- The history is filtered by type (WHERE change_type = 'REPLENISHMENT')
CREATE INDEX idx_logs_change_type ON inventory_logs(change_type);

-- Products are often searched by category
CREATE INDEX idx_products_category ON products(category);

-- ============================================
-- Check: list all the indexes of a table
-- ============================================
SHOW INDEX FROM orders;

-- ============================================
-- Check: EXPLAIN shows HOW MySQL runs a query.
-- In the "key" column I should see the index name it uses.
-- ============================================
EXPLAIN
SELECT * FROM inventory_logs
WHERE change_type = 'REPLENISHMENT';
