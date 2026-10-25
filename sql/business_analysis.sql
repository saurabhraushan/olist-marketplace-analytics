/* Olist Marketplace Analytics — final portfolio queries (MySQL 8+) */

/* 1. Like-for-like growth: Jan-Aug 2017 vs Jan-Aug 2018 */
WITH order_value AS (
    SELECT order_id, SUM(item_value) AS gross_ordered_value
    FROM fact_order_items GROUP BY order_id
)
SELECT YEAR(o.order_purchase_timestamp) AS order_year,
       COUNT(*) AS itemized_orders,
       ROUND(SUM(v.gross_ordered_value),2) AS gross_ordered_value,
       ROUND(AVG(v.gross_ordered_value),2) AS avg_order_value
FROM fact_orders o JOIN order_value v USING (order_id)
WHERE MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 8
  AND YEAR(o.order_purchase_timestamp) IN (2017,2018)
GROUP BY YEAR(o.order_purchase_timestamp);

/* 2. Customer frequency and repeat rate */
WITH customer_period AS (
    SELECT YEAR(o.order_purchase_timestamp) AS order_year,
           c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS orders_in_period
    FROM fact_orders o JOIN dim_customer c USING (customer_id)
    WHERE MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 8
      AND YEAR(o.order_purchase_timestamp) IN (2017,2018)
    GROUP BY YEAR(o.order_purchase_timestamp), c.customer_unique_id
)
SELECT order_year, COUNT(*) AS unique_customers,
       SUM(orders_in_period) AS total_orders,
       ROUND(SUM(orders_in_period)/COUNT(*),2) AS orders_per_customer,
       SUM(orders_in_period=1) AS one_time_customers,
       SUM(orders_in_period>1) AS repeat_customers,
       ROUND(100*SUM(orders_in_period>1)/COUNT(*),2) AS repeat_customer_rate_pct
FROM customer_period GROUP BY order_year;

/* 3. State commercial performance */
WITH order_value AS (
    SELECT order_id, SUM(item_value) AS order_value
    FROM fact_order_items GROUP BY order_id
)
SELECT c.customer_state,
       COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
       COUNT(*) AS total_orders,
       ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS order_share_pct,
       ROUND(SUM(v.order_value),2) AS gross_ordered_value,
       ROUND(100*SUM(v.order_value)/SUM(SUM(v.order_value)) OVER (),2) AS value_share_pct,
       ROUND(AVG(v.order_value),2) AS avg_order_value
FROM fact_orders o JOIN dim_customer c USING (customer_id)
JOIN order_value v USING (order_id)
GROUP BY c.customer_state ORDER BY gross_ordered_value DESC;

/* 4. Category value */
SELECT COALESCE(p.product_category_name_english,'Unknown') AS product_category,
       COUNT(DISTINCT i.order_id) AS total_orders,
       ROUND(SUM(i.item_value),2) AS gross_ordered_value,
       ROUND(100*SUM(i.item_value)/SUM(SUM(i.item_value)) OVER (),2) AS value_share_pct
FROM fact_order_items i LEFT JOIN dim_product p USING (product_id)
GROUP BY COALESCE(p.product_category_name_english,'Unknown')
ORDER BY gross_ordered_value DESC;

/* 5. Freight economics */
SELECT COUNT(DISTINCT order_id) AS orders_with_items,
       COUNT(*) AS total_items,
       ROUND(SUM(price),2) AS product_value,
       ROUND(SUM(freight_value),2) AS freight_value,
       ROUND(SUM(item_value),2) AS gross_ordered_value,
       ROUND(100*SUM(freight_value)/SUM(item_value),2) AS freight_share_pct,
       ROUND(SUM(freight_value)/COUNT(DISTINCT order_id),2) AS avg_freight_per_order
FROM fact_order_items;

/* 6. Delivery and review outcome; reviews first reduced to order grain */
WITH order_reviews AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM fact_reviews GROUP BY order_id
)
SELECT IF(o.is_late=1,'Late delivery','On-time delivery') AS delivery_status,
       COUNT(*) AS delivered_orders,
       COUNT(r.order_id) AS reviewed_orders,
       ROUND(AVG(r.review_score),2) AS avg_review_score,
       ROUND(100*SUM(r.review_score<=2)/COUNT(r.order_id),2) AS low_rating_rate_pct,
       ROUND(100*SUM(r.review_score>=4)/COUNT(r.order_id),2) AS positive_rating_rate_pct
