Create Database Sales_DB;
Use Sales_DB;
DROP TABLE IF EXISTS Sales_DB;

CREATE TABLE Sales_DB (
    Order_ID VARCHAR(50),
    Order_Date DATE,
    Customer_ID VARCHAR(50),
    Customer_Segment VARCHAR(50),
    Region VARCHAR(50),
    Product_Category VARCHAR(50),
    Sub_Category VARCHAR(50),
    Product_Name VARCHAR(255),
    Unit_Price DECIMAL(10, 2),
    Quantity INT,
    Discount_Applied DECIMAL(5, 2),
    Payment_Method VARCHAR(50),
    Order_Status VARCHAR(50),
    Shipping_Delay_Days INT,
    Customer_Rating INT
);



-- Business Problem: Company Net Sales dropped by 18% YoY in 2025 compared to 2024, even though order count did not fall.
-- Management wants to find where the drop came from, identify the root causes behind it, and flag customers at risk of churn.

-- Analysis Framework:
-- PART A - WHAT HAPPENED : Where exactly did the 18% drop come from? (timeline, category, segment, region, product)
-- PART B - WHY HAPPENED : Root-cause drill-down (pricing, discounting, logistics, customers, returns)
-- PART C - RISK OBSERVATION: Early-warning customer risk scoring

-- Metric Definitions (used in every query below):
-- Gross_Sales = Unit_Price * Quantity
-- Net_Sales = Gross_Sales * (1 - Discount_Applied) -> "Net Sales" of ALL orders. This is the metric that shows the -18% drop.
-- Realized Revenue = Net_Sales of Delivered orders only (Cancelled and Returned orders removed)
-- All "_M" columns are in millions of the currency used in the data. No cost/margin data is available, so this is revenue analysis, not profit analysis.

-- Reusable base view: adds Year / Month / Half / Quarter / Gross / Net / Discount band to every order.
DROP VIEW IF EXISTS vw_sales;
CREATE VIEW vw_sales AS
SELECT s.*,
YEAR(Order_Date) AS Order_Year,
MONTH(Order_Date) AS Order_Month,
CASE WHEN MONTH(Order_Date) <= 6 THEN 'H1' ELSE 'H2' END AS Order_Half,
CONCAT('Q', QUARTER(Order_Date)) AS Order_Quarter,
Unit_Price * Quantity AS Gross_Sales,
Unit_Price * Quantity * (1 - Discount_Applied) AS Net_Sales,
CASE WHEN Discount_Applied = 0 THEN '1. No Discount'
     WHEN Discount_Applied <= 0.10 THEN '2. Low (5-10%)'
     WHEN Discount_Applied <= 0.25 THEN '3. Medium (15-25%)'
     ELSE '4. Deep (30-40%)' END AS Discount_Band
FROM Sales_DB s;

-- Start Analysing Data

-- ======================================================================
-- PART A - WHAT HAPPENED (Where did the 18% drop come from?)
-- ======================================================================

-- Data Quality Check

-- 1. 43,008 rows = 43,008 unique Order_IDs (no duplicates), 5,671 customers, orders from 01-Jan-2024 to 31-Dec-2025 (full 2 years).
-- 2. Shipping_Delay_Days is NULL for exactly 2,095 rows = all Cancelled orders (never shipped), so these NULLs are expected, not data errors.
-- 3. Customer_Rating is NULL for 3,312 rows (2,095 cancelled + 1,132 delivered + 85 returned orders where the customer did not rate). 40 cancelled orders have Quantity = 0, so their value is 0. Data needs no further cleaning.

SELECT COUNT(*) AS Total_Rows,
COUNT(DISTINCT Order_ID) AS Distinct_Orders,
COUNT(DISTINCT Customer_ID) AS Distinct_Customers,
SUM(CASE WHEN Shipping_Delay_Days IS NULL THEN 1 ELSE 0 END) AS Null_Shipping_Delay,
SUM(CASE WHEN Customer_Rating IS NULL THEN 1 ELSE 0 END) AS Null_Rating,
SUM(CASE WHEN Quantity = 0 THEN 1 ELSE 0 END) AS Zero_Qty_Rows,
MIN(Order_Date) AS First_Order,
MAX(Order_Date) AS Last_Order
FROM Sales_DB;

SELECT Order_Status,
COUNT(*) AS Orders,
SUM(CASE WHEN Shipping_Delay_Days IS NULL THEN 1 ELSE 0 END) AS Null_Delay,
SUM(CASE WHEN Customer_Rating IS NULL THEN 1 ELSE 0 END) AS Null_Rating,
SUM(CASE WHEN Quantity = 0 THEN 1 ELSE 0 END) AS Zero_Qty
FROM Sales_DB
GROUP BY Order_Status;

-- -------x--------x---------x----------

-- KPI Summary: Overall Sales Performance (2024 vs 2025) Observation

-- 1. Net Sales fell from 561.65M to 460.25M: a loss of 101.41M, i.e. -18.06% YoY. This confirms the management figure of ~18%.
-- 2. Orders did NOT fall: they rose +2.57% (21,231 -> 21,777). But Average Order Value fell -20.11% (26,454 -> 21,135). The company is still getting orders, but each order is worth much less.
-- 3. Average discount rose from 8.57% to 12.46%. Realized Revenue (Delivered only) fell even more, -20.63%, so cancellations/returns leak an extra ~2.6 points of revenue.
-- 4. Conclusion: this is not a traffic or demand-volume problem. It is a price / product-mix / fulfilment problem.

