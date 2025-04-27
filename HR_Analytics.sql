-- Problem
/*
This project aims to use SQL script to create two separate analytical views for creating dashboards that can be used for reporting purposes, and 
give insights on the company's employees at diiferent levels which can then be used for decision making when it comes to payrise and promotions.

We’ve been tasked by our client HR Analytica to create 2 analytical views to power their dashboard outputs and further enable their in-house 
analytics team to generate additional reports and answer basic business questions using our data assets.
  1. A current view of the company, department and title level insights
    a. Total number of employees
    b. Average company tenure in years
    c. Gender ratios
    d. Average payrise percentage and amount
  
  2. A deep dive tool to investigate all information on a single employee.
    a. See all the various employment history ordered by effective date including salary, 
       department, manager and title changes.
    b. Calculate previous historic payrise percentages and value changes
    c. Calculate the previous position and department history in months with 
       start and end dates.
    d. Compare an employee’s current salary, total company tenure, department, position and gender 
       to the average benchmarks for their current position

*/


-- Exploration
-- We know we are dealing with a slowly changing dimension SCD dataset, whish has a from_date and to_date information
-- we have been provided with ER Diagram which shows how the tables are connected
-- We have also been notified that the table date field was mistakenly backdated by 18 years by an intern

/*
We are going to further look at each table to check for foriegn key distribution in order to know the 
kind of relationship it holds with primary keys. This can be a 1:1 relationship, 1:many relationship e.t.c.
*/

-- employees table
select *
from employees.employee
limit 5;

with emp_count as (
select 
  id,
  count(*) as record_value
from employees.employee
group by id
)
select 
  record_value,
  count(*) as number_of_emp_with_record_value
from emp_count
group by record_value;

-- we found that there employee table holds a 1:1 realtionship, which means, there is only one record for each employee



-- title table
select *
from employees.title
limit 5;

with title_count as(
select 
  employee_id,
  count(employee_id) as record_value
from employees.title
group by employee_id
)
select 
  record_value,
  count(*) as employees_with_record_value
from title_count
group by record_value;

-- we found that the title holds 1:many relationship, which means an employees can have more than
-- one title through out their career in the company


--salary
select *
from employees.salary
limit 5;

with salary_count as (
select 
  employee_id,
  count(*) as record_value
from employees.salary
group by employee_id
)
select 
  record_value,
  count(*) employees_with_record_value
from salary_count
group by record_value;

-- we found that the salary holds a 1:many relationship. An employee can have salary change over time

-- Department Employee table
select *
from employees.department_employee
limit 5;

with dept_emp_count as (
select 
  employee_id,
  count(*) as record_value
from employees.department_employee
group by employee_id
)
select 
  record_value,
  count(*) as employess_with_record_value
from dept_emp_count
group by record_value;

-- we found that the department_employee table holds a one to many relationship
-- one employees can change departments over time
-- at most 1 employee has changed department twice

-- Department Manager Table
select *
from employees.department_manager
limit 5;

with dept_manager_count as (
select 
  employee_id,
  count(department_id) as record_value
from employees.department_manager
group by employee_id
)
select
  record_value,
  count(*) as employees_with_record_value
from dept_manager_count
group by record_value

with dept_manager_count as (
select 
  department_id,
  count(distinct employee_id) as record_value
from employees.department_manager
group by department_id
)
select
  record_value,
  count(*) as departments_with_record_value
from dept_manager_count
group by record_value;

-- we found that one department can have records of different employees as manger
-- no one employee has ever been a manager for two different departments

--Department Table
select *
from employees.department
order by id;

-- thethere are 9 unique records in the department table
-- This implies that there are nine unique records for nine different departments

/*
We do not want to modify the original dataset when working on this project, so we have decided
create a copy of the original dataset with the help of materialized view. The materialized view
allows our data copy to be automatically updated whenever any changes is made to the original dataset
We will also create indexes on our materialized view which helps improve the speed of our queries when we run them
*/

DROP SCHEMA IF EXISTS mv_employees CASCADE;
CREATE SCHEMA mv_employees;