FROM fact_orders o LEFT JOIN order_reviews r USING (order_id)
WHERE o.is_delivered=1
GROUP BY o.is_late;

/* 7. Late delivery by state (minimum 100 delivered orders) */
SELECT c.customer_state, COUNT(*) AS delivered_orders,
       SUM(o.is_late) AS late_orders,
       ROUND(100*SUM(o.is_late)/COUNT(*),2) AS late_delivery_rate_pct,
       ROUND(AVG(o.delivery_days),2) AS avg_delivery_days
FROM fact_orders o JOIN dim_customer c USING (customer_id)
WHERE o.is_delivered=1
GROUP BY c.customer_state HAVING COUNT(*)>=100
ORDER BY late_delivery_rate_pct DESC;

/* 8. Single- versus multi-seller delivered orders */
WITH order_seller AS (
    SELECT order_id, COUNT(DISTINCT seller_id) AS seller_count,
           MIN(seller_id) AS seller_id
    FROM fact_order_items GROUP BY order_id
)
SELECT IF(seller_count=1,'Single-seller order','Multi-seller order') AS order_type,
       COUNT(*) AS delivered_orders
FROM order_seller s JOIN fact_orders o USING (order_id)
WHERE o.is_delivered=1 GROUP BY order_type;

/* 9. Seller performance: defensible single-seller review attribution */
WITH order_seller AS (
    SELECT order_id, COUNT(DISTINCT seller_id) AS seller_count,
           MIN(seller_id) AS seller_id, COUNT(*) AS item_count,
           SUM(item_value) AS order_value,
           AVG(order_delivered_carrier_date > shipping_limit_date) AS late_shipping_rate
    FROM fact_order_items JOIN fact_orders USING (order_id)
    GROUP BY order_id
), order_reviews AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM fact_reviews GROUP BY order_id
)
SELECT s.seller_id, COUNT(*) AS total_orders, SUM(s.item_count) AS total_items,
       ROUND(SUM(s.order_value),2) AS total_order_value,
       ROUND(100*AVG(s.late_shipping_rate),2) AS late_shipping_rate_pct,
       ROUND(100*AVG(o.is_late),2) AS late_delivery_rate_pct,
       ROUND(AVG(r.review_score),2) AS avg_review_score,
       ROUND(100*AVG(r.review_score<=2),2) AS low_rating_rate_pct
FROM order_seller s JOIN fact_orders o USING (order_id)
JOIN order_reviews r USING (order_id)
WHERE s.seller_count=1 AND o.is_delivered=1
GROUP BY s.seller_id HAVING COUNT(*)>=20;

/* 10. Payment method share: valid business-analysis records */
WITH valid_payments AS (
    SELECT * FROM fact_payments
    WHERE payment_type IS NOT NULL AND payment_type<>'not_defined'
      AND payment_value>0 AND payment_installments>=0
)
SELECT payment_type, COUNT(*) AS payment_records,
       COUNT(DISTINCT order_id) AS orders_using_method,
       ROUND(SUM(payment_value),2) AS payment_value,
       ROUND(100*SUM(payment_value)/SUM(SUM(payment_value)) OVER (),2) AS payment_value_share_pct
FROM valid_payments GROUP BY payment_type ORDER BY payment_value DESC;

/* 11. Payment-record pattern by order */
WITH valid_payments AS (
    SELECT * FROM fact_payments
    WHERE payment_type IS NOT NULL AND payment_type<>'not_defined' AND payment_value>0
), order_payment AS (
    SELECT order_id, COUNT(*) AS payment_records,
           COUNT(DISTINCT payment_type) AS payment_methods
    FROM valid_payments GROUP BY order_id
)
SELECT CASE WHEN payment_records=1 THEN 'Single record and single method'
            WHEN payment_methods=1 THEN 'Multiple records of same method'
            ELSE 'Multiple payment methods' END AS payment_pattern,
       COUNT(*) AS total_orders,
       ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS order_share_pct,
       ROUND(AVG(payment_records),2) AS avg_payment_records
FROM order_payment GROUP BY payment_pattern ORDER BY total_orders DESC;

/* 12. Credit-card installment export at one row per order */
SELECT order_id, MAX(payment_installments) AS payment_installments,
       SUM(payment_value) AS payment_value
FROM fact_payments
WHERE payment_type='credit_card' AND payment_value>0 AND payment_installments>=1
GROUP BY order_id;