SELECT Order_Year,
COUNT(*) AS Total_Orders,
COUNT(DISTINCT Customer_ID) AS Active_Customers,
SUM(Quantity) AS Units_Sold,
ROUND(SUM(Gross_Sales) / 1000000.0, 2) AS Gross_Sales_M,
ROUND(SUM(Net_Sales) / 1000000.0, 2) AS Net_Sales_M,
ROUND(SUM(Net_Sales) / COUNT(*), 0) AS Avg_Order_Value,
ROUND(AVG(Discount_Applied) * 100, 2) AS Avg_Discount_Pct,
ROUND(SUM(CASE WHEN Order_Status = 'Delivered' THEN Net_Sales ELSE 0 END) / 1000000.0, 2) AS Realized_Revenue_M
FROM vw_sales
GROUP BY Order_Year;

WITH y AS (
SELECT SUM(CASE WHEN Order_Year = 2024 THEN Net_Sales END) AS S24,
SUM(CASE WHEN Order_Year = 2025 THEN Net_Sales END) AS S25,
SUM(CASE WHEN Order_Year = 2024 AND Order_Status = 'Delivered' THEN Net_Sales END) AS R24,
SUM(CASE WHEN Order_Year = 2025 AND Order_Status = 'Delivered' THEN Net_Sales END) AS R25,
SUM(CASE WHEN Order_Year = 2024 THEN 1 END) AS O24,
SUM(CASE WHEN Order_Year = 2025 THEN 1 END) AS O25
FROM vw_sales)
SELECT ROUND(S24 / 1000000.0, 2) AS Net_Sales_2024_M,
ROUND(S25 / 1000000.0, 2) AS Net_Sales_2025_M,
ROUND((S24 - S25) / 1000000.0, 2) AS Sales_Lost_M,
ROUND((S25 - S24) * 100.0 / S24, 2) AS Net_Sales_YoY_Pct,
ROUND((R25 - R24) * 100.0 / R24, 2) AS Realized_Revenue_YoY_Pct,
ROUND((O25 - O24) * 100.0 / O24, 2) AS Orders_YoY_Pct,
ROUND(((S25 / O25) - (S24 / O24)) * 100.0 / (S24 / O24), 2) AS AOV_YoY_Pct
FROM y;

-- -------x--------x---------x----------

-- Monthly Trend (YoY) Observation

-- 1. Jan 2025 was +19.6% and Feb -1.5%: the year started healthy. The sharp break comes in March (-5.8%) and April (-26.8%).
-- 2. From April to August, sales are down 25% to 29.5% every single month; Sep-Nov are slightly better (-16% to -20%) in the seasonal peak months; Dec is back to -26.2%.
-- 3. Orders are flat or up in almost every month (-2.9% to +9.5%), which again shows the problem is order VALUE, not order count.
-- 4. A sudden step-change in March/April (not a slow slide) points to a specific event in early 2025 (a pricing, policy or operational change), not general market weakness.

WITH t AS (SELECT Order_Month,
SUM(CASE WHEN Order_Year = 2024 THEN Net_Sales ELSE 0 END) AS S24,
SUM(CASE WHEN Order_Year = 2025 THEN Net_Sales ELSE 0 END) AS S25,
SUM(CASE WHEN Order_Year = 2024 THEN 1 ELSE 0 END) AS O24,
SUM(CASE WHEN Order_Year = 2025 THEN 1 ELSE 0 END) AS O25
FROM vw_sales
GROUP BY Order_Month)
SELECT Order_Month,
ROUND(S24 / 1000000.0, 2) AS Sales_2024_M,
ROUND(S25 / 1000000.0, 2) AS Sales_2025_M,
ROUND((S25 - S24) * 100.0 / S24, 2) AS Sales_YoY_Pct,
O24 AS Orders_2024,
O25 AS Orders_2025,
ROUND((O25 - O24) * 100.0 / O24, 2) AS Orders_YoY_Pct
FROM t ORDER BY Order_Month;

-- -------x--------x---------x----------

-- Sales Change by Product Category Observation

-- 1. Electronics lost 101.25M (-24.49%), which is 99.85% of the total net loss.
-- 2. Office Supplies fell 7.52M (-14.28%). Furniture is the only category that grew: +7.37M (+7.71%).
-- 3. The problem is concentrated in Electronics; Furniture growth hides part of the damage.

WITH t AS (SELECT Product_Category,
SUM(CASE WHEN Order_Year = 2024 THEN Net_Sales ELSE 0 END) AS S24,
SUM(CASE WHEN Order_Year = 2025 THEN Net_Sales ELSE 0 END) AS S25
FROM vw_sales 
GROUP BY Product_Category)
SELECT Product_Category,
ROUND(S24 / 1000000.0, 2) AS Sales_2024_M,
ROUND(S25 / 1000000.0, 2) AS Sales_2025_M,
ROUND((S25 - S24) / 1000000.0, 2) AS Change_M,
ROUND((S25 - S24) * 100.0 / S24, 2) AS YoY_Pct,
ROUND((S25 - S24) * 100.0 / SUM(S25 - S24) OVER(), 2) AS Share_Of_Total_Change_Pct
FROM t ORDER BY Change_M ASC;

-- -------x--------x---------x----------

-- Sales Change by Sub-Category Observation

-- 1. Laptops alone lost 87.93M (-43.17%) = 86.7% of the entire company loss.
-- 2. All other Electronics fell only mildly (Phones -3.86%, Monitors -11.74%, Accessories -10.66%).
-- 3. Furniture sub-categories grew (Chairs +13.54%, Furnishings +8.85%), partially offsetting the damage.

WITH t AS (SELECT Sub_Category,
SUM(CASE WHEN Order_Year = 2024 THEN Net_Sales ELSE 0 END) AS S24,
SUM(CASE WHEN Order_Year = 2025 THEN Net_Sales ELSE 0 END) AS S25
FROM vw_sales 
GROUP BY Sub_Category)
SELECT Sub_Category,
ROUND(S24 / 1000000.0, 2) AS Sales_2024_M,
ROUND(S25 / 1000000.0, 2) AS Sales_2025_M,
ROUND((S25 - S24) / 1000000.0, 2) AS Change_M,
ROUND((S25 - S24) * 100.0 / S24, 2) AS YoY_Pct,
ROUND((S25 - S24) * 100.0 / SUM(S25 - S24) OVER(), 2) AS Share_Of_Total_Change_Pct
FROM t ORDER BY Change_M ASC;