-- department
DROP MATERIALIZED VIEW IF EXISTS mv_employees.department;
CREATE MATERIALIZED VIEW mv_employees.department AS
SELECT * FROM employees.department;


-- department employee
DROP MATERIALIZED VIEW IF EXISTS mv_employees.department_employee;
CREATE MATERIALIZED VIEW mv_employees.department_employee AS
SELECT
  employee_id,
  department_id,
  (from_date + interval '18 years')::DATE AS from_date,
  CASE
    WHEN to_date <> '9999-01-01' THEN (to_date + interval '18 years')::DATE
    ELSE to_date
    END AS to_date
FROM employees.department_employee;

-- department manager
DROP MATERIALIZED VIEW IF EXISTS mv_employees.department_manager;
CREATE MATERIALIZED VIEW mv_employees.department_manager AS
SELECT
  employee_id,
  department_id,
  (from_date + interval '18 years')::DATE AS from_date,
  CASE
    WHEN to_date <> '9999-01-01' THEN (to_date + interval '18 years')::DATE
    ELSE to_date
    END AS to_date
FROM employees.department_manager;

-- employee
DROP MATERIALIZED VIEW IF EXISTS mv_employees.employee;
CREATE MATERIALIZED VIEW mv_employees.employee AS
SELECT
  id,
  (birth_date + interval '18 years')::DATE AS birth_date,
  first_name,
  last_name,
  gender,
  (hire_date + interval '18 years')::DATE AS hire_date
FROM employees.employee;

-- salary
DROP MATERIALIZED VIEW IF EXISTS mv_employees.salary;
CREATE MATERIALIZED VIEW mv_employees.salary AS
SELECT
  employee_id,
  amount,
  (from_date + interval '18 years')::DATE AS from_date,
  CASE
    WHEN to_date <> '9999-01-01' THEN (to_date + interval '18 years')::DATE
    ELSE to_date
    END AS to_date
FROM employees.salary;

-- title
DROP MATERIALIZED VIEW IF EXISTS mv_employees.title;
CREATE MATERIALIZED VIEW mv_employees.title AS
SELECT
  employee_id,
  title,
  (from_date + interval '18 years')::DATE AS from_date,
  CASE
    WHEN to_date <> '9999-01-01' THEN (to_date + interval '18 years')::DATE
    ELSE to_date
    END AS to_date
FROM employees.title;

-- Index Creation
-- NOTE: we do not name the indexes as they will be given randomly upon creation!
CREATE UNIQUE INDEX ON mv_employees.employee USING btree (id);
CREATE UNIQUE INDEX ON mv_employees.department_employee USING btree (employee_id, department_id);
CREATE INDEX        ON mv_employees.department_employee USING btree (department_id);
CREATE UNIQUE INDEX ON mv_employees.department USING btree (id);
CREATE UNIQUE INDEX ON mv_employees.department USING btree (dept_name);
CREATE UNIQUE INDEX ON mv_employees.department_manager USING btree (employee_id, department_id);
CREATE INDEX        ON mv_employees.department_manager USING btree (department_id);
CREATE UNIQUE INDEX ON mv_employees.salary USING btree (employee_id, from_date);
CREATE UNIQUE INDEX ON mv_employees.title USING btree (employee_id, title, from_date);

with current_employee as (
select 
  employee_id
from employees.salary
where to_date = '9999-01-01'
)
select
  count(*)
from employees.salary
where not exist
;


--Further Data Exploration
-- what is the total number of distinct employee
-- there are 300,023 unique employees from the employee tables
SELECT  
  COUNT(DISTINCT id) as employee_count
From employees.employee


-- how many total distinct employee_id are there in the rest of the table with from_date and to_date columns
-- how many records do we have for total number of employees with current date ('9999-01-01')

-- salary table
-- total employees
SELECT
  COUNT(DISTINCT employee_id) AS distinct_count
FROM mv_employees.salary;

--current date record
SELECT
  to_date,
  COUNT(*) AS record_count,
  COUNT(DISTINCT employee_id) AS employee_count
FROM mv_employees.salary
GROUP BY 1
ORDER BY 1 DESC
LIMIT 5;


