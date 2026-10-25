# Final Business Findings

## 1. Growth

| Metric | Jan–Aug 2017 | Jan–Aug 2018 | Change |
|---|---:|---:|---:|
| Itemized orders | 22,693 | 53,774 | +136.96% |
| Gross ordered value | R$3.61M | R$8.64M | +139.42% |
| Average order value | R$159.09 | R$160.74 | +1.04% |
| Unique customers | 22,320 | 52,743 | +136.30% |

Growth was overwhelmingly volume-led. Customer acquisition and order volume expanded at similar rates, while average order value remained broadly stable.

## 2. Customer behaviour and geography

- Orders per customer remained close to one: **1.03 in 2017** and **1.02 in 2018**.
- Repeat customers increased from **587 to 1,157**, but repeat rate fell from **2.63% to 2.19%** because acquisition grew faster.
- São Paulo generated **41,375 orders** and **37.38%** of gross ordered value.
- Rio de Janeiro and Minas Gerais contributed **13.44%** and **11.72%** of value respectively.
- Geographic service quality varied materially: Alagoas had a **21.41%** late-delivery rate, while large markets such as São Paulo performed much better at **4.49%**.

## 3. Products and freight

- Product value: **R$13.59M**
- Freight value: **R$2.25M**
- Gross ordered value: **R$15.84M**
- Freight share: **14.21%**
- Average freight per itemized order: **R$22.82**
- Product/freight correlation: **0.4128**, a moderate positive relationship.

Health & Beauty was the largest category by value and added **R$602,004.12** between the comparable periods. Watches & Gifts added **R$547,359.35**. Category value was distributed across several major categories rather than dominated by one.

Freight burden varied by destination. Maranhão recorded **20.85%**, compared with **12.14%** in São Paulo. Higher freight shares were generally associated with lower product values and slightly weaker review outcomes.

## 4. Delivery and customer satisfaction

| Delivery status | Orders | Average review | Low-rating rate | Positive-rating rate |
|---|---:|---:|---:|---:|
| On time | 89,936 | 4.29 | 9.23% | 82.64% |
| Late | 6,534 | 2.27 | 62.35% | 26.74% |

The valid delivered cohort contained **96,470 orders**, of which **6.77%** were late. Satisfaction deteriorated quickly as delays grew: average review score fell from **4.29** for on-time/early orders to **3.29** for delays of 1–3 days and **2.11** for delays of 4–7 days.

Delivery reliability is therefore one of the clearest customer-experience levers in the dataset.

## 5. Seller operations and risk

The defensible seller cohort contains **784 sellers**, each with at least 20 reviewed, single-seller, delivered orders.

- Benchmark late-delivery rate: **6.85%**
- Benchmark review score: **4.17**
- High-impact-risk sellers: **50**
- High-impact-risk value: **R$2.23M**, or **17.94%** of qualified value

Seller `7c67e1448b00f6e969d365cea6b010ab` was the clearest intervention priority:

- 963 orders and 1,342 items
- R$234,899.94 in order value
- 30.70% late-shipping rate
- 9.24% late-delivery rate
- 3.51 average review score
- 25.08% low-rating rate

Late shipping should be preferred when assessing seller-controlled execution; late delivery also reflects carrier and network performance.

## 6. Payments

- Valid payment orders: **99,437**
- Total payment value: **R$16.01M**
- Credit-card share of value: **78.34%**
- Boleto: **17.92%**
- Voucher: **2.37%**
- Debit card: **1.36%**

Payment structure was simple for most orders:

- Single record and method: **97.02%**
- Multiple methods: **2.26%**
- Multiple records of the same method: **0.72%**

The credit-card installment dataset contains **73,972 unique orders**. A total of **62.32%** used three installments or fewer. Tableau calculated an installment/payment-value correlation of **0.3308**, indicating a moderate positive relationship rather than a deterministic one.

## Recommendations

1. Protect volume-led growth by improving repeat purchase journeys rather than relying entirely on acquisition.
2. Prioritize delivery interventions in high-volume, high-lateness states—especially Rio de Janeiro—and investigate extreme regional freight burdens.
3. Work directly with high-impact-risk sellers on shipping-limit compliance, using late shipping as the primary operational KPI.
4. Maintain strong credit-card support while monitoring installment affordability and high-value outliers.
5. Preserve grain-safe data models and clearly separate marketplace value, payments, seller attribution and customer-review measures.

