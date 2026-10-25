/* Olist Marketplace Analytics — 02 Staging validation
   Run after CSV loading and before creating the analytics model. */
USE olist_analytics;

/* Loaded row counts */
SELECT 'stg_customers' table_name,COUNT(*) row_count FROM stg_customers
UNION ALL SELECT 'stg_orders',COUNT(*) FROM stg_orders
UNION ALL SELECT 'stg_order_items',COUNT(*) FROM stg_order_items
UNION ALL SELECT 'stg_payments',COUNT(*) FROM stg_payments
UNION ALL SELECT 'stg_reviews',COUNT(*) FROM stg_reviews
UNION ALL SELECT 'stg_products',COUNT(*) FROM stg_products
UNION ALL SELECT 'stg_sellers',COUNT(*) FROM stg_sellers;

/* Candidate-key duplicates */
SELECT customer_id,COUNT(*) c FROM stg_customers GROUP BY customer_id HAVING c>1;
SELECT order_id,COUNT(*) c FROM stg_orders GROUP BY order_id HAVING c>1;
SELECT order_id,order_item_id,COUNT(*) c FROM stg_order_items
GROUP BY order_id,order_item_id HAVING c>1;
SELECT order_id,payment_sequential,COUNT(*) c FROM stg_payments
GROUP BY order_id,payment_sequential HAVING c>1;
SELECT review_id,order_id,COUNT(*) c FROM stg_reviews
GROUP BY review_id,order_id HAVING c>1;
SELECT product_id,COUNT(*) c FROM stg_products GROUP BY product_id HAVING c>1;
SELECT seller_id,COUNT(*) c FROM stg_sellers GROUP BY seller_id HAVING c>1;

/* Raw referential-integrity checks */
SELECT COUNT(*) orphan_orders FROM stg_orders o
LEFT JOIN stg_customers c USING(customer_id) WHERE c.customer_id IS NULL;
SELECT COUNT(*) orphan_items FROM stg_order_items i
LEFT JOIN stg_orders o USING(order_id) WHERE o.order_id IS NULL;
SELECT COUNT(*) orphan_payments FROM stg_payments p
LEFT JOIN stg_orders o USING(order_id) WHERE o.order_id IS NULL;
SELECT COUNT(*) orphan_reviews FROM stg_reviews r
LEFT JOIN stg_orders o USING(order_id) WHERE o.order_id IS NULL;
SELECT COUNT(*) orphan_item_products FROM stg_order_items i
LEFT JOIN stg_products p USING(product_id) WHERE p.product_id IS NULL;
SELECT COUNT(*) orphan_item_sellers FROM stg_order_items i
LEFT JOIN stg_sellers s USING(seller_id) WHERE s.seller_id IS NULL;

/* Raw domain and missing-value checks */
SELECT order_status,COUNT(*) orders FROM stg_orders GROUP BY order_status ORDER BY orders DESC;
SELECT SUM(price IS NULL) missing_price,SUM(price<0) negative_price,
       SUM(freight_value IS NULL) missing_freight,SUM(freight_value<0) negative_freight
FROM stg_order_items;
SELECT SUM(payment_type IS NULL OR payment_type='') missing_payment_type,
       SUM(payment_type='not_defined') undefined_payment_type,
       SUM(payment_installments IS NULL) missing_installments,
       SUM(payment_installments=0) zero_installments,
       SUM(payment_value IS NULL) missing_payment_value,
       SUM(payment_value=0) zero_payment_value,
       SUM(payment_value<0) negative_payment_value
FROM stg_payments;