-- -------x--------x---------x----------

-- Sales Change by Customer Segment Observation

-- 1. Corporate customers lost 100.77M (-32.00%) = 99.37% of the total loss.
-- 2. Consumer (-0.67%) and Home Office (+0.29%) are flat. So the revenue problem is a Corporate (B2B) problem.

WITH t AS (SELECT Customer_Segment,
SUM(CASE WHEN Order_Year = 2024 THEN Net_Sales ELSE 0 END) AS S24,
SUM(CASE WHEN Order_Year = 2025 THEN Net_Sales ELSE 0 END) AS S25
FROM vw_sales 
GROUP BY Customer_Segment)
SELECT Customer_Segment,
ROUND(S24 / 1000000.0, 2) AS Sales_2024_M,
ROUND(S25 / 1000000.0, 2) AS Sales_2025_M,
ROUND((S25 - S24) / 1000000.0, 2) AS Change_M,
ROUND((S25 - S24) * 100.0 / S24, 2) AS YoY_Pct,
ROUND((S25 - S24) * 100.0 / SUM(S25 - S24) OVER(), 2) AS Share_Of_Total_Change_Pct
FROM t ORDER BY Change_M ASC;

-- -------x--------x---------x----------

-- Sales Change by Region Observation

-- 1. Every region declined: North -22.67%, East -21.53%, West -15.53%, South -11.92%. The sales loss is broad-based, so it is not a regional demand problem.

WITH t AS (SELECT Region,
SUM(CASE WHEN Order_Year = 2024 THEN Net_Sales ELSE 0 END) AS S24,
SUM(CASE WHEN Order_Year = 2025 THEN Net_Sales ELSE 0 END) AS S25
FROM vw_sales 
GROUP BY Region)
SELECT Region,
ROUND(S24 / 1000000.0, 2) AS Sales_2024_M,
ROUND(S25 / 1000000.0, 2) AS Sales_2025_M,
ROUND((S25 - S24) / 1000000.0, 2) AS Change_M,
ROUND((S25 - S24) * 100.0 / S24, 2) AS YoY_Pct,
ROUND((S25 - S24) * 100.0 / SUM(S25 - S24) OVER(), 2) AS Share_Of_Total_Change_Pct
FROM t ORDER BY Change_M ASC;

-- -------x--------x---------x----------

-- Segment x Category Matrix Observation

-- 1. The single biggest hole: Corporate x Electronics lost 89.07M (-40.08%) = 87.84% of the total loss.
-- 2. Next: Corporate Office Supplies -7.66M, Consumer Electronics -6.58M, Home Office Electronics -5.60M.
-- 3. Offsets: Home Office Furniture +6.35M and Consumer Furniture +5.05M (but these were bought with heavy discounts, see Part B).

WITH t AS (SELECT Customer_Segment, Product_Category,
SUM(CASE WHEN Order_Year = 2024 THEN Net_Sales ELSE 0 END) AS S24,
SUM(CASE WHEN Order_Year = 2025 THEN Net_Sales ELSE 0 END) AS S25
FROM vw_sales 
GROUP BY Customer_Segment, Product_Category)
SELECT Customer_Segment, Product_Category,
ROUND(S24 / 1000000.0, 2) AS Sales_2024_M,
ROUND(S25 / 1000000.0, 2) AS Sales_2025_M,
ROUND((S25 - S24) / 1000000.0, 2) AS Change_M,
ROUND((S25 - S24) * 100.0 / S24, 2) AS YoY_Pct,
ROUND((S25 - S24) * 100.0 / SUM(S25 - S24) OVER(), 2) AS Share_Of_Total_Change_Pct
FROM t ORDER BY Change_M ASC;

-- -------x--------x---------x----------

-- Top 10 Products by Sales Loss Observation

-- 1. The top 6 losers are ALL laptops: Zenith Gaming G15 (-38.17M, -54.55%), AeroBook Pro 16 (-16.09M), OfficeMate 15 (-14.97M), WorkStation Z17 (-9.42M), AeroBook 14 (-5.31M), Zenith Slim 13 (-3.97M).
-- 2. Zenith Gaming G15 alone explains 37.6% of the whole company loss. Every laptop SKU fell 30-55%, so the cause is category-wide (not one bad product).

WITH t AS (SELECT Product_Name,
SUM(CASE WHEN Order_Year = 2024 THEN Net_Sales ELSE 0 END) AS S24,
SUM(CASE WHEN Order_Year = 2025 THEN Net_Sales ELSE 0 END) AS S25
FROM vw_sales 
GROUP BY Product_Name)
SELECT Product_Name,
ROUND(S24 / 1000000.0, 2) AS Sales_2024_M,
ROUND(S25 / 1000000.0, 2) AS Sales_2025_M,
ROUND((S25 - S24) / 1000000.0, 2) AS Change_M,
ROUND((S25 - S24) * 100.0 / S24, 2) AS YoY_Pct,
ROUND((S25 - S24) * 100.0 / SUM(S25 - S24) OVER(), 2) AS Share_Of_Total_Change_Pct
FROM t ORDER BY Change_M ASC LIMIT 10;

-- -------x--------x---------x----------


-- ======================================================================
-- PART B - WHY HAPPENED (Root Cause Analysis)
-- ======================================================================


-- Root Cause 1: Laptop Price Hike. Did any product price change? Observation

