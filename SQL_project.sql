-- As a product owner, I want to generate a report of individual product sales (aggregated on a monthly basis 
-- at the product code level) for Croma India customer for FY-2021 so that I can track individual product sales and run further product analytics on it in excel.
-- The report should have the following fields,
-- 1. Month
-- 2. Product Name
-- 3. Variant
-- 4. Sold Quantity
-- 5. Gross Price Per Item
-- 6. Gross Price Total

SELECT s.date, g.fiscal_year,
s.product_code,
p.product, p.variant,s.sold_quantity, 
g.gross_price, 
ROUND(g.gross_price*s.sold_quantity, 2) as gross_total_price
FROM fact_sales_monthly s
join dim_product p on 
s.product_code = p.product_code
join fact_gross_price g on 
g.product_code = s.product_code and
g.fiscal_year = get_fiscal_year(s.date)
WHERE
	customer_code = 90002002 and 
    get_fiscal_year(date) = 2021 
   -- and get_fiscal_quarter(date) = "Q4"
order by date asc;

--------------------------- - 

-- As a product owner, I need an aggregate monthly gross sales report for Croma India customer so that I can track 
-- how much sales this particular customer is generating for AtliQ and manage our relationships accordingly.
-- The report should have the following fields,
-- 1. Month
-- 2. Total gross sales amount to Croma India in this month
SELECT 
	s.date, 
	sum(ROUND(g.gross_price*s.sold_quantity, 2)) as gross_total_price, c.customer
FROM fact_sales_monthly s
join fact_gross_price g on 
g.product_code = s.product_code and
g.fiscal_year = get_fiscal_year(s.date)
join dim_customer c on
c.customer_code = s.customer_code
WHERE s.customer_code = 90002002
group by s.date
order by s.date asc;

#############################################################
#Function to get Fiscal Year
CREATE DEFINER=`root`@`localhost` FUNCTION `get_fiscal_year`(
	calender_date date
) RETURNS int
    DETERMINISTIC
BEGIN
	declare fiscal_year INT;
    set fiscal_year = YEAR(date_add(calender_date, INTERVAL 4 month));
	RETURN fiscal_year;
END

-- Generate a yearly report for Croma India where there are two columns
-- 1. Fiscal Year
-- 2. Total Gross Sales amount In that year from Croma

	SELECT 
		 g.fiscal_year,
		SUM(ROUND(g.gross_price*s.sold_quantity, 2)) as gross_total_price
	FROM fact_sales_monthly s
	join fact_gross_price g on 
	g.product_code = s.product_code and
	g.fiscal_year = get_fiscal_year(s.date)
	WHERE customer_code = 90002002
	-- group by g.fiscal_year
	group by g.fiscal_year;
    
    
    select
            get_fiscal_year(date) as fiscal_year,
            sum(round(sold_quantity*g.gross_price,2)) as yearly_sales
	from fact_sales_monthly s
	join fact_gross_price g
	on 
	    g.fiscal_year=get_fiscal_year(s.date) and
	    g.product_code=s.product_code
	where
	    customer_code=90002002
	group by get_fiscal_year(date)
	order by fiscal_year;



#customers by net sales for a given financial year so that I can have a holistic view of our financial performance and can take
#appropriate actions to address any potential issues.

#with cte1 as (
#SELECT pres.date, g.fiscal_year,
#s.product_code,
#p.product, p.variant,s.sold_quantity, 
#g.gross_price as gross_price_per_item, 
#c.market,
#ROUND(g.gross_price*s.sold_quantity, 2) as gross_total_price,
#pre.pre_invoice_discount_pct,
#(gross_total_price - gross_total_price*pre_invoice_discount_pct) as net_invoice_sales,
#(pd.discounts_pct + pd.other_deductions_pct) as post_invoice_deductions
#from pre_invoice_sales pres
# join fact_post_invoice_deductions pd on
#pres.date = pd.date and
# pres.product_code = pd.product_code

