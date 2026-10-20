-- ============================================
-- PHASE 2a: Sample data
-- My pharmacy's products
-- Run this file ONLY ONCE (running again adds duplicates)
-- ============================================

USE inventory_db;

-- INSERT INTO adds new rows to a table
-- I don't give product_id because AUTO_INCREMENT fills it (1, 2, 3...)
INSERT INTO products (product_name, category, price, stock_quantity, reorder_level)
VALUES
    ('Sekalgic (pack)',                 'Pain relief',                2000, 40, 10),
    ('Omeprazole 20 mg (box of 14)',    'Digestive health',           1500, 25,  8),
    ('Nexium 20 mg (box of 14)',        'Acid reflux treatment',      6000, 15,  5),
    ('Unibrol (pack)',                  'Respiratory care',           2500, 20,  5),
    ('Amoxicillin 500 mg (box of 21)',  'Antibiotics',                3000,  6, 10),
    ('Paidoterin (pack)',               'Cough and cold care',        2000, 18,  6),
    ('Sekrol (bottle)',                 'Cough and respiratory care', 2500,  3,  5),
    ('Omnibionta Prenatal Care (pack)', 'Vitamins and supplements',   8000,  2,  3);

-- Check the result: show all products
SELECT * FROM products;

-- ============================================
-- My pharmacy's customers
-- ============================================

INSERT INTO customers (customer_name, email, phone)
VALUES
    ('David Niyonzima',   'david.niyonzima@example.com',   '+250 788 123 457'),
    ('Molo Jean',         'molo.jean@example.com',         '+250 788 123 458'),
    ('Vedaste Habimana',  'vedaste.habimana@example.com',  '+250 788 123 459'),
    ('Prince Iradukunda', 'prince.iradukunda@example.com', '+250 788 123 460'),
    ('Justine Mukamana',  'justine.mukamana@example.com',  '+250 788 123 461');

-- Check the result: show all customers
SELECT * FROM customers;