-- 1. Only 6 of 69 products changed price between 2024 and 2025, and all 6 are laptops.
-- 2. Every laptop SKU was increased by about +9% (8.95% to 9.06%), effective between 1 and 6 March 2025.
-- 3. This is exactly when the sales break starts in the monthly trend (Part A).

SELECT p.Product_Name, p.Old_Price, p.New_Price,
ROUND((p.New_Price - p.Old_Price) * 100.0 / p.Old_Price, 2) AS Price_Hike_Pct,
(SELECT MIN(v.Order_Date) FROM vw_sales v WHERE v.Product_Name = p.Product_Name AND v.Unit_Price = p.New_Price) AS New_Price_Effective_From
FROM (SELECT Product_Name, MIN(Unit_Price) AS Old_Price, MAX(Unit_Price) AS New_Price
FROM vw_sales GROUP BY Product_Name
HAVING MIN(Unit_Price) <> MAX(Unit_Price)) p
ORDER BY p.Product_Name;

-- -------x--------x---------x----------

-- Laptop Monthly Trend Observation

-- 1. Jan 2025 +21.55% and Feb -3.01%: laptops were healthy BEFORE the price increase.
-- 2. After March the decline is immediate and deep: Mar -20.21%, Apr -43.39%, May -60.76%, Jun -61.48%, Jul -60.12%, Sep -57.13%, Dec -57.44%.
-- 3. Even the seasonal peak month (Oct) stays -35.5%. There is no recovery in 10 months.

SELECT Order_Month,
ROUND(SUM(CASE WHEN Order_Year = 2024 THEN Net_Sales ELSE 0 END) / 1000000.0, 2) AS Sales_2024_M,
ROUND(SUM(CASE WHEN Order_Year = 2025 THEN Net_Sales ELSE 0 END) / 1000000.0, 2) AS Sales_2025_M,
ROUND((SUM(CASE WHEN Order_Year = 2025 THEN Net_Sales ELSE 0 END) - SUM(CASE WHEN Order_Year = 2024 THEN Net_Sales ELSE 0 END)) * 100.0 / SUM(CASE WHEN Order_Year = 2024 THEN Net_Sales ELSE 0 END), 2) AS YoY_Pct
FROM vw_sales
WHERE Sub_Category = 'Laptops'
GROUP BY Order_Month
ORDER BY Order_Month;

-- -------x--------x---------x----------

-- Laptop Price vs Demand (Elasticity) Observation

-- 1. Before the hike (Jan-Feb) laptop units grew +2.95%, so demand was healthy.
-- 2. After the hike (Mar-Dec) units fell -54.22% against a ~9% list price increase. That is roughly 6% fewer units for every 1% increase in price: demand is extremely price-sensitive.
-- 3. The average realised price in this table moves by less than the 9% list increase because it is also affected by product mix; the 9% list change is the cleaner price signal.
-- 4. Revenue = price x units. A +9% price with -54% units means about -50% laptop revenue. The price increase was clearly revenue-destructive.


WITH t AS (SELECT CASE WHEN Order_Month <= 2 THEN '1. Jan-Feb (before hike)' ELSE '2. Mar-Dec (after hike)' END AS Period,
SUM(CASE WHEN Order_Year = 2024 THEN Quantity ELSE 0 END) AS Units_2024,
SUM(CASE WHEN Order_Year = 2025 THEN Quantity ELSE 0 END) AS Units_2025,
SUM(CASE WHEN Order_Year = 2024 THEN Gross_Sales ELSE 0 END) * 1.0 / SUM(CASE WHEN Order_Year = 2024 THEN Quantity ELSE 0 END) AS Avg_Price_2024,
SUM(CASE WHEN Order_Year = 2025 THEN Gross_Sales ELSE 0 END) * 1.0 / SUM(CASE WHEN Order_Year = 2025 THEN Quantity ELSE 0 END) AS Avg_Price_2025
FROM vw_sales
WHERE Sub_Category = 'Laptops'
GROUP BY Period)
SELECT Period, Units_2024, Units_2025,
ROUND((Units_2025 - Units_2024) * 100.0 / Units_2024, 2) AS Units_YoY_Pct,
ROUND(Avg_Price_2024, 0) AS Avg_Price_2024,
ROUND(Avg_Price_2025, 0) AS Avg_Price_2025,
ROUND((Avg_Price_2025 - Avg_Price_2024) * 100.0 / Avg_Price_2024, 2) AS Price_YoY_Pct
FROM t ORDER BY Period;

-- -------x--------x---------x----------

-- Laptop Loss by Customer Segment Observation

-- 1. Corporate laptop sales fell 66.27M (-49.19%) = 75.4% of the laptop loss. Consumer fell 13.64M (-38.64%) and Home Office 8.02M (-23.83%).
-- 2. Bulk-buying Corporate customers reacted the strongest to the price rise, because a 9% hike on large multi-unit orders is a big absolute cost.

WITH t AS (SELECT Customer_Segment,
SUM(CASE WHEN Order_Year = 2024 THEN Net_Sales ELSE 0 END) AS S24,
SUM(CASE WHEN Order_Year = 2025 THEN Net_Sales ELSE 0 END) AS S25
FROM vw_sales WHERE Sub_Category = 'Laptops'
GROUP BY Customer_Segment)
SELECT Customer_Segment,
ROUND(S24 / 1000000.0, 2) AS Sales_2024_M,
ROUND(S25 / 1000000.0, 2) AS Sales_2025_M,
ROUND((S25 - S24) / 1000000.0, 2) AS Change_M,
ROUND((S25 - S24) * 100.0 / S24, 2) AS YoY_Pct,
ROUND((S25 - S24) * 100.0 / SUM(S25 - S24) OVER(), 2) AS Share_Of_Total_Change_Pct
FROM t ORDER BY Change_M ASC;

