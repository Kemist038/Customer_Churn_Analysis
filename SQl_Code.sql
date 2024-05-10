USE Customer_Churn;

SHOW TABLES;
SET sql_mode =(SELECT REPLACE(@@sql_mode,  "ONLY_FULL_GROUP_BY",""));
SELECT * FROM Purchases;
SELECT * FROM Students;
SELECT * FROM Subscriptions;


# Net Revenue vs Refund, New vs Recurring Customer, Country wise Revenue
SELECT
	p.purchase_id,
    p.student_id,
    CASE
		WHEN p.subscription_type = 0 Then "Monthly"
        WHEN p.subscription_type = 2 Then "Yearly"
        WHEN p.subscription_type = 3 Then "LifeTime"
    END AS Subscription_Type,
    p.refund_id,
    p.refunded_date,
    CASE
		WHEN p.refunded_date IS NULL THEN "Revenue"
        ELSE "Refund"
    END AS Refunds,
    p.Price,
    MIN(p.Purchase_date) AS "First_Purchase_Date",
    p2.purchase_date AS "Current_Purchase_Date",
    CASE
		WHEN MIN(p.Purchase_date) = p2.purchase_date THEN "New_Customer"
        ELSE "Recurring_Customer"
    END AS Revenue_Type,
    s.student_Country
FROM
	purchases AS p
INNER JOIN
	Purchases AS p2 ON p.student_id = p2.student_id
LEFT JOIN 
	Students AS s ON p.student_id = s.student_id
GROUP BY p.purchase_id
ORDER BY p.Purchase_id;


# Total Churn, Acive Churn and Passive Churn
WITH active_users AS (
    SELECT 
        student_id, 
        DATE_FORMAT(subscription_period_start, '%Y-%m') AS month,
		subscription_type
    FROM 
        subscriptions s
	JOIN
		students st
	using (student_id)
    WHERE 
        cancelled_date IS NULL AND 
        next_charge_date >= DATE_FORMAT(s.subscription_period_start, '%Y-%m-01')
        and (subscription_type = 0 or subscription_type = 2 or subscription_type = 1)
     -- AND subscription_period_start <= DATE_ADD(subscription_period_start, INTERVAL -DAY(subscription_period_start)+1 DAY)
    GROUP BY 
        student_id, month
), canceled_users AS (
    SELECT 
        student_id, 
        DATE_FORMAT(cancelled_date, '%Y-%m') AS cancel_month,
		subscription_type
    FROM 
        subscriptions s
	JOIN
		students st
	using (student_id)
    WHERE 
        cancelled_date is not null
		 and (subscription_type = 0 or subscription_type = 2 or subscription_type = 1)
    GROUP BY 
        student_id, cancel_month
),
end_users AS (
    SELECT 
        student_id, 
        DATE_FORMAT(end_date, '%Y-%m') AS end_month, 
        subscription_type
    FROM 
        subscriptions s1
	JOIN
		students st
	using (student_id)
    WHERE 
       state is not null and cancelled_date is null
		and (subscription_type = 0 or subscription_type = 2 or subscription_type = 1)
    GROUP BY 
        student_id
), 
end_users_count as(
SELECT
end_month,
count(*) as number_ended_users
FROM 
end_users
GROUP BY 
  end_users.end_month
ORDER BY 
    end_users.end_month ASC)
    select 
	active_users.month,
    COUNT(DISTINCT active_users.student_id) AS active_users,
    SUM(COUNT(DISTINCT active_users.student_id)) OVER (ORDER BY active_users.month) as sum_active_users,
	COUNT(DISTINCT canceled_users.student_id) AS canceled_users,  
	number_ended_users,
    (COUNT(DISTINCT canceled_users.student_id) + number_ended_users)/ (SUM(COUNT(DISTINCT active_users.student_id)) OVER (ORDER BY active_users.month )) * 100 as churn_rate, 
    COUNT(DISTINCT canceled_users.student_id) / (SUM(COUNT(DISTINCT active_users.student_id)) OVER (ORDER BY active_users.month)) * 100 as active_churn_rate,
    number_ended_users/ (SUM(COUNT(DISTINCT active_users.student_id)) OVER (ORDER BY active_users.month)) * 100 as passive_churn_rate,
	active_users.subscription_type
from
    active_users
LEFT JOIN
    canceled_users 
    ON canceled_users.cancel_month = active_users.month
LEFT JOIN
	end_users_count
ON 
    end_users_count.end_month = active_users.month
JOIN
	students
on students.student_id = active_users.student_id
GROUP BY 
    active_users.month
ORDER BY 
    active_users.month ASC;