USE inventory_db;

-- Check David's order 4: total should be 3 x 2500 = 7500.00
SELECT * FROM orders WHERE order_id = 4;

-- Unibrol should be 17 (was 20), Sekrol should still be 3
SELECT product_id, product_name, stock_quantity
FROM products
WHERE product_id IN (4, 7);

-- The history should show -3 for Unibrol (product 4)
SELECT * FROM inventory_logs;