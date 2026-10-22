-- ============================================
-- PHASE 1: Database design
-- Table 1: products
-- Purpose: stores every product the shop sells
-- ============================================

-- Work inside my lab database
USE inventory_db;

CREATE TABLE IF NOT EXISTS products (
    -- Unique ID for each product; MySQL fills it in (1, 2, 3...)
    product_id     INT AUTO_INCREMENT PRIMARY KEY,

    -- Product name is required (cannot be empty)
    product_name   VARCHAR(100) NOT NULL,

    -- Group of the product, e.g. 'Electronics', 'Clothing'
    category       VARCHAR(50),

    -- Price with 2 decimals; CHECK blocks negative prices (data integrity)
    price          DECIMAL(10,2) NOT NULL CHECK (price >= 0),

    -- How many items are in stock now; can never go below 0
    stock_quantity INT NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),

    -- When stock falls below this number, the product must be reordered (used in Phase 3)
    reorder_level  INT NOT NULL DEFAULT 10
);
DESCRIBE products;

-- ============================================
-- Table 2: customers
-- Purpose: stores the people who buy from the shop
-- ============================================

CREATE TABLE IF NOT EXISTS customers (
    -- Unique ID for each customer; MySQL fills it in (1, 2, 3...)
    customer_id    INT AUTO_INCREMENT PRIMARY KEY,

    -- Customer's full name is required
    customer_name  VARCHAR(100) NOT NULL,

    -- Email is required and UNIQUE: two customers cannot share the same email
    email          VARCHAR(100) NOT NULL UNIQUE,

    -- Phone is text (not a number) because it can start with 0 or have a + sign
    phone          VARCHAR(20)
);

DESCRIBE customers;

-- ============================================
-- Table 3: orders
-- Purpose: one row for each order a customer places
-- ============================================

CREATE TABLE IF NOT EXISTS orders (
    -- Unique ID for each order; MySQL fills it in (1, 2, 3...)
    order_id      INT AUTO_INCREMENT PRIMARY KEY,

    -- Which customer placed the order (must be a real customer_id)
    customer_id   INT NOT NULL,

    -- Date and time of the order; MySQL puts the current time automatically
    order_date    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Total price of the order; starts at 0, will be calculated automatically in Phase 4
    total_amount  DECIMAL(10,2) NOT NULL DEFAULT 0,

    -- FOREIGN KEY: links this order to the customers table
    -- An order cannot exist for a customer who does not exist (data integrity)
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

DESCRIBE orders;

-- ============================================
-- Table 4: order_details
-- Purpose: which products are inside each order (one row per product per order)
-- ============================================

CREATE TABLE IF NOT EXISTS order_details (
    -- Unique ID for each line of an order
    order_detail_id  INT AUTO_INCREMENT PRIMARY KEY,

    -- Which order this line belongs to
    order_id         INT NOT NULL,

    -- Which product was bought
    product_id       INT NOT NULL,

    -- How many of this product; must be at least 1
    quantity         INT NOT NULL CHECK (quantity > 0),

    -- Price of ONE item at the time of the order
    -- (saved here because the product price can change later)
    unit_price       DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),

    -- FOREIGN KEYS: this line must point to a real order AND a real product
    FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

DESCRIBE order_details;

-- ============================================
-- Table 5: inventory_logs
-- Purpose: history of EVERY stock change (for auditing)
-- ============================================

CREATE TABLE IF NOT EXISTS inventory_logs (
    -- Unique ID for each log entry
    log_id           INT AUTO_INCREMENT PRIMARY KEY,

    -- Which product's stock changed
    product_id       INT NOT NULL,

    -- How much the stock changed:
    -- negative number = stock went DOWN (e.g. -3 after an order)
    -- positive number = stock went UP   (e.g. +50 after replenishment)
    quantity_change  INT NOT NULL,

    -- Why it changed: only 'ORDER' or 'REPLENISHMENT' are allowed
    change_type      VARCHAR(20) NOT NULL CHECK (change_type IN ('ORDER', 'REPLENISHMENT')),

    -- When it happened; MySQL fills in the current date and time
    change_date      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- FOREIGN KEY: the log must be about a real product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

DESCRIBE inventory_logs;