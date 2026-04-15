-- 14
WITH customer_metrics AS (
    SELECT
        CustomerID,
        SUM(CAST(SalePrice AS DECIMAL(10,2))) AS TotalRevenue,
        COUNT(OrderID) AS OrderCount,
        AVG(CAST(SalePrice AS DECIMAL(10,2))) AS AvgOrderValue
    FROM ecommerce_dataset_c
    GROUP BY CustomerID
),

max_values AS (
    SELECT
        MAX(TotalRevenue) AS MaxRevenue,
        MAX(OrderCount) AS MaxOrderCount,
        MAX(AvgOrderValue) AS MaxAvgValue
    FROM customer_metrics
),

composite_score AS (
    SELECT
        cm.CustomerID,
        cm.TotalRevenue,
        cm.OrderCount,
        cm.AvgOrderValue,
        ROUND(
            (0.5 * (cm.TotalRevenue / mv.MaxRevenue)) +
            (0.3 * (cm.OrderCount / mv.MaxOrderCount)) +
            (0.2 * (cm.AvgOrderValue / mv.MaxAvgValue)),
            4
        ) AS CompositeScore
    FROM customer_metrics cm
    CROSS JOIN max_values mv
)

SELECT *
FROM composite_score
ORDER BY CompositeScore DESC
LIMIT 5;


-- 15
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(CAST(OrderDate AS DATE), '%Y-%m') AS YearMonth,
        SUM(CAST(SalePrice AS DECIMAL(10,2))) AS TotalRevenue
    FROM ecommerce_dataset_c
    GROUP BY DATE_FORMAT(CAST(OrderDate AS DATE), '%Y-%m')
),

growth_calc AS (
    SELECT
        YearMonth,
        TotalRevenue,
        LAG(TotalRevenue) OVER (ORDER BY YearMonth) AS PrevMonthRevenue
    FROM monthly_revenue
)

SELECT
    YearMonth,
    TotalRevenue,
    PrevMonthRevenue,
    ROUND(
        ((TotalRevenue - PrevMonthRevenue) / PrevMonthRevenue) * 100, 2
    ) AS MoM_Growth_Percent
FROM growth_calc
WHERE PrevMonthRevenue IS NOT NULL
ORDER BY YearMonth;


-- 16

WITH revenue_by_month_category AS (
    SELECT
        DATE_FORMAT(CAST(OrderDate AS DATE), '%Y-%m') AS YearMonth,
        ProductCategory,
        SUM(CAST(SalePrice AS DECIMAL(10,2))) AS MonthlyRevenue
    FROM ecommerce_dataset_c
    GROUP BY DATE_FORMAT(CAST(OrderDate AS DATE), '%Y-%m'), ProductCategory
),

rolling_avg_calc AS (
    SELECT
        YearMonth,
        ProductCategory,
        MonthlyRevenue,
        ROUND(
            AVG(MonthlyRevenue) OVER (
                PARTITION BY ProductCategory
                ORDER BY YearMonth
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ),
            2
        ) AS Rolling_3_Month_Avg
    FROM revenue_by_month_category
)

SELECT *
FROM rolling_avg_calc
ORDER BY ProductCategory, YearMonth;

-- 17
UPDATE ecommerce_dataset_c
SET SalePrice = SalePrice * 0.85
WHERE CustomerID IN (
    SELECT CustomerID
    FROM (
        SELECT CustomerID
        FROM ecommerce_dataset_c
        GROUP BY CustomerID
        HAVING COUNT(*) >= 10
    ) AS eligible_customers
);

-- 18
WITH order_gaps AS (
    SELECT
        CustomerID,
        CAST(OrderDate AS DATE) AS OrderDate,
        DATEDIFF(
            CAST(OrderDate AS DATE),
            LAG(CAST(OrderDate AS DATE)) OVER (
                PARTITION BY CustomerID
                ORDER BY CAST(OrderDate AS DATE)
            )
        ) AS DaysBetweenOrders
    FROM ecommerce_dataset_c
),
qualified_customers AS (
    SELECT CustomerID
    FROM ecommerce_dataset_c
    GROUP BY CustomerID
    HAVING COUNT(*) >= 5
)

SELECT 
    og.CustomerID,
    ROUND(AVG(og.DaysBetweenOrders), 2) AS Avg_Days_Between_Orders
FROM order_gaps og
JOIN qualified_customers qc
    ON og.CustomerID = qc.CustomerID
WHERE og.DaysBetweenOrders IS NOT NULL
GROUP BY og.CustomerID
ORDER BY Avg_Days_Between_Orders;

-- 19
WITH customer_revenue AS (
    SELECT CustomerID, 
           SUM(CAST(SalePrice AS DECIMAL(10,2))) AS TotalRevenue
    FROM ecommerce_dataset_c
    WHERE Status = 'Delivered'
    GROUP BY CustomerID
),
average_revenue AS (
    SELECT AVG(TotalRevenue) AS AvgRevenue
    FROM customer_revenue
)
SELECT cr.CustomerID, cr.TotalRevenue
FROM customer_revenue cr
JOIN average_revenue ar ON 1 = 1
WHERE cr.TotalRevenue > ar.AvgRevenue * 1.3
ORDER BY cr.TotalRevenue DESC;

-- 20

WITH formatted_sales AS (
    SELECT 
        ProductCategory,
        YEAR(STR_TO_DATE(OrderDate, '%Y-%m-%d')) AS OrderYear,
        CAST(SalePrice AS DECIMAL(10,2)) AS SaleAmount
    FROM ecommerce_dataset_c
    WHERE Status = 'Delivered'
),

yearly_sales AS (
    SELECT 
        ProductCategory,
        OrderYear,
        SUM(SaleAmount) AS TotalSales
    FROM formatted_sales
    GROUP BY ProductCategory, OrderYear
),

sales_with_lag AS (
    SELECT 
        ProductCategory,
        OrderYear,
        TotalSales,
        LAG(TotalSales) OVER (PARTITION BY ProductCategory ORDER BY OrderYear) AS PrevYearSales
    FROM yearly_sales
),

growth_calculated AS (
    SELECT 
        ProductCategory,
        OrderYear,
        TotalSales AS CurrentYearSales,
        PrevYearSales AS PreviousYearSales,
        ROUND(((TotalSales - PrevYearSales) / PrevYearSales) * 100, 2) AS GrowthPercentage
    FROM sales_with_lag
    WHERE PrevYearSales IS NOT NULL
)

SELECT 
    ProductCategory,
    OrderYear,
    CurrentYearSales,
    PreviousYearSales,
    GrowthPercentage
FROM growth_calculated
ORDER BY GrowthPercentage DESC
LIMIT 3;