-- -------x--------x---------x----------

-- Corporate Laptop Monthly Trend Observation

-- 1. Corporate laptop orders were 50-84 per month in 2024. In 2025 they fell from 59 (Jan) to 32 (Feb) to 13 (May) and never recovered (12 in Sep, 24 in Dec).
-- 2. Jan 2025 sales were actually +64% above Jan 2024 (7.19M -> 11.83M), then fell off a cliff from February.

SELECT Order_Month,
SUM(CASE WHEN Order_Year = 2024 THEN 1 ELSE 0 END) AS Orders_2024,
SUM(CASE WHEN Order_Year = 2025 THEN 1 ELSE 0 END) AS Orders_2025,
ROUND(SUM(CASE WHEN Order_Year = 2024 THEN Net_Sales ELSE 0 END) / 1000000.0, 2) AS Sales_2024_M,
ROUND(SUM(CASE WHEN Order_Year = 2025 THEN Net_Sales ELSE 0 END) / 1000000.0, 2) AS Sales_2025_M
FROM vw_sales
WHERE Customer_Segment = 'Corporate' AND Sub_Category = 'Laptops'
GROUP BY Order_Month
ORDER BY Order_Month;

-- -------x--------x---------x----------

-- Corporate Laptop Customer Behaviour Observation

-- 1. Orders fell 55.7% (738 -> 327) and unique buyers fell from 416 to 227.
-- 2. Units per order are stable (2.86 vs 3.09), discount level is stable (9.8% -> 9.0%), and rating is unchanged (3.93 vs 3.93).
-- 3. So customers did not get worse service or lower discounts; they simply stopped buying. The analysis suggests price increase was the primary driver.

SELECT Order_Year, COUNT(*) AS Orders,
COUNT(DISTINCT Customer_ID) AS Unique_Buyers,
ROUND(AVG(Quantity), 2) AS Avg_Units_Per_Order,
ROUND(AVG(Unit_Price), 0) AS Avg_Unit_Price,
ROUND(AVG(Discount_Applied) * 100, 2) AS Avg_Discount_Pct,
ROUND(AVG(Shipping_Delay_Days), 2) AS Avg_Delay_Days,
ROUND(AVG(Customer_Rating), 2) AS Avg_Rating,
ROUND(SUM(Net_Sales) / 1000000.0, 2) AS Net_Sales_M
FROM vw_sales
WHERE Customer_Segment = 'Corporate' AND Sub_Category = 'Laptops'
GROUP BY Order_Year;

-- -------x--------x---------x----------

-- Corporate Laptop Buyer Retention Observation

-- 1. Of 416 Corporate laptop buyers in 2024, only 151 bought again in 2025 (36.3% retention). 265 buyers were lost.
-- 2. Only 76 new buyers joined, which is far too few to replace the lost accounts.

WITH b AS (SELECT Customer_ID,
SUM(CASE WHEN Order_Year = 2024 THEN 1 ELSE 0 END) AS O24,
SUM(CASE WHEN Order_Year = 2025 THEN 1 ELSE 0 END) AS O25
FROM vw_sales
WHERE Customer_Segment = 'Corporate' AND Sub_Category = 'Laptops'
GROUP BY Customer_ID)
SELECT SUM(CASE WHEN O24 > 0 THEN 1 ELSE 0 END) AS Laptop_Buyers_2024,
SUM(CASE WHEN O24 > 0 AND O25 > 0 THEN 1 ELSE 0 END) AS Repeat_Buyers_In_2025,
SUM(CASE WHEN O24 > 0 AND O25 = 0 THEN 1 ELSE 0 END) AS Lost_Buyers,
ROUND(SUM(CASE WHEN O24 > 0 AND O25 > 0 THEN 1 ELSE 0 END) * 100.0 / SUM(CASE WHEN O24 > 0 THEN 1 ELSE 0 END), 2) AS Buyer_Retention_Pct,
SUM(CASE WHEN O24 = 0 AND O25 > 0 THEN 1 ELSE 0 END) AS New_Buyers_2025
FROM b;

-- -------x--------x---------x----------

-- Corporate Loss Beyond Laptops Observation

-- 1. Laptops are 65.8% of the Corporate loss. Besides laptops, Corporate also cut Phones -14.00M (-30.19%), Monitors -5.47M, Accessories -3.33M.
-- 2. Phone prices did not change, so Corporate customers are also reducing spend generally (probably a broader vendor-consolidation or budget effect).

WITH t AS (SELECT Sub_Category,
SUM(CASE WHEN Order_Year = 2024 THEN Net_Sales ELSE 0 END) AS S24,
SUM(CASE WHEN Order_Year = 2025 THEN Net_Sales ELSE 0 END) AS S25
FROM vw_sales WHERE Customer_Segment = 'Corporate'
GROUP BY Sub_Category)
SELECT Sub_Category,
ROUND(S24 / 1000000.0, 2) AS Sales_2024_M,
ROUND(S25 / 1000000.0, 2) AS Sales_2025_M,
ROUND((S25 - S24) / 1000000.0, 2) AS Change_M,
ROUND((S25 - S24) * 100.0 / S24, 2) AS YoY_Pct,
ROUND((S25 - S24) * 100.0 / SUM(S25 - S24) OVER(), 2) AS Share_Of_Total_Change_Pct
FROM t ORDER BY Change_M ASC;

-- -------x--------x---------x----------

-- Root Cause 2: Discount Strategy Change Observation

-- 1. In 2024 the maximum discount was 25%. In 2025, brand-new 30%, 35% and 40% discount tiers appear, used on 3,477 orders (15.97% of all 2025 orders).
-- 2. The share of orders in the lower discount bands fell, so the extra discount depth is concentrated in one place (next query).