#############################################################
#CREATING VIEW TABLES
#Creating view table for net sales
#first we'll create a table named PRE_INVOICE_SALES with pre discount column
CREATE 
    ALGORITHM = UNDEFINED 
    DEFINER = `root`@`localhost` 
    SQL SECURITY DEFINER
VIEW `pre_invoice_sales` AS
    SELECT 
        `s`.`date` AS `date`,
        `g`.`fiscal_year` AS `fiscal_year`,
        `s`.`product_code` AS `product_code`,
        `p`.`product` AS `product`,
        `c`.`customer_code` AS `customer_code`,
        `p`.`variant` AS `variant`,
        `s`.`sold_quantity` AS `sold_quantity`,
        `g`.`gross_price` AS `gross_price_per_item`,
        `c`.`market` AS `market`,
        ROUND((`g`.`gross_price` * `s`.`sold_quantity`),
                2) AS `gross_total_price`,
        `pre`.`pre_invoice_discount_pct` AS `pre_invoice_discount_pct`
    FROM
        ((((`fact_sales_monthly` `s`
        JOIN `dim_product` `p` ON ((`s`.`product_code` = `p`.`product_code`)))
        JOIN `dim_customer` `c` ON ((`c`.`customer_code` = `s`.`customer_code`)))
        JOIN `fact_gross_price` `g` ON (((`g`.`product_code` = `s`.`product_code`)
            AND (`g`.`fiscal_year` = `s`.`fiscal_year`))))
        JOIN `fact_pre_invoice_deductions` `pre` ON (((`pre`.`customer_code` = `s`.`customer_code`)
            AND (`pre`.`fiscal_year` = `s`.`fiscal_year`))))
    ORDER BY `s`.`date`
    
# now using the PRE_INVOICE_SALES, creating a view table for POST_DEDUCTION_INVOICE

CREATE 
    ALGORITHM = UNDEFINED 
    DEFINER = `root`@`localhost` 
    SQL SECURITY DEFINER
VIEW `post_deduction_invoice` AS
    SELECT 
        `pre`.`date` AS `date`,
        `pre`.`fiscal_year` AS `fiscal_year`,
        `pre`.`product_code` AS `product_code`,
        `pre`.`product` AS `product`,
        `pre`.`customer_code` AS `customer_code`,
        `pre`.`variant` AS `variant`,
        `pre`.`sold_quantity` AS `sold_quantity`,
        `pre`.`gross_price_per_item` AS `gross_price_per_item`,
        `pre`.`market` AS `market`,
        `pre`.`gross_total_price` AS `gross_total_price`,
        `pre`.`pre_invoice_discount_pct` AS `pre_invoice_discount_pct`,
        ((1 - `pre`.`pre_invoice_discount_pct`) * `pre`.`gross_total_price`) AS `net_invoice_sales`,
        (`pd`.`discounts_pct` + `pd`.`other_deductions_pct`) AS `post_invoice_deductions`
    FROM
        (`pre_invoice_sales` `pre`
        JOIN `fact_post_invoice_deductions` `pd` ON (((`pre`.`product_code` = `pd`.`product_code`)
            AND (`pre`.`date` = `pd`.`date`))))
            
# Using the POST_DEDUCTION_INVOICE view table, creating our final table for net sales

CREATE 
    ALGORITHM = UNDEFINED 
    DEFINER = `root`@`localhost` 
    SQL SECURITY DEFINER
VIEW `net_sales` AS
    SELECT 
        `post_deduction_invoice`.`date` AS `date`,
        `post_deduction_invoice`.`fiscal_year` AS `fiscal_year`,
        `post_deduction_invoice`.`product_code` AS `product_code`,
        `post_deduction_invoice`.`product` AS `product`,
        `post_deduction_invoice`.`customer_code` AS `customer_code`,
        `post_deduction_invoice`.`variant` AS `variant`,
        `post_deduction_invoice`.`sold_quantity` AS `sold_quantity`,
        `post_deduction_invoice`.`gross_price_per_item` AS `gross_price_per_item`,
        `post_deduction_invoice`.`market` AS `market`,
        `post_deduction_invoice`.`gross_total_price` AS `gross_total_price`,
        `post_deduction_invoice`.`pre_invoice_discount_pct` AS `pre_invoice_discount_pct`,
        `post_deduction_invoice`.`net_invoice_sales` AS `net_invoice_sales`,
        `post_deduction_invoice`.`post_invoice_deductions` AS `post_invoice_deductions`,
        ROUND(((1 - `post_deduction_invoice`.`post_invoice_deductions`) * `post_deduction_invoice`.`net_invoice_sales`),
                2) AS `net_sales`
    FROM
        `post_deduction_invoice`