-- department_employee table
-- total employees
SELECT
  COUNT(DISTINCT employee_id) AS distinct_count
FROM mv_employees.salary;

-- current date records
SELECT
  to_date,
  COUNT(*) AS record_count,
  COUNT(DISTINCT employee_id) AS employee_count
FROM mv_employees.department_employee
GROUP BY 1
ORDER BY 1 DESC
LIMIT 5;


-- title table
-- total employes
-- total employees
SELECT
  COUNT(DISTINCT employee_id) AS distinct_count
FROM mv_employees.title;

-- curent date record
SELECT
  to_date,
  COUNT(*) AS record_count,
  COUNT(DISTINCT employee_id) AS employee_count
FROM mv_employees.title
GROUP BY 1
ORDER BY 1 DESC
LIMIT 5;

/*
- From our exploration above, all tables have the same unique number of employees as 300,024
-  Tables with to_date columns have the same number of unique employees (240,124) in the current date
- Our current Snapshot data asset must have 240,124 total records for employees thtat are still working for the copany
*/


-- Cretaing the current Snapshot data asset
/*
For our current company, department and title level dashboard outputs we will first create a current snapshot view which 
we will use as the base for each of the aggregated layers for the different dashboard outputs.
  1. Apply LAG window functions on the salary materialized view to obtain the latest previous_salary value, keeping only
     current valid records with to_date = '9999-01-01'
     
  2. Join previous salary and all other required information from the materialized views for the dashboard analysis 
     (omitting the department_manager view)
     
  3. Apply WHERE filter to keep only current records
  
  4. Make sure to include the gender column from the employee view for all calculations
  
  5. Use the hire_date column from the employee view to calculate the number of tenure years
  
  6. Include the from_date columns from the title and department are included to calculate tenure
  
  7. Use the salary table to calculate the current average salary
  
  8. Include department and title information for additional group by aggregations
  
  9. Implement the various statistical measures for the salary amount
  
  10. Combine all of these elements into a single final current snapshot view

*/

DROP VIEW IF EXISTS mv_employees.current_employee_snapshot CASCADE;
CREATE VIEW mv_employees.current_employee_snapshot AS
-- apply LAG to get previous salary amount for all employees
WITH cte_previous_salary AS (
  SELECT * FROM (
    SELECT
      employee_id,
      to_date,
      LAG(amount) OVER (
        PARTITION BY employee_id
        ORDER BY from_date
      ) AS amount
    FROM mv_employees.salary
  ) all_salaries
  -- keep only latest valid previous_salary records only
  -- must have this in subquery to account for execution order
  WHERE to_date = '9999-01-01'
),
-- combine all elements into a joined CTE
cte_joined_data AS (
  SELECT
    employee.id AS employee_id,
    employee.gender,
    employee.hire_date,
    title.title,
    salary.amount AS salary,
    cte_previous_salary.amount AS previous_salary,
    department.dept_name AS department,
    -- need to keep the title and department from_date columns for tenure
    title.from_date AS title_from_date,
    department_employee.from_date AS department_from_date
  FROM mv_employees.employee
  INNER JOIN mv_employees.title
    ON employee.id = title.employee_id
  INNER JOIN mv_employees.salary
    ON employee.id = salary.employee_id
  -- join onto the CTE we created in the first step
  INNER JOIN cte_previous_salary
    ON employee.id = cte_previous_salary.employee_id
  INNER JOIN mv_employees.department_employee
    ON employee.id = department_employee.employee_id
  -- NOTE: department is joined only to the department_employee table!
  INNER JOIN mv_employees.department
    ON department_employee.department_id = department.id
  -- apply where filter to keep only relevant records
  WHERE salary.to_date = '9999-01-01'
    AND title.to_date = '9999-01-01'
    AND department_employee.to_date = '9999-01-01'
),
-- finally we can apply all our calculations in this final output
final_output AS (
  SELECT
    employee_id,
    gender,
    title,
    salary,
    department,
    -- salary change percentage
    ROUND(
      100 * (salary - previous_salary) / previous_salary::NUMERIC,
      2
    ) AS salary_percentage_change,
    -- tenure calculations
    DATE_PART('year', now()) -
      DATE_PART('year', hire_date) AS company_tenure_years,
    DATE_PART('year', now()) -
      DATE_PART('year', title_from_date) AS title_tenure_years,
    DATE_PART('year', now()) -
      DATE_PART('year', department_from_date) AS department_tenure_years
  FROM cte_joined_data
)
SELECT * FROM final_output;