SELECT Order_Year, Discount_Band,
COUNT(*) AS Orders,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY Order_Year), 2) AS Order_Share_Pct
FROM vw_sales
GROUP BY Order_Year, Discount_Band
ORDER BY Order_Year, Discount_Band;

-- -------x--------x---------x----------

-- Average Discount by Category Observation

-- 1. Furniture is the only category affected: average discount jumped from 8.54% to 21.32% and the maximum from 25% to 40%.
-- 2. Electronics (8.57% -> 8.40%) and Office Supplies (8.59% -> 8.31%) are unchanged. All 3,477 deep-discount orders are Furniture orders.

SELECT Product_Category, Order_Year,
ROUND(AVG(Discount_Applied) * 100, 2) AS Avg_Discount_Pct,
MAX(Discount_Applied) * 100 AS Max_Discount_Pct
FROM vw_sales
GROUP BY Product_Category, Order_Year
ORDER BY Product_Category, Order_Year;

-- -------x--------x---------x----------

-- Furniture Monthly Discount Trend Observation

-- 1. Furniture discount was 7.6-8.4% in Jan-Feb 2025, then jumped to 23.2% in March 2025 and stayed at 22-24% every month after.
-- 2. Price realization (Net/Gross) fell from ~91% to ~77%. The company started giving away ~14% of furniture list value from March onward, the same month as the laptop price hike.

SELECT Order_Month,
SUM(CASE WHEN Order_Year = 2024 THEN 1 ELSE 0 END) AS Orders_2024,
SUM(CASE WHEN Order_Year = 2025 THEN 1 ELSE 0 END) AS Orders_2025,
ROUND(AVG(CASE WHEN Order_Year = 2024 THEN Discount_Applied END) * 100, 2) AS Avg_Disc_2024_Pct,
ROUND(AVG(CASE WHEN Order_Year = 2025 THEN Discount_Applied END) * 100, 2) AS Avg_Disc_2025_Pct,
ROUND(SUM(CASE WHEN Order_Year = 2025 THEN Net_Sales ELSE 0 END) * 100.0 / SUM(CASE WHEN Order_Year = 2025 THEN Gross_Sales ELSE 0 END), 2) AS Realization_2025_Pct
FROM vw_sales
WHERE Product_Category = 'Furniture'
GROUP BY Order_Month
ORDER BY Order_Month;

-- -------x--------x---------x----------

-- Did the Furniture Discounts Pay Off? Observation

-- 1. Furniture orders grew +32.1% (5,229 -> 6,908) and Gross Sales grew +24.3%, but Net Sales grew only +7.7% (95.53M -> 102.90M).
-- 2. Price realization fell from 91.09% to 78.96%.

SELECT Order_Year,
COUNT(*) AS Orders,
ROUND(SUM(Gross_Sales) / 1000000.0, 2) AS Gross_Sales_M,
ROUND(SUM(Net_Sales) / 1000000.0, 2) AS Net_Sales_M,
ROUND(SUM(Net_Sales) * 100.0 / SUM(Gross_Sales), 2) AS Realization_Pct
FROM vw_sales
WHERE Product_Category = 'Furniture'
GROUP BY Order_Year;

-- -------x--------x---------x----------

-- Furniture Deep-Discount Quality Observation

-- 1. Deep-discount (30-40%) furniture orders have a 20.36% return rate vs 4.5-5.6% for lower discount bands in the same year (about 4x).
-- 2. Their cancellation rate is 10.01% (vs 4.3-6.1%) and their rating is 3.55 (vs 3.85-3.91). Deep discounts attract low-quality demand that returns, cancels and rates badly.
-- 3. Of 41.62M net sales in this band, a large part comes back as returns, so the real benefit of the discount is even smaller.

