# Inventory and Order Management System (DEM03: SQL for Data)

A MySQL database for a small **pharmacy** that manages products, customers, orders and stock.
It places orders safely, keeps a full history of every stock change, refills low stock,
and gives business reports such as order summaries and customer tiers.

**Tools:** MySQL 8, MySQL Workbench
**Database:** `inventory_db`

---

## Project Structure

```text
SQL-lab/
│
├── 01_create_tables.sql        Phase 1: the 5 tables, keys and constraints
├── 02_sample_data.sql          Phase 2: 8 pharmacy products, 5 customers
├── 03_place_order.sql          Phase 2: first order, step by step (by hand)
├── 04_place_order_procedure.sql Phase 2: procedures to place orders automatically
├── 05_reports.sql              Phase 3: 4 business reports
├── 06_replenishment.sql        Phase 4: procedure that refills low stock
├── 07_replenishment_demo.sql   Phase 4: demo (before, refill, after, history)
├── 08_views.sql                Phase 5: 3 views
├── 09_indexes.sql              Phase 5: indexes for speed
├── 10_tests.sql                Tests: stock check, bulk discount, full history
├── 11_improvement_tests.sql    Improvements: CHECK on reorder_level, tests of invalid orders
└── README.md
```

**How to run:** create the database once (`CREATE DATABASE inventory_db;`), then run the files
in order, 01 to 09, in MySQL Workbench.
Files 02, 03, 09, 10 and 11 should be run **only once** (running them again adds duplicates or errors).

---

## Phase 1: Database Design

| Table | What it stores |
|---|---|
| `products` | product name, category, price, stock quantity, reorder level |
| `customers` | name, email (unique), phone |
| `orders` | which customer, order date, total amount |
| `order_details` | which products are in each order, quantity, unit price |
| `inventory_logs` | history of every stock change (ORDER or REPLENISHMENT) |

**Data integrity:**
- **Primary keys** give every row a unique ID.
- **Foreign keys** link the tables: an order must belong to a real customer, and an order line must point to a real order and a real product.
- **CHECK** rules block wrong values: no negative prices or stock, quantity must be at least 1.
- **NOT NULL** and **UNIQUE** (email) keep the data complete and without duplicates.

---

## Phase 2: Order Placement and Inventory Tracking

Two **stored procedures** place orders:

- `create_order(customer_id)` creates a new empty order and shows its ID.
- `add_product_to_order(order_id, product_id, quantity)`:
  1. reads the product's stock and price
  2. stops with a message if the product does not exist or there is not enough stock
  3. otherwise, in one **transaction** (all steps succeed, or none are saved):
     - adds the product to `order_details`
     - reduces the stock
     - writes the change in `inventory_logs` (negative number = stock went down)
     - recalculates the order total

Calling `add_product_to_order` several times adds several products to the same order.

**Improvements:**
- **Quantity check:** 0 or negative quantities are refused before anything changes (a negative order can never increase stock).
- **Missing product:** a `CONTINUE HANDLER FOR NOT FOUND` sets the stock to NULL, so the procedure answers `Product not found`.
- **Safety net:** an `EXIT HANDLER FOR SQLEXCEPTION` does `ROLLBACK` if any unexpected error happens, so nothing half-done is saved.
- **Safe for two customers at once:** the transaction starts *before* reading the stock, and `SELECT ... FOR UPDATE` locks the product row until `COMMIT`, so two orders cannot sell the same last items.

```sql
CALL create_order(1);                  -- e.g. returns new_order_id = 4
CALL add_product_to_order(4, 4, 3);    -- 3 x Unibrol
```

---

## Phase 3: Reports (`05_reports.sql`)

| Report | Question it answers |
|---|---|
| 1. Order summary | For each order: customer, date, number of items, total |
| 2. Low stock | Which products are below their reorder level? |
| 3. Customer tiers | How much has each customer spent? Gold, Silver or Bronze? |
| 4. Bulk discounts | Which orders get a discount for large quantities? |

**Customer tiers (RWF):** Gold = 10,000 or more · Silver = 5,000 to 9,999 · Bronze = less than 5,000

**Bulk discount rule:** 10 items or more = 10% · 5 to 9 items = 5% · less than 5 = no discount

**Design decision:** `orders.total_amount` stores the amount **before** discount (the subtotal). Report 4 shows the discount and the amount to pay. Customer tiers are based on the subtotal.

---

## Phase 4: Replenishment and Automation

`replenish_low_stock()` finds every product with stock below its reorder level and refills it
to **2 × the reorder level**. It writes the history first (positive number = stock went up,
type `REPLENISHMENT`), then updates the stock, inside one transaction.

Demo result (`07_replenishment_demo.sql`):

| Product | Before | After | Logged |
|---|---|---|---|
| Amoxicillin | 6 | 20 | +14 |
| Sekrol | 3 | 10 | +7 |
| Omnibionta | 2 | 6 | +4 |

**What is automated:**
- Stock update after an order → `add_product_to_order`
- Order total calculation → `add_product_to_order`
- Inventory history → both procedures write to `inventory_logs`
- Customer tier categorization → `customer_tiers_view` (recalculated every time it is opened)

---

## Phase 5: Views and Optimization

**Views** (saved queries, always up to date):
- `order_summary_view`: customer name, order date, total amount, number of items
- `low_stock_view`: products that need to be reordered
- `customer_tiers_view`: total spent and tier for every customer

**Indexes:** MySQL already indexes every primary key and foreign key. I added indexes on
columns my queries use in `WHERE` or `ORDER BY`:
- `orders(order_date)`
- `inventory_logs(change_type)`
- `products(category)`

`EXPLAIN` confirms MySQL uses the index:
`Index lookup on inventory_logs using idx_logs_change_type`

With only 8 products the time difference is too small to measure; the benefit grows as the tables grow (in the lecture demo, adding indexes made queries about 6× faster).

---

## Tests (`10_tests.sql`)

| Test | Expected result |
|---|---|
| Order 50 Sekrol when only 10 are in stock | `Not enough stock`, and the stock stays 10 |
| Order a product that does not exist (id 99) | `Product not found` |
| Molo orders 10 Sekalgic | Total 20,000, 10% bulk discount, 18,000 to pay; Molo becomes Gold |
| Full inventory history | Every ORDER (negative) and REPLENISHMENT (positive) change, oldest first |

### Scratch testing (`scratch_testing.sql`)

Quick queries I used while working to check my results by hand: David's order total (3 x 2,500 = 7,500), Unibrol and Sekrol stock after the order, and the inventory history.

---

## Author

Christine Umutoni, AmaliTech Data Engineering training