-- Dashboard Aggregation Views

-- Company Level
-- company level aggregation view
DROP VIEW IF EXISTS mv_employees.company_level_dashboard;
CREATE VIEW mv_employees.company_level_dashboard AS
SELECT
  gender,
  COUNT(*) AS employee_count,
  ROUND(100 * COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER ()) AS employee_percentage,
  ROUND(AVG(company_tenure_years)) AS company_tenure,
  ROUND(AVG(salary)) AS avg_salary,
  ROUND(AVG(salary_percentage_change)) AS avg_salary_percentage_change,
  -- salary statistics
  ROUND(MIN(salary)) AS min_salary,
  ROUND(MAX(salary)) AS max_salary,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary)) AS median_salary,
  ROUND(
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary) -
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary)
  ) AS inter_quartile_range,
  ROUND(STDDEV(salary)) AS stddev_salary
FROM mv_employees.current_employee_snapshot
GROUP BY gender;


-- Department Level
-- department level aggregation view
DROP VIEW IF EXISTS mv_employees.department_level_dashboard;
CREATE VIEW mv_employees.department_level_dashboard AS
SELECT
  gender,
  department,
  COUNT(*) AS employee_count,
  ROUND(100 * COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER (
    PARTITION BY department
  )) AS employee_percentage,
  ROUND(AVG(department_tenure_years)) AS department_tenure,
  ROUND(AVG(salary)) AS avg_salary,
  ROUND(AVG(salary_percentage_change)) AS avg_salary_percentage_change,
  -- salary statistics
  ROUND(MIN(salary)) AS min_salary,
  ROUND(MAX(salary)) AS max_salary,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary)) AS median_salary,
  ROUND(
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary) -
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary)
  ) AS inter_quartile_range,
  ROUND(STDDEV(salary)) AS stddev_salary
FROM mv_employees.current_employee_snapshot
GROUP BY
  gender, department;
  
  
-- Title Level

-- title level aggregation view
DROP VIEW IF EXISTS mv_employees.title_level_dashboard;
CREATE VIEW mv_employees.title_level_dashboard AS
SELECT
  gender,
  title,
  COUNT(*) AS employee_count,
  ROUND(100 * COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER (
    PARTITION BY title
  )) AS employee_percentage,
  ROUND(AVG(title_tenure_years)) AS title_tenure,
  ROUND(AVG(salary)) AS avg_salary,
  ROUND(AVG(salary_percentage_change)) AS avg_salary_percentage_change,
  -- salary statistics
  ROUND(MIN(salary)) AS min_salary,
  ROUND(MAX(salary)) AS max_salary,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary)) AS median_salary,
  ROUND(
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary) -
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary)
  ) AS inter_quartile_range,
  ROUND(STDDEV(salary)) AS stddev_salary
FROM mv_employees.current_employee_snapshot
GROUP BY
  gender, title;


  
-- Creating the Historical Employee data asset