SELECT Order_Year, Discount_Band,
COUNT(*) AS Orders,
ROUND(SUM(Gross_Sales) / 1000000.0, 2) AS Gross_Sales_M,
ROUND(SUM(Net_Sales) / 1000000.0, 2) AS Net_Sales_M,
ROUND(SUM(CASE WHEN Order_Status = 'Returned' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Return_Rate_Pct,
ROUND(SUM(CASE WHEN Order_Status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Cancel_Rate_Pct,
ROUND(AVG(Customer_Rating), 2) AS Avg_Rating
FROM vw_sales
WHERE Product_Category = 'Furniture'
GROUP BY Order_Year, Discount_Band
ORDER BY Order_Year, Discount_Band;

-- -------x--------x---------x----------

-- Root Cause 3: West Region Logistics Failure. Shipping Delay by Region Observation

-- 1. Until June 2025 average shipping delay is ~2 days in all four regions (also all of 2024).
-- 2. From July 2025 West jumps to 7.82 days, then 9.47 (Aug), 10.93 (Sep), 11.00 (Oct), 10.84 (Nov), 10.75 (Dec). North, South and East remain at ~2 days.
-- 3. This is a region-specific operational failure (warehouse, carrier or fulfilment partner) starting July 2025.

SELECT Order_Year, Order_Month,
ROUND(AVG(CASE WHEN Region = 'West' THEN Shipping_Delay_Days END), 2) AS West_Delay,
ROUND(AVG(CASE WHEN Region = 'North' THEN Shipping_Delay_Days END), 2) AS North_Delay,
ROUND(AVG(CASE WHEN Region = 'South' THEN Shipping_Delay_Days END), 2) AS South_Delay,
ROUND(AVG(CASE WHEN Region = 'East' THEN Shipping_Delay_Days END), 2) AS East_Delay
FROM vw_sales
WHERE Order_Status <> 'Cancelled'
GROUP BY Order_Year, Order_Month
ORDER BY Order_Year, Order_Month;

-- -------x--------x---------x----------

-- West Region Before vs After Observation

-- 1. West H1 2025 -> H2 2025: average delay 2.01 -> 10.19 days, cancellation rate 4.35% -> 20.79%, average rating 3.95 -> 2.64.
-- 2. West H2 Net Sales are still 55.53M because customers kept placing orders. The damage is in cancelled / unfulfilled orders and brand rating, which do not show in booked sales.

SELECT CONCAT(Order_Year, ' ', Order_Half) AS Period,
COUNT(*) AS Orders,
ROUND(SUM(Net_Sales) / 1000000.0, 2) AS Net_Sales_M,
ROUND(AVG(Shipping_Delay_Days), 2) AS Avg_Delay_Days,
ROUND(SUM(CASE WHEN Order_Status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Cancel_Rate_Pct,
ROUND(SUM(CASE WHEN Order_Status = 'Returned' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Return_Rate_Pct,
ROUND(AVG(Customer_Rating), 2) AS Avg_Rating
FROM vw_sales
WHERE Region = 'West'
GROUP BY Order_Year, Order_Half
ORDER BY Order_Year, Order_Half;

-- -------x--------x---------x----------

-- Cancellation & Return Rates by Region Observation

-- 1. West FY2025 cancellation rate is 12.70% vs 3.20%-4.35% for the other regions (and ~3.95% for West in 2024).
-- 2. Return rate rose in every region (about 4.7-5.0% -> 7.0-7.5%), which is explained by the furniture discount issue below.

SELECT Region, Order_Year,
COUNT(*) AS Orders,
ROUND(SUM(CASE WHEN Order_Status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Cancel_Rate_Pct,
ROUND(SUM(CASE WHEN Order_Status = 'Returned' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Return_Rate_Pct
FROM vw_sales
GROUP BY Region, Order_Year
ORDER BY Region, Order_Year;

-- -------x--------x---------x----------

-- Shipping Delay vs Customer Experience Observation

-- 1. Rating is flat at ~4.02 up to 3 days of delay, then drops to 3.87 (4-5 days), 3.38 (6-8 days) and 2.43 (9+ days).
-- 2. Share of low ratings (<=2) jumps from ~11.5% to 56.7% for 9+ day delays; return rate also rises to 9.92%.
-- 3. Delay beyond 5 days clearly damages customer satisfaction.

SELECT CASE WHEN Shipping_Delay_Days <= 1 THEN '0-1 days'
WHEN Shipping_Delay_Days <= 3 THEN '2-3 days'
WHEN Shipping_Delay_Days <= 5 THEN '4-5 days'
WHEN Shipping_Delay_Days <= 8 THEN '6-8 days'
ELSE '9+ days' END AS Delay_Bucket,
COUNT(*) AS Orders,
ROUND(AVG(Customer_Rating), 2) AS Avg_Rating,
ROUND(SUM(CASE WHEN Customer_Rating <= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(Customer_Rating), 2) AS Low_Rating_Pct,
ROUND(SUM(CASE WHEN Order_Status = 'Returned' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Return_Rate_Pct
FROM vw_sales
WHERE Shipping_Delay_Days IS NOT NULL
GROUP BY Delay_Bucket
ORDER BY MIN(Shipping_Delay_Days);

-- -------x--------x---------x----------

-- Is the Cancellation Increase Only a West Problem? Observation

-- 1. Rest of the business: cancellation rate is 3.68% (2024) vs 4.02% (2025), almost stable.
-- 2. West (Jul-Dec 2025): 20.79%. So most of the rise in company-wide cancellations (3.68% -> 6.03%) comes from the West failure.

SELECT Order_Year,
CASE WHEN Region = 'West' AND Order_Year = 2025 AND Order_Month >= 7 THEN 'West (Jul-Dec 2025)' ELSE 'Rest of Business' END AS Order_Group,
COUNT(*) AS Orders,
ROUND(SUM(CASE WHEN Order_Status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Cancel_Rate_Pct
FROM vw_sales
GROUP BY Order_Year, Order_Group
ORDER BY Order_Year, Order_Group;

-- -------x--------x---------x----------

-- Revenue Leakage: Cancelled & Returned Orders Observation

-- 1. Cancelled value rose from 20.49M to 26.17M (3.65% -> 5.69% of sales). Returned orders were 37.99M (6.76%) vs 34.71M (7.54%).
-- 2. Delivered (realized) revenue fell from 503.18M to 399.36M = -20.63%, worse than the -18.06% booked drop.

SELECT Order_Year, Order_Status,
COUNT(*) AS Orders,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY Order_Year), 2) AS Order_Share_Pct,
ROUND(SUM(Net_Sales) / 1000000.0, 2) AS Net_Sales_M,
ROUND(SUM(Net_Sales) * 100.0 / SUM(SUM(Net_Sales)) OVER(PARTITION BY Order_Year), 2) AS Value_Share_Pct
FROM vw_sales
GROUP BY Order_Year, Order_Status
ORDER BY Order_Year, Order_Status;

-- -------x--------x---------x----------

-- Proof: Return Rate Increase Is Fully Explained by Deep-Discount Furniture Observation

-- 1. All other orders have exactly the same return rate in both years: 4.87% (2024) and 4.87% (2025).
-- 2. Furniture with 30%+ discount returns at 20.36%. So the entire rise in company return rate (4.87% -> 7.34%) comes from deep-discount furniture orders.

SELECT Order_Year,
CASE WHEN Product_Category = 'Furniture' AND Discount_Applied >= 0.30 THEN 'Furniture - Deep Discount (30%+)'
ELSE 'All Other Orders' END AS Order_Group,
COUNT(*) AS Orders,
ROUND(SUM(CASE WHEN Order_Status = 'Returned' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Return_Rate_Pct,
ROUND(SUM(CASE WHEN Order_Status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Cancel_Rate_Pct
FROM vw_sales
GROUP BY Order_Year, Order_Group
ORDER BY Order_Year, Order_Group;

-- -------x--------x---------x----------

-- Customer Rating by Category Observation

-- 1. Furniture rating fell 3.97 -> 3.72 (low ratings 12.4% -> 20.1%), caused by the deep-discount returns issue. Electronics rating fell 3.96 -> 3.84 and low ratings 12.7% -> 16.1%, partly from West delays.
-- 2. Falling ratings are an early warning of lower repeat purchases in 2026.

SELECT Product_Category, Order_Year,
ROUND(AVG(Customer_Rating), 2) AS Avg_Rating,
ROUND(SUM(CASE WHEN Customer_Rating <= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(Customer_Rating), 2) AS Low_Rating_Pct
FROM vw_sales
GROUP BY Product_Category, Order_Year
ORDER BY Product_Category, Order_Year;

-- -------x--------x---------x----------

-- ======================================================================
-- PART C - RISK OBSERVATION
-- ======================================================================

-- Reusable Risk View: Customer Risk Scoring Logic
-- Segments every customer who bought in 2024 into 4 tiers (thresholds: 50% spend drop, 90 days inactivity):
-- Lost - Win-back: no order at all in 2025.
-- High Risk: 2025 spend is less than 50% of 2024 AND no order in the last 90 days.
-- Medium Risk: 2025 spend is less than 50% of 2024 OR no order in the last 90 days.
-- Healthy: spend is stable or growing.
-- "Days since last order" is measured from the last date in the data (31-Dec-2025), not from today's date.

DROP VIEW IF EXISTS vw_customer_risk;
CREATE VIEW vw_customer_risk AS
WITH c AS (SELECT Customer_ID,
MAX(Customer_Segment) AS Customer_Segment,
SUM(CASE WHEN Order_Year = 2024 THEN 1 ELSE 0 END) AS O24,
SUM(CASE WHEN Order_Year = 2025 THEN 1 ELSE 0 END) AS O25,
SUM(CASE WHEN Order_Year = 2024 THEN Net_Sales ELSE 0 END) AS S24,
SUM(CASE WHEN Order_Year = 2025 THEN Net_Sales ELSE 0 END) AS S25,
MAX(Order_Date) AS Last_Order_Date
FROM vw_sales
GROUP BY Customer_ID), d AS (SELECT c.*,
DATEDIFF((SELECT MAX(Order_Date) FROM vw_sales), Last_Order_Date) AS Days_Since_Last_Order
FROM c WHERE O24 > 0)
SELECT d.*,
CASE WHEN O25 = 0 THEN 'Lost - Win-back'
WHEN S25 < 0.5 * S24 AND Days_Since_Last_Order > 90 THEN 'High Risk'
WHEN S25 < 0.5 * S24 OR Days_Since_Last_Order > 90 THEN 'Medium Risk'
ELSE 'Healthy' END AS Risk_Level
FROM d;

-- -------x--------x---------x----------

-- Early Warning: Customer Risk Scoring Observation

-- 1. Of 4,387 customers from 2024, only 1,325 (33.7%) are healthy. 1,470 are already lost (97.38M of 2024 sales), 559 are High Risk (111.31M in 2024, down to only 14.44M in 2025) and 1,033 are Medium Risk (163.82M -> 85.14M).
-- 2. About 49% of the 2024 revenue base sits in High and Medium risk accounts, so there is a large pool where a retention campaign can protect revenue.
-- 3. Another 17.3% of the 2024 base is already lost (win-back needed), so only about one-third of the 2024 revenue base is truly safe.

SELECT Risk_Level,
COUNT(*) AS Customers,
ROUND(SUM(S24) / 1000000.0, 2) AS Sales_2024_M,
ROUND(SUM(S25) / 1000000.0, 2) AS Sales_2025_M,
ROUND(SUM(S24) * 100.0 / SUM(SUM(S24)) OVER(), 2) AS Share_Of_2024_Base_Pct
FROM vw_customer_risk
GROUP BY Risk_Level
ORDER BY Sales_2024_M DESC;

-- -------x--------x---------x----------

-- High-Value At-Risk Accounts (Priority Call List) Observation

-- 1. The top at-risk accounts are all Corporate, each worth 2.0-2.7M in 2024. Examples: CUST-14849 (2.42M in 2024 -> 0.002M in 2025, silent for 360 days) and CUST-14435 (2.02M -> 0.06M, 325 days).
-- 2. Some big accounts are still active but shrinking (e.g. CUST-14916: 2.73M -> 1.09M, ordered 6 days before data end), so they are Medium Risk. They need an early conversation before they go silent like the High Risk accounts.
-- 3. Ordering by 2024 revenue gives the Customer Success / Key Account team the biggest dollars first.

SELECT Customer_ID, Customer_Segment, ROUND(S24, 0) AS Sales_2024, ROUND(S25, 0) AS Sales_2025,
Days_Since_Last_Order, Risk_Level
FROM vw_customer_risk
WHERE Risk_Level IN ('High Risk', 'Medium Risk')
ORDER BY S24 DESC
LIMIT 15;

-- -------x--------x---------x----------

-- Win-back List (Already Lost Customers) Observation

-- 1. The top lost accounts are all Corporate with 1.0-1.6M each in 2024 (e.g. CUST-14812 1.63M, CUST-15075 1.41M, CUST-14592 1.35M).
-- 2. Their last orders were placed in Nov-Dec 2024 and they never returned in 2025, right before the March 2025 price hike.

SELECT Customer_ID, Customer_Segment, ROUND(S24, 0) AS Sales_2024, Last_Order_Date
FROM vw_customer_risk
WHERE Risk_Level = 'Lost - Win-back'
ORDER BY S24 DESC
LIMIT 15;

-- -------x--------x---------x----------

-- END --