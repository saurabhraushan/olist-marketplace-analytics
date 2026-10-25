/* Olist Marketplace Analytics — 06 Tableau analytical views */
USE olist_analytics;

CREATE OR REPLACE VIEW vw_tableau_order_summary AS
WITH items AS (
 SELECT order_id,COUNT(*) item_count,COUNT(DISTINCT seller_id) seller_count,
        SUM(price) product_value,SUM(freight_value) freight_value,SUM(item_value) gross_ordered_value
 FROM fact_order_items GROUP BY order_id
), reviews AS (
 SELECT order_id,AVG(review_score) order_review_score FROM fact_reviews GROUP BY order_id
), payments AS (
 SELECT order_id,SUM(payment_value) total_payment_value,COUNT(*) payment_record_count,
        COUNT(DISTINCT payment_type) payment_method_count,
        MAX(payment_installments) maximum_installments
 FROM fact_payments
 WHERE payment_type IS NOT NULL AND payment_type<>'not_defined' AND payment_value>0
 GROUP BY order_id
)
SELECT o.*,c.customer_unique_id,c.customer_state,c.customer_city,
 i.item_count,i.seller_count,(i.seller_count=1) is_single_seller,
 i.product_value,i.freight_value,i.gross_ordered_value,
 r.order_review_score,p.total_payment_value,p.payment_record_count,
 p.payment_method_count,p.maximum_installments
FROM fact_orders o JOIN dim_customer c USING(customer_id)
LEFT JOIN items i USING(order_id) LEFT JOIN reviews r USING(order_id)
LEFT JOIN payments p USING(order_id);

CREATE OR REPLACE VIEW vw_tableau_customer_period AS
SELECT YEAR(o.order_purchase_timestamp) order_year,c.customer_unique_id,
 COUNT(DISTINCT o.order_id) orders_in_period,
 MIN(o.order_purchase_timestamp) first_order_date_in_period,
 MAX(o.order_purchase_timestamp) last_order_date_in_period
FROM fact_orders o JOIN dim_customer c USING(customer_id)
WHERE YEAR(o.order_purchase_timestamp) IN(2017,2018)
  AND MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 8
GROUP BY YEAR(o.order_purchase_timestamp),c.customer_unique_id;

CREATE OR REPLACE VIEW vw_tableau_order_items AS
SELECT i.*,o.order_purchase_timestamp,o.order_delivered_carrier_date,o.is_delivered,o.is_late,
 c.customer_state,s.seller_state,
 COALESCE(p.product_category_name_english,'Unknown') product_category,
 (o.order_delivered_carrier_date>i.shipping_limit_date) is_late_shipped
FROM fact_order_items i JOIN fact_orders o USING(order_id)
JOIN dim_customer c USING(customer_id)
LEFT JOIN dim_seller s USING(seller_id) LEFT JOIN dim_product p USING(product_id);

/* Seller dashboard: reviewed, delivered, single-seller orders only.
   High value = top quartile of qualified sellers by total order value. */
CREATE OR REPLACE VIEW vw_tableau_seller_performance AS
WITH order_seller AS (
 SELECT i.order_id,COUNT(DISTINCT i.seller_id) seller_count,MIN(i.seller_id) seller_id,
        COUNT(*) item_count,SUM(i.item_value) order_value,
        SUM(CASE WHEN o.order_delivered_carrier_date IS NOT NULL
                  AND i.shipping_limit_date IS NOT NULL THEN 1 ELSE 0 END) evaluated_items,
        SUM(CASE WHEN o.order_delivered_carrier_date>i.shipping_limit_date THEN 1 ELSE 0 END) late_shipped_items
 FROM fact_order_items i JOIN fact_orders o USING(order_id)
 GROUP BY i.order_id
), order_reviews AS (
 SELECT order_id,AVG(review_score) review_score FROM fact_reviews GROUP BY order_id
), seller_metrics AS (
 SELECT s.seller_id,COUNT(*) total_orders,SUM(s.item_count) total_items,
        SUM(s.order_value) total_order_value,SUM(s.evaluated_items) evaluated_items,
        SUM(s.late_shipped_items) late_shipped_items,
        SUM(o.is_late) late_orders,COUNT(r.order_id) reviewed_orders,
        SUM(r.review_score) review_score_sum,SUM(r.review_score<=2) low_rated_orders
 FROM order_seller s JOIN fact_orders o USING(order_id)
 JOIN order_reviews r USING(order_id)
 WHERE s.seller_count=1 AND o.is_delivered=1
 GROUP BY s.seller_id HAVING COUNT(r.order_id)>=20
), benchmarked AS (
 SELECT m.*,
        100*m.late_shipped_items/NULLIF(m.evaluated_items,0) late_shipping_rate_pct,
        100*m.late_orders/m.total_orders late_delivery_rate_pct,
        m.review_score_sum/m.reviewed_orders avg_review_score,
        100*m.low_rated_orders/m.reviewed_orders low_rating_rate_pct,
        100*SUM(m.late_orders) OVER()/SUM(m.total_orders) OVER() benchmark_late_delivery_rate,
        SUM(m.review_score_sum) OVER()/SUM(m.reviewed_orders) OVER() benchmark_avg_review_score,
        NTILE(4) OVER(ORDER BY m.total_order_value DESC) value_quartile
 FROM seller_metrics m
)
SELECT b.*,
 CASE
  WHEN value_quartile=1 AND late_delivery_rate_pct>benchmark_late_delivery_rate
       AND avg_review_score<benchmark_avg_review_score THEN 'High-impact risk'
  WHEN value_quartile=1 AND late_delivery_rate_pct<=benchmark_late_delivery_rate
       AND avg_review_score>=benchmark_avg_review_score THEN 'High-value strong performer'
  WHEN value_quartile=1 THEN 'High-value mixed performance'
  WHEN late_delivery_rate_pct>benchmark_late_delivery_rate
       AND avg_review_score<benchmark_avg_review_score THEN 'Operational risk'
  WHEN late_delivery_rate_pct<=benchmark_late_delivery_rate
       AND avg_review_score>=benchmark_avg_review_score THEN 'Strong performer'
  ELSE 'Mixed performance'
 END seller_segment
FROM benchmarked b;

CREATE OR REPLACE VIEW tableau_payments_clean AS
SELECT * FROM fact_payments
WHERE payment_type IS NOT NULL AND payment_type<>'not_defined'
  AND payment_value>0 AND payment_installments>=0;

CREATE OR REPLACE VIEW tableau_credit_installments AS
SELECT order_id,MAX(payment_installments) payment_installments,
       SUM(payment_value) payment_value
FROM fact_payments
WHERE payment_type='credit_card' AND payment_value>0 AND payment_installments>=1
GROUP BY order_id;

/* Export views from MySQL Workbench to CSV and connect each Tableau data source
   to the view whose grain matches the worksheet calculation. */

