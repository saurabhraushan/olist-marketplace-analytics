/* Olist Marketplace Analytics — 03 Analytics-ready model
   Run only after 02_staging_validation.sql passes. */
USE olist_analytics;

CREATE TABLE dim_customer AS
SELECT DISTINCT customer_id,customer_unique_id,customer_zip_code_prefix,
       customer_city,customer_state FROM stg_customers;
ALTER TABLE dim_customer ADD PRIMARY KEY(customer_id);

CREATE TABLE dim_product AS
SELECT p.product_id,p.product_category_name,
       t.product_category_name_english,p.product_weight_g,
       p.product_length_cm,p.product_height_cm,p.product_width_cm
FROM stg_products p LEFT JOIN stg_category_translation t USING(product_category_name);
ALTER TABLE dim_product ADD PRIMARY KEY(product_id);

CREATE TABLE dim_seller AS SELECT DISTINCT * FROM stg_sellers;
ALTER TABLE dim_seller ADD PRIMARY KEY(seller_id);

CREATE TABLE fact_orders AS
SELECT order_id,customer_id,order_status,
 STR_TO_DATE(NULLIF(order_purchase_timestamp,''),'%Y-%m-%d %H:%i:%s') order_purchase_timestamp,
 STR_TO_DATE(NULLIF(order_approved_at,''),'%Y-%m-%d %H:%i:%s') order_approved_at,
 STR_TO_DATE(NULLIF(order_delivered_carrier_date,''),'%Y-%m-%d %H:%i:%s') order_delivered_carrier_date,
 STR_TO_DATE(NULLIF(order_delivered_customer_date,''),'%Y-%m-%d %H:%i:%s') order_delivered_customer_date,
 STR_TO_DATE(NULLIF(order_estimated_delivery_date,''),'%Y-%m-%d %H:%i:%s') order_estimated_delivery_date,
 DATEDIFF(STR_TO_DATE(NULLIF(order_delivered_customer_date,''),'%Y-%m-%d %H:%i:%s'),
          STR_TO_DATE(NULLIF(order_purchase_timestamp,''),'%Y-%m-%d %H:%i:%s')) delivery_days,
 (order_status='delivered' AND NULLIF(order_delivered_customer_date,'') IS NOT NULL) is_delivered,
 CASE WHEN order_status='delivered' AND NULLIF(order_delivered_customer_date,'') IS NOT NULL
      THEN DATE(STR_TO_DATE(order_delivered_customer_date,'%Y-%m-%d %H:%i:%s'))>
           DATE(STR_TO_DATE(order_estimated_delivery_date,'%Y-%m-%d %H:%i:%s')) END is_late
FROM stg_orders;
ALTER TABLE fact_orders ADD PRIMARY KEY(order_id);

CREATE TABLE fact_order_items AS
SELECT order_id,order_item_id,product_id,seller_id,
 STR_TO_DATE(NULLIF(shipping_limit_date,''),'%Y-%m-%d %H:%i:%s') shipping_limit_date,
 price,freight_value,price+freight_value item_value FROM stg_order_items;
ALTER TABLE fact_order_items ADD PRIMARY KEY(order_id,order_item_id);

CREATE TABLE fact_payments AS SELECT * FROM stg_payments;
ALTER TABLE fact_payments ADD PRIMARY KEY(order_id,payment_sequential);

CREATE TABLE fact_reviews AS
SELECT review_id,order_id,review_score,review_comment_title,review_comment_message
FROM stg_reviews;
ALTER TABLE fact_reviews ADD PRIMARY KEY(review_id,order_id);

CREATE INDEX ix_orders_customer ON fact_orders(customer_id);
CREATE INDEX ix_items_product ON fact_order_items(product_id);
CREATE INDEX ix_items_seller ON fact_order_items(seller_id);
CREATE INDEX ix_payments_order ON fact_payments(order_id);
CREATE INDEX ix_reviews_order ON fact_reviews(order_id);