-- 1. Replace the view with an updated version with manager info
CREATE OR REPLACE VIEW mv_employees.current_employee_snapshot AS
-- apply LAG to get previous salary amount for all employees
WITH cte_previous_salary AS (
  SELECT * FROM (
    SELECT
      employee_id,
      to_date,
      LAG(amount) OVER (
        PARTITION BY employee_id
        ORDER BY from_date
      ) AS amount
    FROM mv_employees.salary
  ) all_salaries
  -- keep only latest valid previous_salary records only
  -- must have this in subquery to account for execution order
  WHERE to_date = '9999-01-01'
),
-- combine all elements into a joined CTE
cte_joined_data AS (
  SELECT
    employee.id AS employee_id,
    -- include employee full name
    CONCAT_WS(' ', employee.first_name, employee.last_name) AS employee_name,
    employee.gender,
    employee.hire_date,
    title.title,
    salary.amount AS salary,
    cte_previous_salary.amount AS previous_salary,
    department.dept_name AS department,
    -- include manager full name
    CONCAT_WS(' ', manager.first_name, manager.last_name) AS manager,
    -- need to keep the title and department from_date columns for tenure calcs
    title.from_date AS title_from_date,
    department_employee.from_date AS department_from_date
  FROM mv_employees.employee
  INNER JOIN mv_employees.title
    ON employee.id = title.employee_id
  INNER JOIN mv_employees.salary
    ON employee.id = salary.employee_id
  -- join onto the CTE we created in the first step
  INNER JOIN cte_previous_salary
    ON employee.id = cte_previous_salary.employee_id
  INNER JOIN mv_employees.department_employee
    ON employee.id = department_employee.employee_id
  -- NOTE: department is joined only to the department_employee table!
  INNER JOIN mv_employees.department
    ON department_employee.department_id = department.id
  -- add in the department_manager information onto the department table
  INNER JOIN mv_employees.department_manager
    ON department.id = department_manager.department_id
  -- join again on the employee_id field to another employee for manager's info
  INNER JOIN mv_employees.employee AS manager
    ON department_manager.employee_id = manager.id
  -- apply where filter to keep only relevant records
  WHERE salary.to_date = '9999-01-01'
    AND title.to_date = '9999-01-01'
    AND department_employee.to_date = '9999-01-01'
    -- add in department_manager to_date column filter
    AND department_manager.to_date = '9999-01-01'
)
-- finally we can apply all our calculations in this final output
SELECT
  employee_id,
  gender,
  title,
  salary,
  department,
  -- salary change percentage
  ROUND(
    100 * (salary - previous_salary) / previous_salary::NUMERIC,
    2
  ) AS salary_percentage_change,
  -- tenure calculations
  DATE_PART('year', now()) -
    DATE_PART('year', hire_date) AS company_tenure_years,
  DATE_PART('year', now()) -
    DATE_PART('year', title_from_date) AS title_tenure_years,
  DATE_PART('year', now()) -
    DATE_PART('year', department_from_date) AS department_tenure_years,
  -- need to add the two newest fields after original view columns!
  employee_name,
  manager
FROM cte_joined_data;

-- Run the following line to check that the counts are the same as before
-- SELECT COUNT(*) FROM mv_employees.current_employee_snapshot;
-- Expected result: 240,124


-- 2. Generate benchmark views for company tenure, gender, department and title
-- Note the slightly verbose column names - this helps us avoid renaming later!
DROP VIEW IF EXISTS mv_employees.tenure_benchmark;
CREATE VIEW mv_employees.tenure_benchmark AS
SELECT
  company_tenure_years,
  AVG(salary) AS tenure_benchmark_salary
FROM mv_employees.current_employee_snapshot
GROUP BY company_tenure_years;

DROP VIEW IF EXISTS mv_employees.gender_benchmark;
CREATE VIEW mv_employees.gender_benchmark AS
SELECT
  gender,
  AVG(salary) AS gender_benchmark_salary
FROM mv_employees.current_employee_snapshot
GROUP BY gender;

DROP VIEW IF EXISTS mv_employees.department_benchmark;
CREATE VIEW mv_employees.department_benchmark AS
SELECT
  department,
  AVG(salary) AS department_benchmark_salary
FROM mv_employees.current_employee_snapshot
GROUP BY department;

DROP VIEW IF EXISTS mv_employees.title_benchmark;
CREATE VIEW mv_employees.title_benchmark AS
SELECT
  title,
  AVG(salary) AS title_benchmark_salary
FROM mv_employees.current_employee_snapshot
GROUP BY title;