# Top 5 Market by net sales

select market,
round(sum(net_sales)/1000000,2) as net_sales_in_millions
from gdb0041.net_sales
where fiscal_year = 2021
group by market
order by net_sales_in_millions desc
limit 5;

# Top 5 customers by net sales

select customer,
round(sum(net_sales)/1000000,2) as net_sales_in_millions
from gdb0041.net_sales ns
join dim_customer c on
c.customer_code = ns.customer_code
where fiscal_year = 2021
group by customer
order by net_sales_in_millions desc
limit 5;
 
 # Top 5 products by net sales
 
 select product,
round(sum(net_sales)/1000000,2) as net_sales_in_millions
from gdb0041.net_sales
where fiscal_year = 2021
group by product
order by net_sales_in_millions desc
limit 5;





#WINDOW Function - over and partition

USE random_tables;
#pct of total by whole amount
select 
*,
amount*100/(SELECT SUM(amount) FROM expenses) as pct
from expenses
order by category;


# Pct of total partition by category
select 
*,
amount*100/SUM(amount)  over(partition by category) as pct
from expenses
order by category;

#Running sum of total by date and category
select *,
sum(amount) over(partition by category order by date) as running_total
from expenses
order by category, date;


#Top 2 category based on amount
with cte1 as (
select *,
row_number ()  over(partition by category order by amount desc) as rn,
rank() over(partition by category order by amount desc) as rnk,
dense_rank() over(partition by category order by amount desc) as drnk
from expenses
order by category
)
select * from cte1 
where drnk <=2;

#Ranking students based on their marks

select * from student_marks;
with cte2 as (
select *,
row_number ()  over(order by marks desc) as rn,
rank() over(order by marks desc) as rnk,
dense_rank() over(order by marks desc) as drnk
from student_marks
)
select * from cte2;

# Top products in each division by their quantity in FY 21 using rank
use gdb0041;

with cte3 as (
select division, product, sum(sold_quantity) as Total_quantity,
rank() over(partition by division order by sum(sold_quantity) desc) as rnk
from fact_sales_monthly s
join dim_product p on
s.product_code = p.product_code
where s.fiscal_year = 2021
group by product, division
)
select *
from cte3
where rnk <=3;


# Top 2 products by gross sales partition by region

with cte1 as (
		select
			c.market,
			c.region,
			round(sum(gross_price_total)/1000000,2) as gross_sales_mln
			from gross_sales s
			join dim_customer c
			on c.customer_code=s.customer_code
			where fiscal_year=2021
			group by c.market, c.region
			order by gross_sales_mln desc
		),
		cte2 as (
			select *,
			dense_rank() over(partition by region order by gross_sales_mln desc) as drnk
			from cte1
		)
	select * from cte2 where drnk<=2
		
# Supply chain forcast with sold_quantity and forecast_quantity
#created a view table
#select s.*, f.forecast_quantity
#from fact_sales_monthly s
#join fact_forecast_monthly f
#using (date, fiscal_year, product_code, customer_code)



