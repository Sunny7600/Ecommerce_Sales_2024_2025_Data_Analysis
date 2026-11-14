# 📉 E-commerce Sales Decline Analysis (2024–2025)

### Why did Net Sales fall 18% while orders grew? An end-to-end analysis using **Python, SQL and Power BI**

![Python](https://img.shields.io/badge/Python-Pandas%20%7C%20NumPy-3776AB?logo=python&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-MySQL-4479A1?logo=mysql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811?logo=powerbi&logoColor=black)
![Status](https://img.shields.io/badge/Status-Completed-brightgreen)

---

## 📌 Table of Contents
1. [Business Problem](#-business-problem)
2. [Key Results at a Glance](#-key-results-at-a-glance)
3. [Dataset](#-dataset)
4. [Tools & Workflow](#-tools--workflow)
5. [Data Cleaning (Python)](#-data-cleaning-python)
6. [Analysis Framework (SQL)](#-analysis-framework-sql)
7. [Key Findings](#-key-findings)
8. [Dashboard (Power BI)](#-dashboard-power-bi)
9. [Business Recommendations](#-business-recommendations)
10. [Repository Structure](#-repository-structure)
11. [How to Reproduce](#-how-to-reproduce)
12. [Limitations](#-limitations)
13. [Skills Demonstrated](#-skills-demonstrated)
14. [Contact](#-contact)

---

## 🎯 Business Problem

An e-commerce company's **Net Sales dropped 18% YoY in 2025**, even though the number of orders did **not** fall. Management wants to know:

| Question | Part of project |
|---|---|
| **What happened?** Where exactly did the loss come from? | Part A – Executive Summary |
| **Why did it happen?** What are the root causes? | Part B – Root Cause Analysis |
| **Who do we act on first?** Which customers are at risk? | Part C – Customer Risk |

---

## ⚡ Key Results at a Glance

| Metric | 2024 | 2025 | YoY |
|---|---|---|---|
| **Net Sales** | 561.65M | 460.25M | **-18.06%** |
| **Orders** | 21,231 | 21,777 | **+2.57%** |
| **Average Order Value** | 26,454 | 21,135 | **-20.11%** |
| **Avg Discount** | 8.57% | 12.46% | +3.89 pts |
| **Realized Revenue** (Delivered only) | 503.18M | 399.36M | **-20.63%** |

> **Insight:** This is **not a demand problem**. Customers kept ordering, but each order was worth ~20% less. The cause is pricing, product mix and fulfilment.

---

## 📂 Dataset

- **Source:** E-commerce order data, Jan 2024 – Dec 2025
- **Size:** 43,653 raw rows → **43,008 clean rows**, 5,671 unique customers
- **Grain:** One row per order

| Column | Description |
|---|---|
| `Order_ID`, `Order_Date`, `Customer_ID` | Order and customer identifiers |
| `Customer_Segment` | Consumer / Corporate / Home Office |
| `Region` | North / South / East / West |
| `Product_Category`, `Sub_Category`, `Product_Name` | Product hierarchy |
| `Unit_Price`, `Quantity`, `Discount_Applied` | Pricing fields |
| `Payment_Method`, `Order_Status` | Payment type; Delivered / Returned / Cancelled |
| `Shipping_Delay_Days`, `Customer_Rating` | Fulfilment and satisfaction |

### Metric Definitions
```
Gross Sales      = Unit_Price × Quantity
Net Sales        = Gross Sales × (1 − Discount_Applied)      -- all orders
Realized Revenue = Net Sales of Delivered orders only
```

---

## 🛠 Tools & Workflow

```
Raw CSV  ──►  Python (Pandas)  ──►  Cleaned CSV  ──►  SQL (MySQL)  ──►  Power BI  ──►  Insights & Actions
            data cleaning          43,008 rows       analysis          3-page dashboard
```

| Tool | Used for |
|---|---|
| **Python** (Pandas, NumPy, Jupyter) | Data cleaning and validation |
| **SQL** (MySQL) | Views, CTEs, window functions, aggregations, customer risk scoring |
| **Power BI** | Interactive 3-page dashboard, DAX measures, slicers |
| **PowerPoint** | Business presentation of findings |

---

## 🧹 Data Cleaning (Python)

| Check | Raw | Clean |
|---|---|---|
| Rows | 43,653 | 43,008 |
| Duplicate rows | 645 | 0 |
| Negative quantities | 160 | 0 |
| `Order_Date` | Mixed text formats | Proper date type, 0 failed |
| `Shipping_Delay_Days` blanks | 1,314 unexplained | Only 2,095 cancelled orders remain blank (expected) |

**Steps performed**
1. Dropped duplicate rows, so `Order_ID` is now unique
2. Trimmed whitespace and standardised text casing (segment, region, category, status)
3. Fixed label inconsistencies (`Upi` → `UPI`, `Paypal` → `PayPal`)
4. Parsed mixed date formats into a single date type
5. Converted negative quantities on returned orders to positive values
6. Left delay and rating blank for cancelled orders (they never shipped)
7. Filled other missing shipping delays using the **region + status + month median**
8. Validated prices, discounts and quantities for impossible values

---

## 🔍 Analysis Framework (SQL)

The full analysis is in [`Ecommerce_Sales_2024_2025_Data_Analysis.sql`](Ecommerce_Sales_2024_2025_Data_Analysis.sql). It starts with a reusable base view (`vw_sales`) that adds year, month, half, quarter, gross and net sales and discount bands, so every query uses identical metric logic.

- **Part A – What happened:** KPI summary, monthly YoY trend, and breakdowns by category, sub-category, segment, region, segment × category matrix and top 10 products by loss
- **Part B – Why it happened:** price, discount, return, shipping-delay, cancellation and rating drill-downs
- **Part C – Risk observation:** customer-level 2024 vs 2025 comparison and risk classification

Each query block includes written observations, so the file reads as a short analysis report.

---

## 💡 Key Findings

### Part A: What happened?
- **Laptops** lost 87.93M (-43.17%), which is **86.7% of the total company loss**
- **Corporate** customers lost 100.77M (-32.00%), which is **99.4% of the total loss**. Consumer (-0.67%) and Home Office (+0.29%) were flat
- **Corporate × Electronics** alone is the biggest hole at -89.07M (-40.08%)
- Every region declined (North -22.67%, East -21.53%, West -15.53%, South -11.92%), so the loss is broad rather than regional
- Furniture was the only category to grow (+7.37M), partly masking the damage
- The break was a **sudden step-change in March–April 2025**, not a slow slide, pointing to a specific event

### Part B: Why did it happen? (3 root causes)

| # | Root Cause | Evidence |
|---|---|---|
| **1** | **Laptop price hike** (~9% list price rise from March 2025) | Laptop units **-54.22%** (Mar–Dec); only **36.30%** of Corporate laptop buyers retained |
| **2** | **Furniture deep discounts** (30–40% tiers introduced March 2025) | Furniture avg discount rose to **21.32%**; deep-discount return rate is **20.36%** vs ~5–6% for other bands, roughly **4× higher** |
| **3** | **West region logistics failure** (from July 2025) | West avg shipping delay jumped from ~2 to **10.19 days**; cancellations rose from ~4% to **20.79%**; ratings fall to **2.4** for 9+ day delays vs 3.9 for 0–3 days |

### Part C: Who do we act on first?
Of the **4,387 customers who bought in 2024**, classified by their 2025 behaviour:

| Risk Level | Customers | Share |
|---|---|---|
| 🟢 Healthy | 1,325 | 30.20% |
| 🟠 Medium Risk | 1,033 | 23.55% |
| 🔴 High Risk | 559 | 12.74% |
| ⚫ Lost (Win-back) | 1,470 | 33.51% |

- **Revenue at Risk: 275.12M (48.98%)**
- The **top 10 accounts by 2024 sales are all Corporate**, and nearly all have almost stopped buying in 2025 (for example, CUST-14849 went from 2.42M to 0.00M)

---

## 📊 Dashboard (Power BI)

A 3-page interactive dashboard with slicers for Customer Segment, Region and Category.

| Page | Question answered |
|---|---|
| **1. Executive Summary** | What happened? |
| **2. Root Cause Analysis** | Why did it happen? |
| **3. Customer Risk** | Who do we act on first? |

> 📸 **Add your screenshots here** (create an `images/` folder, then uncomment):
> ```
> ![Executive Summary](images/01_executive_summary.png)
> ![Root Cause Analysis](images/02_root_cause_analysis.png)
> ![Customer Risk](images/03_customer_risk.png)
> ```

📄 Full dashboard export: [`Ecommerce_Sales_2024_2025_Dashboard.pdf`](Ecommerce_Sales_2024_2025_Dashboard.pdf)
🧾 Power BI file: [`Ecommerce_Sales_2024_2025_Dashboard.pbix`](Ecommerce_Sales_2024_2025_Dashboard.pbix)
🎤 Presentation: [`Ecommerce_Sales__2024_2025_Presentation.pptx`](Ecommerce_Sales__2024_2025_Presentation.pptx)

---

## ✅ Business Recommendations

1. **Call high-risk and medium-risk accounts immediately.** Account managers should start with the top Corporate accounts
2. **Launch a win-back offer for the 1,470 lost customers**, starting with lapsed Corporate accounts (bundle or contract pricing)
3. **Review the laptop pricing decision.** A ~9% increase cost far more in lost volume than it gained in price
4. **Re-examine the 30–40% furniture discount tiers.** They lift orders but drive a ~20% return rate
5. **Audit carrier and warehouse performance in the West region**, where delays and cancellations spiked from July 2025

---

## 📁 Repository Structure

```
├── Ecommerce_Sales_2024_2025_Raw_Data.csv          # Original data (43,653 rows)
├── Ecommerce_Sales_2024_2025_Data_Cleaning.ipynb   # Python cleaning notebook
├── Ecommerce_Sales_2024_2025_Cleaned_Data.csv      # Cleaned data (43,008 rows)
├── Ecommerce_Sales_2024_2025_Data_Analysis.sql     # SQL analysis with observations
├── Ecommerce_Sales_2024_2025_Dashboard.pbix        # Power BI dashboard
├── Ecommerce_Sales_2024_2025_Dashboard.pdf         # Dashboard export
├── Ecommerce_Sales__2024_2025_Presentation.pptx    # Business presentation
└── README.md
```

---

## 🚀 How to Reproduce

1. **Clean the data:** open `Ecommerce_Sales_2024_2025_Data_Cleaning.ipynb` in Jupyter and run all cells (requires `pandas`, `numpy`)
2. **Load into SQL:** run the first section of the `.sql` file to create `Sales_DB`, import the cleaned CSV into the `Sales_DB` table, then run the remaining queries
3. **Explore the dashboard:** open the `.pbix` file in Power BI Desktop

---

## 🚧 Limitations

- No cost or margin data is available, so this is a **revenue analysis, not a profit analysis**
- The analysis shows strong associations and timing (for example, the March 2025 price and discount changes) but cannot prove causation without further testing

---

## 🧠 Skills Demonstrated

- **Data cleaning:** duplicates, inconsistent text, mixed date formats, negative values, missing-value handling
- **SQL:** views, CTEs, window functions, conditional aggregation, YoY analysis, customer segmentation
- **Power BI:** data modelling, DAX measures, multi-page dashboard design, slicers, conditional formatting
- **Analytical thinking:** structuring a problem as *what → why → who*, and isolating drivers (product, segment, region, price, discount, logistics)
- **Business communication:** turning numbers into recommendations for stakeholders

---

## 📬 Contact

**Sunny Yadav**
📧 Ysunny7600@gmail.com
🔗 [LinkedIn](https://www.linkedin.com/in/sunny-yadav-180ba2227/) · [GitHub](https://github.com/Sunny7600)

⭐ If you found this project useful, feel free to star the repository!
