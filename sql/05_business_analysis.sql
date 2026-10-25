/* Olist Marketplace Analytics — 05 Final business-analysis queries (MySQL 8+) */

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

/* 13. Comparable category growth */
WITH category_year AS (
 SELECT COALESCE(p.product_category_name_english,'Unknown') category,
        YEAR(o.order_purchase_timestamp) order_year,SUM(i.item_value) category_value
 FROM fact_orders o JOIN fact_order_items i USING(order_id)
 LEFT JOIN dim_product p USING(product_id)
 WHERE YEAR(o.order_purchase_timestamp) IN(2017,2018)
   AND MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 8
 GROUP BY category,YEAR(o.order_purchase_timestamp)
)
SELECT category,
 SUM(CASE WHEN order_year=2017 THEN category_value ELSE 0 END) value_2017,
 SUM(CASE WHEN order_year=2018 THEN category_value ELSE 0 END) value_2018,
 ROUND(SUM(CASE WHEN order_year=2018 THEN category_value ELSE -category_value END),2) incremental_value
FROM category_year GROUP BY category ORDER BY incremental_value DESC;

/* 14. Freight burden by customer state */
WITH order_economics AS (
 SELECT order_id,SUM(price) product_value,SUM(freight_value) freight_value,
        SUM(item_value) gross_ordered_value,COUNT(*) item_count
 FROM fact_order_items GROUP BY order_id
)
SELECT c.customer_state,COUNT(*) total_orders,SUM(e.item_count) total_items,
 ROUND(SUM(e.product_value),2) product_value,ROUND(SUM(e.freight_value),2) freight_value,
 ROUND(AVG(e.freight_value),2) avg_freight_per_order,
 ROUND(100*SUM(e.freight_value)/SUM(e.gross_ordered_value),2) freight_share_pct
FROM order_economics e JOIN fact_orders o USING(order_id)
JOIN dim_customer c USING(customer_id)
GROUP BY c.customer_state HAVING COUNT(*)>=100 ORDER BY freight_share_pct DESC;

/* 15. Delay buckets and review outcomes */
WITH reviewed_orders AS (
 SELECT order_id,AVG(review_score) review_score FROM fact_reviews GROUP BY order_id
), delivery AS (
 SELECT o.order_id,r.review_score,
 DATEDIFF(DATE(o.order_delivered_customer_date),DATE(o.order_estimated_delivery_date)) delay_days
 FROM fact_orders o LEFT JOIN reviewed_orders r USING(order_id) WHERE o.is_delivered=1
)
SELECT CASE WHEN delay_days<=0 THEN 'On time or early'
            WHEN delay_days<=3 THEN '1-3 days late'
            WHEN delay_days<=7 THEN '4-7 days late'
            WHEN delay_days<=14 THEN '8-14 days late'
            ELSE '15+ days late' END delay_bucket,
 COUNT(*) total_orders,COUNT(review_score) reviewed_orders,
 ROUND(AVG(delay_days),2) avg_delay_days,ROUND(AVG(review_score),2) avg_review_score,
 ROUND(100*AVG(review_score<=2),2) low_rating_rate_pct,
 ROUND(100*AVG(review_score>=4),2) positive_rating_rate_pct
FROM delivery GROUP BY delay_bucket
ORDER BY MIN(CASE WHEN delay_days<=0 THEN 1 WHEN delay_days<=3 THEN 2
                  WHEN delay_days<=7 THEN 3 WHEN delay_days<=14 THEN 4 ELSE 5 END);

/* 16. Payment combinations for multi-record orders */
WITH valid AS (
 SELECT * FROM fact_payments WHERE payment_type IS NOT NULL
 AND payment_type<>'not_defined' AND payment_value>0
), x AS (
 SELECT order_id,COUNT(*) payment_records,
 GROUP_CONCAT(DISTINCT payment_type ORDER BY payment_type SEPARATOR ' + ') payment_combination,
 SUM(payment_value) payment_value
 FROM valid GROUP BY order_id HAVING COUNT(*)>1
)
SELECT payment_combination,COUNT(*) total_orders,
 ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER(),2) share_of_multi_record_orders_pct,
 ROUND(AVG(payment_records),2) avg_payment_records,MAX(payment_records) maximum_payment_records,
 ROUND(AVG(payment_value),2) avg_payment_value
FROM x GROUP BY payment_combination ORDER BY total_orders DESC;

/* 17. Credit-card installment buckets */
WITH card_orders AS (
 SELECT order_id,MAX(payment_installments) installments,SUM(payment_value) payment_value
 FROM fact_payments WHERE payment_type='credit_card' AND payment_value>0
 AND payment_installments>=1 GROUP BY order_id
)
SELECT CASE WHEN installments=1 THEN '1 installment'
            WHEN installments<=3 THEN '2-3 installments'
            WHEN installments<=6 THEN '4-6 installments'
            WHEN installments<=9 THEN '7-9 installments'
            WHEN installments<=12 THEN '10-12 installments'
            ELSE '13+ installments' END installment_bucket,
 COUNT(*) total_orders,ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER(),2) order_share_pct,
 ROUND(AVG(installments),2) avg_installments,ROUND(AVG(payment_value),2) avg_payment_value,
 MIN(payment_value) minimum_payment_value,MAX(payment_value) maximum_payment_value
FROM card_orders GROUP BY installment_bucket
ORDER BY MIN(installments);

/* 18. Seller benchmark cohort and risk inputs */
WITH order_seller AS (
 SELECT i.order_id,COUNT(DISTINCT i.seller_id) seller_count,MIN(i.seller_id) seller_id,
        COUNT(*) item_count,SUM(i.item_value) order_value,
        AVG(o.order_delivered_carrier_date>i.shipping_limit_date) late_shipping
 FROM fact_order_items i JOIN fact_orders o USING(order_id) GROUP BY i.order_id
), reviews AS (SELECT order_id,AVG(review_score) score FROM fact_reviews GROUP BY order_id),
seller AS (
 SELECT s.seller_id,COUNT(*) total_orders,SUM(s.item_count) total_items,
        SUM(s.order_value) total_order_value,AVG(s.late_shipping) late_shipping_rate,
        AVG(o.is_late) late_delivery_rate,AVG(r.score) avg_review_score,
        AVG(r.score<=2) low_rating_rate
 FROM order_seller s JOIN fact_orders o USING(order_id) JOIN reviews r USING(order_id)
 WHERE s.seller_count=1 AND o.is_delivered=1 GROUP BY s.seller_id HAVING COUNT(*)>=20
)
SELECT *,ROUND(100*late_shipping_rate,2) late_shipping_rate_pct,
 ROUND(100*late_delivery_rate,2) late_delivery_rate_pct,
 ROUND(100*low_rating_rate,2) low_rating_rate_pct,
 ROUND(100*AVG(late_delivery_rate) OVER(),2) benchmark_late_delivery_rate,
 ROUND(AVG(avg_review_score) OVER(),2) benchmark_avg_review_score
FROM seller;