SELECT *,
    SUM((CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) AS net_err,
    SUM((CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) * 100 / SUM(forecast_quantity) AS net_err_pct,
    SUM(ABS(CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) AS abs_err,
    SUM(ABS(CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) * 100 / SUM(forecast_quantity) AS abs_err_pct
FROM fact_act_est s
WHERE s.fiscal_year = 2021
GROUP BY s.customer_code, s.date
order by abs_err_pct;


########################################

#Forecast Accuracy percentage

with forecast_temp_table as ( 
SELECT s.customer_code,
	sum(s.sold_quantity) as total_sold_quantity,
    sum(s.forecast_quantity) as total_forecast_quantity,
    SUM((CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) AS net_err,
    SUM((CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) * 100 / SUM(forecast_quantity) AS net_err_pct,
    SUM(ABS(CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) AS abs_err,
    SUM(ABS(CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) * 100 / SUM(forecast_quantity) AS abs_err_pct,
    s.fiscal_year
FROM fact_act_est s
WHERE s.fiscal_year = 2021
group by customer_code
)
select t.*,
		c.customer,
        c.market,
		if(abs_err_pct >100, 0 , 100 - abs_err_pct) as forecast_accuracy
from forecast_temp_table t
join dim_customer c on
t.customer_code = c.customer_code 
order by forecast_accuracy desc;

#The supply chain business manager wants to see which customers’ forecast accuracy has dropped from 2020 to 2021. 
#Provide a complete report with these columns: customer_code, customer_name, market, forecast_accuracy_2020, forecast_accuracy_2021

#creating two separate CTE's for forecast accuracy for FY 2020 and 2021 and join them to display in a single table

with f_2021 as ( 
SELECT s.customer_code,
	sum(s.sold_quantity) as total_sold_quantity,
    sum(s.forecast_quantity) as total_forecast_quantity,
    SUM((CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) AS net_err,
    SUM((CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) * 100 / SUM(forecast_quantity) AS net_err_pct,
    SUM(ABS(CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) AS abs_err,
    SUM(ABS(CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) * 100 / SUM(forecast_quantity) AS abs_err_pct
FROM fact_act_est s
WHERE s.fiscal_year = 2021
group by customer_code
),
f_2020 as (
SELECT s.customer_code,
	sum(s.sold_quantity) as total_sold_quantity_2020,
    sum(s.forecast_quantity) as total_forecast_quantity_2020,
    SUM((CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) AS net_err_2020,
    SUM((CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) * 100 / SUM(forecast_quantity) AS net_err_pct_2020,
    SUM(ABS(CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) AS abs_err_2020,
    SUM(ABS(CONVERT(forecast_quantity, SIGNED) - CONVERT(sold_quantity, SIGNED))) * 100 / SUM(forecast_quantity) AS abs_err_pct_2020
FROM fact_act_est s
WHERE s.fiscal_year = 2020
group by customer_code
)
select  t.customer_code,
		c.customer,
        c.market,
		if(abs_err_pct >100, 0 , 100 - abs_err_pct) as forecast_accuracy_2021,
		if(abs_err_pct >100, 0 , 100 - abs_err_pct_2020) as forecast_accuracy_2020
from f_2021 t
join dim_customer c on
t.customer_code = c.customer_code 
join f_2020 s on
s.customer_code = t.customer_code
order by forecast_accuracy_2021 desc;

############### STORED PROCEDURE #################

# Get a badge (Gold or silver) on markets based on total quantity sold in a specific fiscal year
CREATE DEFINER=`root`@`localhost` PROCEDURE `Get_market_badge`(
  IN in_market VARCHAR(50),
    IN in_fiscal_year INT,
    OUT market_badge VARCHAR(10)
)
BEGIN
 DECLARE total_sold_quantity INT;

    -- Calculate the total sold quantity for the given market and fiscal year
    SELECT SUM(s.sold_quantity)
    INTO total_sold_quantity
    FROM fact_sales_monthly s
    JOIN dim_customer c 
    ON c.customer_code = s.customer_code
    WHERE c.market = in_market AND get_fiscal_year(s.date) = in_fiscal_year;

    -- Determine the market badge based on the total sold quantity
    IF total_sold_quantity > 5000000 THEN
        SET market_badge = 'Gold';
    ELSE
        SET market_badge = 'Silver';
    END IF;
END


		



 
 
 
