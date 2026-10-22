-- ============================================
-- PHASE 4b: Replenishment demo
-- Shows the system finding low-stock products and refilling them.
-- Running it again is safe: if nothing is low, nothing changes.
-- ============================================

USE inventory_db;

-- BEFORE: which products are low? (stock below reorder_level)
SELECT product_id, product_name, stock_quantity, reorder_level
FROM products
WHERE stock_quantity < reorder_level;

-- Refill them (procedure from 06_replenishment.sql)
CALL replenish_low_stock();

-- AFTER: the same products now have 2 x reorder_level
SELECT product_id, product_name, stock_quantity, reorder_level
FROM products
WHERE product_id IN (5, 7, 8);   -- Amoxicillin, Sekrol, Omnibionta

-- HISTORY: the refills are recorded as REPLENISHMENT (positive numbers)
SELECT * FROM inventory_logs
WHERE change_type = 'REPLENISHMENT';
