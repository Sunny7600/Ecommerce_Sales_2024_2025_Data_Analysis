Create Database SDB;
Use SDB;
DROP TABLE IF EXISTS SDB;

CREATE TABLE SDB (
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

SELECT * FROM SDB;

SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'C:/Users/ysunn/OneDrive/Desktop/Revenue Loss Sales Data/Ecommerce_Sales_2024_2025_Cleaned_Data.csv'
INTO TABLE SDB
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- ----------------------------------------------------------------------------------------------------------------

-- Problem Statement: Company sales dropped by 18% YoY in 2025 compared to 2024. Management wants to identify the root cause, quantify the losses, and simulate an action plan to recover lost revenue.

-- Start Analysing Data

SELECT * FROM SDB;

-- Comparing 2024 vs 2025 Gross Sales, Net Sales, and Total Orders.

WITH Yearly_Gross_Sales AS (
SELECT 
SUM(CASE WHEN YEAR(Order_Date) = 2024 THEN Unit_Price * Quantity ELSE 0 END) AS Gross_Sales_2024,
SUM(CASE WHEN YEAR(Order_Date) = 2025 THEN Unit_Price * Quantity ELSE 0 END) AS Gross_Sales_2025
FROM SDB)
SELECT Gross_Sales_2024, Gross_Sales_2025,
ROUND(((Gross_Sales_2025 - Gross_Sales_2024) / NULLIF(Gross_Sales_2024, 0)) * 100, 2) AS Growth_Percentage
FROM Yearly_Gross_Sales;

-- --------

WITH Yearly_Net_Sales AS 
(SELECT SUM(CASE WHEN YEAR(Order_Date) = 2024 THEN Unit_Price * Quantity * (1 - Discount_Applied) ELSE 0 END) AS Net_Sales_2024,
SUM(CASE WHEN YEAR(Order_Date) = 2025 THEN Unit_Price * Quantity * (1 - Discount_Applied) ELSE 0 END) AS Net_Sales_2025
FROM SDB WHERE Order_Status = 'Delivered')
SELECT 
ROUND(Net_Sales_2024, 2) AS Net_Sales_2024,
ROUND(Net_Sales_2025, 2) AS Net_Sales_2025,
ROUND(((Net_Sales_2025 - Net_Sales_2024) / NULLIF(Net_Sales_2024, 0)) * 100, 2) AS Net_Growth_Percentage
FROM Yearly_Net_Sales;

-- ---------

WITH Yearly_Orders AS 
(SELECT 
SUM(CASE WHEN YEAR(Order_Date) = 2024 THEN 1 ELSE 0 END) AS Orders_2024,
SUM(CASE WHEN YEAR(Order_Date) = 2025 THEN 1 ELSE 0 END) AS Orders_2025
FROM SDB)
SELECT Orders_2024, Orders_2025,
ROUND(((Orders_2025 - Orders_2024) / NULLIF(Orders_2024, 0)) * 100, 2) AS Order_Growth_Percentage
FROM Yearly_Orders;

-- OBERSERVATION: After looking at the gross sales, net sales, and total orders in this dataset, I noticed that total orders grew by 2.22% in 2025, but net sales still dropped by 21.03% not 18% mentioned in business problem.



-- Comparing the total lost revenue attributed to Cancelled and Returned orders in 2025 vs 2024.

SELECT YEAR(Order_Date) AS Order_Year,
ROUND(SUM(CASE WHEN Order_Status = 'Cancelled' THEN (Unit_Price * Quantity) * (1 - Discount_Applied) ELSE 0 END),2) AS Cancelled_Revenue_Loss,
ROUND(SUM(CASE WHEN Order_Status = 'Returned' THEN (Unit_Price * Quantity) * (1 - Discount_Applied) ELSE 0 END),2) AS Returned_Revenue_Loss,
ROUND(SUM((Unit_Price * Quantity) * (1 - Discount_Applied)),2) AS Total_Lost_Revenue
FROM SDB
WHERE Order_Status IN ('Cancelled', 'Returned')
GROUP BY YEAR(Order_Date)
ORDER BY Order_Year;

-- OBERSERVATION: Looking at the data, the total lost revenue increased from 5.53 crore in 2024 to 5.68 crore in 2025. While the revenue lost due to returned orders went down but loss from cancelled orders saw a significant jump in 2025.


-- Why the Cancellation rate saw a significant jump in 2025?


SELECT Region,
    SUM(CASE WHEN YEAR(Order_Date) = 2024 THEN 1 ELSE 0 END) AS Cancelled_Orders_2024,
    SUM(CASE WHEN YEAR(Order_Date) = 2025 THEN 1 ELSE 0 END) AS Cancelled_Orders_2025
FROM SDB WHERE Order_Status = 'Cancelled'
GROUP BY Region;

SELECT YEAR(Order_Date) AS Order_Year,
ROUND(AVG(Shipping_Delay_Days), 2) AS Avg_Shipping_Delay_Days
FROM SDB
WHERE Region = 'West'
GROUP BY YEAR(Order_Date)
ORDER BY Order_Year;

-- OBSERVATION: While order cancellations in other regions showed minor changes year-over-year but the West region saw a massive jump from 182 in 2024 to 616 in 2025. The main reason behind this spike was the average shipping delay in the West region, which increased significantly from 2.01 days in 2024 to 6.23 days in 2025.


-- Comparing Total Orders On Each Customer Segment 2024 vs 2025

SELECT Customer_Segment,
    SUM(CASE WHEN YEAR(Order_Date) = 2024 THEN 1 ELSE 0 END) AS Total_Orders_2024,
    SUM(CASE WHEN YEAR(Order_Date) = 2025 THEN 1 ELSE 0 END) AS Total_Orders_2025
FROM SDB
WHERE YEAR(Order_Date) IN (2024, 2025)
GROUP BY Customer_Segment
ORDER BY Customer_Segment;

-- OBSERVATION: In 2025, total orders grew for Consumer and Home Office segments, but Corporate orders dropped significantly compared to 2024. Consumer grew from 8,562 to 9,536 and Home Office from 4,640 to 5,393, while Corporate orders fell from 6,811 to 5,529.



-- Comparing Total Orders On Each Sub_Category From Corporate Segment 2024 vs 2025

SELECT Sub_Category,
SUM(CASE WHEN YEAR(Order_Date) = 2024 THEN 1 ELSE 0 END) AS Total_Orders_2024,
SUM(CASE WHEN YEAR(Order_Date) = 2025 THEN 1 ELSE 0 END) AS Total_Orders_2025
FROM SDB WHERE Customer_Segment = 'Corporate'
GROUP BY Sub_Category;

-- OBSERVATION: While most sub-categories in the Corporate segment had small order fluctuations between 2024 and 2025, Paper and Laptops saw major drops. Since Laptops have a much higher price point, the sharp decline in Laptop orders was the main driver behind the overall revenue loss.



-- Checking Total Orders On Each Sub_Category 2024 vs 2025.

SELECT Sub_Category,
SUM(CASE WHEN YEAR(Order_Date) = 2024 THEN 1 ELSE 0 END) AS Total_Orders_2024,
SUM(CASE WHEN YEAR(Order_Date) = 2025 THEN 1 ELSE 0 END) AS Total_Orders_2025
FROM SDB WHERE YEAR(Order_Date) IN (2024, 2025)
GROUP BY Sub_Category;

-- OBSERVATION: Most sub-categories showed normal growth or minor changes between 2024 and 2025, but Laptops saw a huge drop, with orders falling from 1,413 down to 769 (almost 45.6% drop).


  
-- Cheecking Average Customer_Rating across regions 2024 vs 2025?

SELECT Region,
ROUND(AVG(CASE WHEN YEAR(Order_Date) = 2024 THEN Customer_Rating ELSE NULL END), 2) AS Avg_Rating_2024,
ROUND(AVG(CASE WHEN YEAR(Order_Date) = 2025 THEN Customer_Rating ELSE NULL END), 2) AS Avg_Rating_2025,
ROUND(AVG(CASE WHEN YEAR(Order_Date) = 2025 THEN Customer_Rating ELSE NULL END) - AVG(CASE WHEN YEAR(Order_Date) = 2024 THEN Customer_Rating ELSE NULL END), 2) AS Rating_Difference
FROM SDB WHERE YEAR(Order_Date) IN (2024, 2025)
GROUP BY Region
ORDER BY Region;

-- OBSERVATION: Customer ratings in other regions remained stable around 3.86 to 3.92 but the West region saw a massive drop from 3.91 in 2024 to 3.14 in 2025 (a drop of 0.78). As identified earlier, the primary reason for this decline was the increase in average shipping delay days (6.23 days in 2025)



-- Checking Discounts Provided on Sub Categories.

SELECT Sub_Category,
ROUND(AVG(CASE WHEN YEAR(Order_Date) = 2024 THEN Discount_Applied ELSE NULL END) * 100, 2) AS Avg_Discount_2024,
ROUND(AVG(CASE WHEN YEAR(Order_Date) = 2025 THEN Discount_Applied ELSE NULL END) * 100, 2) AS Avg_Discount_2025
FROM SDB WHERE YEAR(Order_Date) IN (2024, 2025)
GROUP BY Sub_Category;

-- OBSERVATION: While most sub-categories maintained a consistent average discount of around 8% to 9%, four sub-categories—Furnishings, Bookcases, Tables, and Chairs—saw a massive jump in average discounts in 2025, spiking to over 20% to 21%.



-- Checking if higher discounts on these 4 categories led to higher net sales or not.

SELECT Sub_Category,
ROUND(SUM(CASE WHEN YEAR(Order_Date) = 2024 THEN (Unit_Price * Quantity) * (1 - Discount_Applied) ELSE 0 END), 2) AS Net_Sales_2024,
ROUND(SUM(CASE WHEN YEAR(Order_Date) = 2025 THEN (Unit_Price * Quantity) * (1 - Discount_Applied) ELSE 0 END), 2) AS Net_Sales_2025,
ROUND(SUM(CASE WHEN YEAR(Order_Date) = 2025 THEN (Unit_Price * Quantity) * (1 - Discount_Applied) ELSE 0 END) - SUM(CASE WHEN YEAR(Order_Date) = 2024 THEN (Unit_Price * Quantity) * (1 - Discount_Applied) ELSE 0 END), 2) AS Net_Sales_Difference
FROM SDB
WHERE Order_Status = 'Delivered'
AND Sub_Category IN ('Bookcases', 'Chairs', 'Furnishings', 'Tables') AND YEAR(Order_Date) IN (2024, 2025)
GROUP BY Sub_Category
ORDER BY Net_Sales_2025 DESC;

-- OBSERVATION: Heavy discounts in 2025 did not deliver the expected revenue boost for these sub-categories. Although Chairs and Furnishings had slight net sales gains, Tables and Bookcases suffered revenue drops, making the high-discount strategy largely ineffective.


-- ------------------------------------------------------------------------------------------------------------

-- Predicting Estimated Potential Revenue Recovery if Issues Were Fixed



-- Calculating revenue saved if 2025 orders with >2 days delivery delay were not cancelled

SELECT 
    COUNT(Order_ID) AS Total_Late_Cancelled_Orders,
    ROUND(SUM((Unit_Price * Quantity) * (1 - Discount_Applied)), 2) AS Potential_Revenue_Saved
FROM SDB WHERE YEAR(Order_Date) = 2025 AND Order_Status = 'Cancelled' AND Shipping_Delay_Days > 2;

-- OBSERVATION: In 2025, a total of 738 orders were cancelled due to delivery delays exceeding 2 days. Resolving these shipping bottlenecks could have saved approximately ₹1.43 Crore (₹14,370,678.45) in lost net revenue.



-- Calculating lost revenue from unfulfilled Laptop orders in 2025

WITH Laptop_Metrics AS (SELECT 
SUM(CASE WHEN YEAR(Order_Date) = 2024 THEN 1 ELSE 0 END) AS Orders_2024,
SUM(CASE WHEN YEAR(Order_Date) = 2025 THEN 1 ELSE 0 END) AS Orders_2025,
AVG(CASE WHEN YEAR(Order_Date) = 2025 THEN Unit_Price * (1 - Discount_Applied) ELSE NULL END) AS Avg_Net_Price_2025
FROM SDB WHERE Sub_Category = 'Laptops' AND Order_Status = 'Delivered')
SELECT Orders_2024, Orders_2025,
(Orders_2024 - Orders_2025) AS Lost_Laptop_Orders,
ROUND(Avg_Net_Price_2025, 2) AS Avg_Net_Price_Per_Laptop_2025,
ROUND((Orders_2024 - Orders_2025) * Avg_Net_Price_2025, 2) AS Potential_Revenue_Saved
FROM Laptop_Metrics;

-- OBSERVATION: In 2025, Laptop order volume dropped by 573 orders compared to 2024 (from 1,248 down to 675). Retaining Laptop order volume at the 2024 baseline level could have recovered approximately ₹4.00 Crore (₹39,962,889.85) in lost net revenue.



-- Calculating revenue deficit for Tables & Bookcases if 2024 baseline was maintained despite high discounts

WITH SubCategory_Annual_Sales AS (SELECT Sub_Category,
SUM(CASE WHEN YEAR(Order_Date) = 2024 THEN (Unit_Price * Quantity) * (1 - Discount_Applied) ELSE 0 END) AS Net_Sales_2024,
SUM(CASE WHEN YEAR(Order_Date) = 2025 THEN (Unit_Price * Quantity) * (1 - Discount_Applied) ELSE 0 END) AS Net_Sales_2025
FROM SDB WHERE Order_Status = 'Delivered' AND Sub_Category IN ('Tables', 'Bookcases') AND YEAR(Order_Date) IN (2024, 2025)
GROUP BY Sub_Category)
SELECT Sub_Category,
ROUND(Net_Sales_2024, 2) AS Sales_2024,
ROUND(Net_Sales_2025, 2) AS Sales_2025,
ROUND(Net_Sales_2024 - Net_Sales_2025, 2) AS Revenue_Deficit_Lost,
ROUND(Net_Sales_2024 - Net_Sales_2025, 2) AS Potential_Revenue_Recoverable
FROM SubCategory_Annual_Sales;

-- OBSERVATION: Despite offering high discounts (~21%) in 2025, net sales for Bookcases and Tables dropped compared to 2024. Maintaining the 2024 baseline revenue for these two categories could have recovered approximately ₹26.73 Lakhs (₹8.88L for Bookcases + ₹17.85L for Tables) in lost net revenue.

-- Total Potential Revenue Recovery: 5.70 Crore (57,006,531.05)

-- END