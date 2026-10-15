# 📉 Ecommerce Sales Analysis 2024–2025: Revenue Loss Root-Cause Analysis

An end-to-end data analytics project that investigates why an e-commerce company's sales fell in 2025 compared to 2024, quantifies the revenue losses, and estimates how much revenue could have been recovered.

**Tools used:** Python (data cleaning) · MySQL (analysis) · Power BI (dashboard)

---

## 📌 Problem Statement

Company sales dropped by 18% YoY in 2025 compared to 2024. Management wants to identify the root cause, quantify the losses, and simulate an action plan to recover lost revenue.

---

## 📂 Dataset

- **File:** `Ecommerce_Sales_2024_2025_Cleaned_Data.csv`
- **Records:** 40,471 orders (01-01-2024 to 31-12-2025)
- **Columns (15):**

| Column | Description |
|---|---|
| `Order_ID` | Unique order identifier |
| `Order_Date` | Date of the order |
| `Customer_ID` | Unique customer identifier |
| `Customer_Segment` | Consumer / Corporate / Home Office |
| `Region` | East / North / South / West |
| `Product_Category` | Product category |
| `Sub_Category` | Product sub-category |
| `Product_Name` | Name of the product |
| `Unit_Price` | Price per unit |
| `Quantity` | Units ordered |
| `Discount_Applied` | Discount applied on the order |
| `Payment_Method` | Mode of payment |
| `Order_Status` | Delivered / Returned / Cancelled |
| `Shipping_Delay_Days` | Shipping delay in days |
| `Customer_Rating` | Customer rating |

---

## 🛠️ Project Workflow

1. **Data Cleaning (Python):** Raw sales data was cleaned in Jupyter Notebook and exported as the cleaned CSV.
2. **Data Analysis (MySQL):** Cleaned data was loaded into a MySQL table (`SDB`) and analysed with SQL (CTEs, `CASE WHEN`, aggregations, `NULLIF`).
3. **Dashboard (Power BI):** An interactive dashboard was built to visualise the findings, with slicers for Order Date, Order Status, Customer Segment and Region.

---

## 🔍 Analysis Performed

- Comparing 2024 vs 2025 Gross Sales, Net Sales and Total Orders
- Comparing revenue lost from Cancelled and Returned orders (2024 vs 2025)
- Investigating the rise in cancellations by Region
- Checking average shipping delay in the West region
- Comparing Total Orders by Customer Segment (2024 vs 2025)
- Comparing Total Orders by Sub-Category within the Corporate segment
- Comparing Total Orders by Sub-Category (2024 vs 2025)
- Checking Average Customer Rating by Region
- Checking Average Discount by Sub-Category
- Checking whether higher discounts led to higher Net Sales
- Estimating potential revenue recovery

---

## 📊 Key Findings

### 1. Sales Overview
- Total orders grew by **2.22%** in 2025, but net sales still dropped by **21.03%** (not the 18% mentioned in the business problem).

### 2. Cancelled vs Returned Revenue Loss
- Total lost revenue increased from **₹5.53 Crore (2024)** to **₹5.68 Crore (2025)**.
- Revenue lost due to returned orders went down, but loss from cancelled orders saw a significant jump in 2025.

### 3. West Region: Cancellations and Shipping Delays
- Cancellations in the West region jumped from **182 (2024)** to **616 (2025)**, while other regions showed minor changes.
- Average shipping delay in the West increased from **2.01 days** to **6.23 days**.
- Average customer rating in the West dropped from **3.91 to 3.14** (a drop of 0.78), while other regions stayed stable between 3.86 and 3.92.

### 4. Customer Segments
- Consumer orders grew from 8,562 to 9,536 and Home Office from 4,640 to 5,393.
- **Corporate orders fell from 6,811 to 5,529.**

### 5. Laptop Volume Crash
- Within the Corporate segment, Paper and Laptops saw major drops.
- Overall Laptop orders fell from **1,413 to 769** (almost a 45.6% drop). Since Laptops have a much higher price point, this was the main driver behind the overall revenue loss.

### 6. Discount Strategy Did Not Work
- Most sub-categories maintained an average discount of around 8%–9%.
- Furnishings, Bookcases, Tables and Chairs saw average discounts jump to **over 20%–21%** in 2025.
- Chairs and Furnishings had slight net sales gains, but **Tables and Bookcases suffered revenue drops**, making the high-discount strategy largely ineffective.

---

## 💰 Estimated Potential Revenue Recovery

| Issue | Estimated Recoverable Revenue |
|---|---|
| Orders cancelled in 2025 with shipping delay > 2 days (738 orders) | ₹1.43 Crore (₹14,370,678.45) |
| Laptop volume drop (1,248 → 675 delivered orders; 573 lost orders) | ₹4.00 Crore (₹39,962,889.85) |
| Tables & Bookcases deficit despite ~21% discounts (₹8.88L + ₹17.85L) | ₹26.73 Lakhs |
| **Total Potential Revenue Recovery** | **₹5.70 Crore (₹57,006,531.05)** |

---

## 📈 Power BI Dashboard

The dashboard (`Ecommerce_Sales_2024_2025_Dashboard.pdf`) includes:

- **KPI cards:** Gross Sales (1.07bn), Net Sales (848.71M), Total Orders (40.471K), Avg Customer Rating (3.81)
- **Order Cancellations by Region** (2024 vs 2025)
- **Total Orders by Customer Segment** (2024 vs 2025)
- **Laptop Volume Crash** (2024 vs 2025)
- **Avg Shipping Delay by Region** (2024 vs 2025)
- **Cancelled Orders by Customer Segment** (2024 vs 2025)
- **Order Status** breakdown: Delivered 36.04K (89.05%), Returned 2.48K (6.12%), Cancelled
- **Slicers:** Order Date, Order Status, Customer Segment, Region

---

## 👤 Author

**Sunny Yadav**
GitHub: [Sunny7600](https://github.com/Sunny7600)