-- 3. Create a historic employee record view with all previously generated views
DROP VIEW IF EXISTS mv_employees.historic_employee_records CASCADE;
CREATE VIEW mv_employees.historic_employee_records AS
-- we need the previous salary only for the latest record
-- other salary increase/decrease events will use a different field!
WITH cte_previous_salary AS (
  SELECT
    employee_id,
    amount
  FROM (
    SELECT
      employee_id,
      to_date,
      LAG(amount) OVER (
        PARTITION BY employee_id
        ORDER BY from_date
      ) AS amount,
      -- need to rank by descending to get latest record
      ROW_NUMBER() OVER (
        PARTITION BY employee_id
        ORDER BY to_date DESC
      ) AS record_rank
    FROM mv_employees.salary
  ) all_salaries
  -- keep only latest previous_salary records only
  -- must have this in subquery to account for execution order
  WHERE record_rank = 1
),
cte_join_data AS (
SELECT
  employee.id AS employee_id,
  employee.birth_date,
  -- calculated employee_age field
  DATE_PART('year', now()) -
    DATE_PART('year', employee.birth_date) AS employee_age,
  -- employee full name
  CONCAT_WS(' ', employee.first_name, employee.last_name) AS employee_name,
  employee.gender,
  employee.hire_date,
  title.title,
  salary.amount AS salary,
  -- need to separately define the previous_latest_salary
  -- to differentiate between the following lag record!
  cte_previous_salary.amount AS previous_latest_salary,
  department.dept_name AS department,
  -- use the `manager` aliased version of employee table for manager
  CONCAT_WS(' ', manager.first_name, manager.last_name) AS manager,
  -- calculated tenure fields
  DATE_PART('year', now()) -
    DATE_PART('year', employee.hire_date) AS company_tenure_years,
  DATE_PART('year', now()) -
    DATE_PART('year', title.from_date) AS title_tenure_years,
  DATE_PART('year', now()) -
    DATE_PART('year', department_employee.from_date) AS department_tenure_years,
  -- we also need to use AGE & DATE_PART functions here to generate month diff
  DATE_PART('months', AGE(now(), title.from_date)) AS title_tenure_months,
  GREATEST(
    title.from_date,
    salary.from_date,
    department_employee.from_date,
    department_manager.from_date
  ) AS effective_date,
  LEAST(
    title.to_date,
    salary.to_date,
    department_employee.to_date,
    department_manager.to_date
  ) AS expiry_date
FROM mv_employees.employee
INNER JOIN mv_employees.title
  ON employee.id = title.employee_id
INNER JOIN mv_employees.salary
  ON employee.id = salary.employee_id
INNER JOIN mv_employees.department_employee
  ON employee.id = department_employee.employee_id
-- NOTE: department is joined only to the department_employee table!
INNER JOIN mv_employees.department
  ON department_employee.department_id = department.id
-- add in the department_manager information onto the department table
INNER JOIN mv_employees.department_manager
  ON department.id = department_manager.department_id
-- join again on the employee_id field to another employee for manager's info
INNER JOIN mv_employees.employee AS manager
  ON department_manager.employee_id = manager.id
-- join onto our previous cte_previous_salary only for previous_latest_salary
INNER JOIN cte_previous_salary
  ON mv_employees.employee.id = cte_previous_salary.employee_id
),
-- now we apply the window function to order our transactions
-- we will filter out the top 5 in the next CTE step
cte_ordered_transactions AS (
  SELECT
    employee_id,
    birth_date,
    employee_age,
    employee_name,
    gender,
    hire_date,
    title,
    LAG(title) OVER w AS previous_title,
    salary,
    -- previous latest salary is based off the CTE
    previous_latest_salary,
    LAG(salary) OVER w AS previous_salary,
    department,
    LAG(department) OVER w AS previous_department,
    manager,
    LAG(manager) OVER w AS previous_manager,
    company_tenure_years,
    title_tenure_years,
    title_tenure_months,
    department_tenure_years,
    effective_date,
    expiry_date,
    -- we use a reverse ordered effective date window to capture last 5 events
    ROW_NUMBER() OVER (
      PARTITION BY employee_id
      ORDER BY effective_date DESC
    ) AS event_order
  FROM cte_join_data
  -- apply logical filter to remove invalid records resulting from the join
  WHERE effective_date <= expiry_date
  -- define window frame with chronological ordering by effective date
  WINDOW
    w AS (PARTITION BY employee_id ORDER BY effective_date)
),
-- finally we apply our case when statements to generate the employee events
-- and generate our benchmark comparisons for the final output
-- we aliased our FROM table as "base" for compact code!
final_output AS (
  SELECT
    base.employee_id,
    base.gender,
    base.birth_date,
    base.employee_age,
    base.hire_date,
    base.title,
    base.employee_name,
    base.previous_title,
    base.salary,
    -- previous latest salary is based off the CTE
    previous_latest_salary,
    -- previous salary is based off the LAG records
    base.previous_salary,
    base.department,
    base.previous_department,
    base.manager,
    base.previous_manager,
    -- tenure metrics
    base.company_tenure_years,
    base.title_tenure_years,
    base.title_tenure_months,
    base.department_tenure_years,
    base.event_order,
    -- only include the latest salary change for the first event_order row
    CASE
      WHEN event_order = 1
        THEN ROUND(
          100 * (base.salary - base.previous_latest_salary) /
            base.previous_latest_salary::NUMERIC,
          2
        )
      ELSE NULL
    END AS latest_salary_percentage_change,
    -- event type logic by comparing all of the previous lag records
    CASE
      WHEN base.previous_salary < base.salary
        THEN 'Salary Increase'
      WHEN base.previous_salary > base.salary
        THEN 'Salary Decrease'
      WHEN base.previous_department <> base.department
        THEN 'Dept Transfer'
      WHEN base.previous_manager <> base.manager
        THEN 'Reporting Line Change'
      WHEN base.previous_title <> base.title
        THEN 'Title Change'
      ELSE NULL
    END AS event_name,
    -- salary change
    ROUND(base.salary - base.previous_salary) AS salary_amount_change,
    ROUND(
      100 * (base.salary - base.previous_salary) / base.previous_salary::NUMERIC,
      2
    ) AS salary_percentage_change,
    -- benchmark comparisons - we've omit the aliases for succinctness!
    -- tenure
    ROUND(tenure_benchmark_salary) AS tenure_benchmark_salary,
    ROUND(
      100 * (base.salary - tenure_benchmark_salary)
        / tenure_benchmark_salary::NUMERIC
    ) AS tenure_comparison,
    -- title
    ROUND(title_benchmark_salary) AS title_benchmark_salary,
    ROUND(
      100 * (base.salary - title_benchmark_salary)
        / title_benchmark_salary::NUMERIC
    ) AS title_comparison,
    -- department
    ROUND(department_benchmark_salary) AS department_benchmark_salary,
    ROUND(
      100 * (salary - department_benchmark_salary)
        / department_benchmark_salary::NUMERIC
    ) AS department_comparison,
    -- gender
    ROUND(gender_benchmark_salary) AS gender_benchmark_salary,
    ROUND(
      100 * (base.salary - gender_benchmark_salary)
        / gender_benchmark_salary::NUMERIC
    ) AS gender_comparison,
    -- usually best practice to leave the effective/expiry dates at the end
    base.effective_date,
    base.expiry_date
  FROM cte_ordered_transactions AS base  -- used alias here for the joins below
  INNER JOIN mv_employees.tenure_benchmark
    ON base.company_tenure_years = tenure_benchmark.company_tenure_years
  INNER JOIN mv_employees.title_benchmark
    ON base.title = title_benchmark.title
  INNER JOIN mv_employees.department_benchmark
    ON base.department = department_benchmark.department
  INNER JOIN mv_employees.gender_benchmark
    ON base.gender = gender_benchmark.gender
  -- apply filter to only keep the latest 5 events per employee
  -- WHERE event_order <= 5
)
-- finally we are done with the historic values
SELECT * FROM final_output;

-- This final view powers the employee deep dive tool
-- by keeping only the 5 latest events
DROP VIEW IF EXISTS mv_employees.employee_deep_dive;
CREATE VIEW mv_employees.employee_deep_dive AS
SELECT *
FROM mv_employees.historic_employee_records
WHERE event_order <= 5;

