-- ============================================
-- IMPROVEMENTS + their tests
-- 1. New rule: reorder_level can never be negative
-- 2. Tests: invalid orders are refused and change NOTHING
-- Run this file ONLY ONCE (the rule can only be added once).
-- ============================================

USE inventory_db;

-- ============================================
-- 1. Add a CHECK rule to the products table
-- (same kind of rule as price >= 0 and stock >= 0)
-- ============================================
ALTER TABLE products
ADD CONSTRAINT chk_reorder_level CHECK (reorder_level >= 0);

-- ============================================
-- 2. BEFORE: remember the stock of Sekalgic (product 1)
-- ============================================
SELECT product_name, stock_quantity
FROM products
WHERE product_id = 1;

-- TEST A: quantity 0 -> expected 'Quantity must be at least 1'
CALL add_product_to_order(52, 1, 0);

-- TEST B: negative quantity -> expected 'Quantity must be at least 1'
-- (a negative order must NEVER increase the stock)
CALL add_product_to_order(52, 1, -5);

-- TEST C: product that does not exist -> expected 'Product not found'
CALL add_product_to_order(52, 99, 1);

-- TEST D: more than the stock -> expected 'Not enough stock'
CALL add_product_to_order(52, 1, 1000);

-- ============================================
-- AFTER: the stock of Sekalgic must be EXACTLY the same as BEFORE
-- ============================================
SELECT product_name, stock_quantity
FROM products
WHERE product_id = 1;

-- And no new ORDER line was written in the history for these tests
SELECT COUNT(*) AS order_log_rows
FROM inventory_logs
WHERE change_type = 'ORDER';
