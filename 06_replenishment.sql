-- ============================================
-- PHASE 4a: Stock replenishment
-- Goal: refill every product whose stock is below its reorder_level,
--       and write each refill in inventory_logs (history).
-- My rule: refill the product up to 2 x its reorder_level
--   Example: Sekrol has 3, reorder_level is 5 -> refill to 10 (adds +7)
-- This file only CREATES the procedure (no data changes),
-- so it is safe to run again.
-- ============================================

USE inventory_db;

-- Remove the old version first, so I can run this file again
DROP PROCEDURE IF EXISTS replenish_low_stock;

DELIMITER $$

CREATE PROCEDURE replenish_low_stock()
BEGIN
    -- Do both steps together: all succeed, or none are saved
    START TRANSACTION;

    -- Step 1: write the history FIRST (while we still know the old stock)
    -- quantity_change = new stock - old stock (positive = stock went UP)
    INSERT INTO inventory_logs (product_id, quantity_change, change_type)
    SELECT
        product_id,
        (reorder_level * 2) - stock_quantity,
        'REPLENISHMENT'
    FROM products
    WHERE stock_quantity < reorder_level;

    -- Step 2: refill the stock of the same products
    UPDATE products
    SET stock_quantity = reorder_level * 2
    WHERE stock_quantity < reorder_level;

    -- Save all the changes
    COMMIT;

    SELECT 'Low-stock products replenished' AS message;
END$$

DELIMITER ;
