/*
 Olist Marketplace Analytics
 01 — Data import and staging template (MySQL 8+)

 These statements reconstruct the repeatable loading pattern used for the
 project. Update @data_dir and filenames for your local Olist CSV extracts.
 Dates are staged as text and converted with STR_TO_DATE during modelling.
*/

CREATE DATABASE IF NOT EXISTS olist_analytics;
USE olist_analytics;
SET GLOBAL local_infile = 1;

CREATE TABLE IF NOT EXISTS stg_customers (
  customer_id VARCHAR(32), customer_unique_id VARCHAR(32),
  customer_zip_code_prefix INT, customer_city VARCHAR(100), customer_state VARCHAR(10)
);
CREATE TABLE IF NOT EXISTS stg_orders (
  order_id VARCHAR(32), customer_id VARCHAR(32), order_status VARCHAR(20),
  order_purchase_timestamp VARCHAR(30), order_approved_at VARCHAR(30),
  order_delivered_carrier_date VARCHAR(30), order_delivered_customer_date VARCHAR(30),
  order_estimated_delivery_date VARCHAR(30)
);
CREATE TABLE IF NOT EXISTS stg_order_items (
  order_id VARCHAR(32), order_item_id INT, product_id VARCHAR(32), seller_id VARCHAR(32),
  shipping_limit_date VARCHAR(30), price DECIMAL(12,2), freight_value DECIMAL(12,2)
);
CREATE TABLE IF NOT EXISTS stg_payments (
  order_id VARCHAR(32), payment_sequential INT, payment_type VARCHAR(30),
  payment_installments INT, payment_value DECIMAL(12,2)
);
CREATE TABLE IF NOT EXISTS stg_reviews (
  review_id VARCHAR(32), order_id VARCHAR(32), review_score INT,
  review_comment_title TEXT, review_comment_message TEXT,
  review_creation_date VARCHAR(30), review_answer_timestamp VARCHAR(30)
);
CREATE TABLE IF NOT EXISTS stg_products (
  product_id VARCHAR(32), product_category_name VARCHAR(100),
  product_name_length INT, product_description_length INT,
  product_photos_qty INT, product_weight_g INT,
  product_length_cm INT, product_height_cm INT, product_width_cm INT
);
CREATE TABLE IF NOT EXISTS stg_sellers (
  seller_id VARCHAR(32), seller_zip_code_prefix INT,
  seller_city VARCHAR(100), seller_state VARCHAR(10)
);
CREATE TABLE IF NOT EXISTS stg_category_translation (
  product_category_name VARCHAR(100), product_category_name_english VARCHAR(100)
);

/* Run one LOAD DATA statement per file; example shown below. */
LOAD DATA LOCAL INFILE 'C:/olist/olist_customers_dataset.csv'
INTO TABLE stg_customers CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(customer_id,customer_unique_id,customer_zip_code_prefix,customer_city,customer_state);

/* Repeat the same pattern for orders, items, payments, reviews, products,
   sellers and category translation using their matching column lists. */

