# Data Quality and Preparation Report

## Validated analytical tables

| Table | Primary grain | Rows |
|---|---|---:|
| `fact_orders` | `order_id` | 99,441 |
| `fact_order_items` | `(order_id, order_item_id)` | 112,650 |
| `fact_payments` | `(order_id, payment_sequential)` | 103,886 |
| `fact_reviews` | `(review_id, order_id)` | 99,222 |

## Core controls

- Candidate keys and duplicate counts were validated before analysis.
- Tested fact-to-dimension relationships contained no material orphan records.
- Facts were aggregated independently to order grain before combining them.
- Raw anomalies were preserved and handled through metric-specific validity rules.
- Incomplete September–October 2018 records were excluded from like-for-like growth comparisons.

## Important findings and treatments

### Orders

- 99,441 total orders.
- 98,666 orders had item records; 775 did not.
- 96,470 delivered orders had valid delivery dates.
- Late delivery uses calendar-date comparison, eliminating 1,292 false late flags caused by same-date timestamp differences.
- Final late-delivery count: 6,534; validation mismatch: 0.

### Order items

- 112,650 rows and 112,650 distinct `(order_id, order_item_id)` keys.
- No negative price or freight values.
- 1,627 items had an unknown translated product category.
- 110,195 items were eligible for shipping-limit evaluation; 10,270 were late shipped (9.32%).

### Reviews

- 99,222 review records covering 98,671 orders.
- 547 orders had multiple reviews; maximum three reviews per order.
- Reviews were aggregated to order grain before joining.
- Seller-review analysis uses only single-seller orders because the source review does not identify a seller.

### Payments

- 103,886 raw records.
- Removed nine zero-value/undefined records for business analysis, leaving 103,877 valid records.
- 99,437 orders had valid payments.
- Two zero-installment credit-card records and three undefined payment types were investigated.
- The credit-card installment export contains 73,972 distinct orders with installment counts from 1 to 24.

## Metric-specific populations

Different KPIs intentionally use different denominators:

- Growth/value metrics: orders with item records.
- Customer metrics: all valid orders linked to `customer_unique_id`.
- Delivery metrics: delivered orders with valid delivery dates.
- Review metrics: reviewed orders after order-level review aggregation.
- Seller satisfaction: reviewed, delivered, single-seller orders.
- Installment analysis: eligible credit-card orders only.

This prevents missing fields in one domain from unnecessarily excluding an otherwise valid order from another domain.

