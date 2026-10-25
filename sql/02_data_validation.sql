/* Olist Marketplace Analytics — 02 Data validation */
USE olist_analytics;

/* Row-count checkpoint */
SELECT 'fact_orders' table_name, COUNT(*) row_count FROM fact_orders
UNION ALL SELECT 'fact_order_items',COUNT(*) FROM fact_order_items
UNION ALL SELECT 'fact_payments',COUNT(*) FROM fact_payments
UNION ALL SELECT 'fact_reviews',COUNT(*) FROM fact_reviews;

/* Duplicate keys: every result should return zero rows */
SELECT order_id,COUNT(*) c FROM fact_orders GROUP BY order_id HAVING c>1;
SELECT order_id,order_item_id,COUNT(*) c FROM fact_order_items
GROUP BY order_id,order_item_id HAVING c>1;
SELECT order_id,payment_sequential,COUNT(*) c FROM fact_payments
GROUP BY order_id,payment_sequential HAVING c>1;
SELECT review_id,order_id,COUNT(*) c FROM fact_reviews
GROUP BY review_id,order_id HAVING c>1;

/* Referential integrity */
SELECT COUNT(*) orphan_orders FROM fact_orders o
LEFT JOIN dim_customer c USING(customer_id) WHERE c.customer_id IS NULL;
SELECT COUNT(*) orphan_items FROM fact_order_items i
LEFT JOIN fact_orders o USING(order_id) WHERE o.order_id IS NULL;
SELECT COUNT(*) orphan_payments FROM fact_payments p
LEFT JOIN fact_orders o USING(order_id) WHERE o.order_id IS NULL;
SELECT COUNT(*) orphan_reviews FROM fact_reviews r
LEFT JOIN fact_orders o USING(order_id) WHERE o.order_id IS NULL;

/* Missing item coverage */
SELECT COUNT(*) total_orders,
       SUM(i.order_id IS NOT NULL) orders_with_items,
       SUM(i.order_id IS NULL) orders_without_items
FROM fact_orders o LEFT JOIN (SELECT DISTINCT order_id FROM fact_order_items) i USING(order_id);

/* Review multiplicity */
WITH x AS (SELECT order_id,COUNT(*) review_count FROM fact_reviews GROUP BY order_id)
SELECT (SELECT COUNT(*) FROM fact_reviews) total_review_records,
       COUNT(*) orders_with_reviews,
       SUM(review_count=1) orders_with_one_review,
       SUM(review_count>1) orders_with_multiple_reviews,
       MAX(review_count) maximum_reviews_per_order FROM x;

/* Payment anomaly audit */
SELECT COUNT(*) total_payment_records,
 COUNT(DISTINCT order_id) orders_with_payments,
 SUM(payment_type IS NULL) missing_type,
 SUM(payment_type='not_defined') undefined_type,
 SUM(payment_installments IS NULL) missing_installments,
 SUM(payment_installments=0) zero_installments,
 SUM(payment_installments<0) negative_installments,
 SUM(payment_value IS NULL) missing_value,
 SUM(payment_value=0) zero_value,
 SUM(payment_value<0) negative_value
FROM fact_payments;

/* Calendar-date late flag verification */
SELECT COUNT(*) delivered_orders,
 SUM(is_late) stored_late_orders,
 SUM(DATE(order_delivered_customer_date)>DATE(order_estimated_delivery_date)) calculated_late_orders,
 SUM(is_late<>(DATE(order_delivered_customer_date)>DATE(order_estimated_delivery_date))) mismatched_orders
FROM fact_orders WHERE is_delivered=1;

/* Item shipping-limit eligibility */
SELECT COUNT(*) evaluated_items,
 SUM(o.order_delivered_carrier_date>i.shipping_limit_date) late_shipped_items,
 ROUND(100*AVG(o.order_delivered_carrier_date>i.shipping_limit_date),2) late_shipping_rate_pct
FROM fact_order_items i JOIN fact_orders o USING(order_id)
WHERE o.order_delivered_carrier_date IS NOT NULL AND i.shipping_limit_date IS NOT NULL;

