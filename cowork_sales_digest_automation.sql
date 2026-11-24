-- Snowflake CoWork Automations demo, weekly sales digest
-- Run the sections in order. Replace COMPUTE_WH with a warehouse you can use.

------------------------------------------------------------
-- 1. Dedicated database and schema
------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS COWORK_DEMO;
CREATE SCHEMA IF NOT EXISTS COWORK_DEMO.SALES;
USE SCHEMA COWORK_DEMO.SALES;

------------------------------------------------------------
-- 2. Sample data
------------------------------------------------------------
CREATE OR REPLACE TABLE DAILY_SALES AS
SELECT
    ROW_NUMBER() OVER (ORDER BY d.sale_date, c.category, r.region) AS sale_id,
    d.sale_date,
    c.category AS product_category,
    r.region,
    UNIFORM(20000, 90000, RANDOM()) AS sales_amount,
    UNIFORM(10, 80, RANDOM())       AS quantity
FROM (
    SELECT DATEADD(day, -SEQ4(), CURRENT_DATE()) AS sale_date
    FROM TABLE(GENERATOR(ROWCOUNT => 14))
) d
CROSS JOIN (SELECT column1 AS category FROM VALUES ('Electronics'), ('Apparel'), ('Food')) c
CROSS JOIN (SELECT column1 AS region   FROM VALUES ('North'), ('South'), ('West')) r;

SELECT * FROM DAILY_SALES ORDER BY sale_date DESC LIMIT 10;

------------------------------------------------------------
-- 3. Semantic view
------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW COWORK_DEMO.SALES.DAILY_SALES_SV
  TABLES (
    sales AS COWORK_DEMO.SALES.DAILY_SALES PRIMARY KEY (sale_id)
  )
  DIMENSIONS (
    sales.sale_date AS sale_date COMMENT = 'Date of the sale',
    sales.category  AS product_category COMMENT = 'Product category',
    sales.region    AS region COMMENT = 'Sales region'
  )
  METRICS (
    sales.total_sales AS SUM(sales.sales_amount) COMMENT = 'Total sales amount',
    sales.total_units AS SUM(sales.quantity) COMMENT = 'Total units sold'
  )
  COMMENT = 'Daily sales by category and region';

------------------------------------------------------------
-- 4. Agent
------------------------------------------------------------
CREATE OR REPLACE AGENT COWORK_DEMO.SALES.SALES_DIGEST_AGENT
  COMMENT = 'Answers sales questions for the weekly digest'
  PROFILE = '{"display_name": "Sales Digest Agent"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  instructions:
    response: "You are a sales analyst. Keep answers short and based on the data. When asked for a breakdown, include a chart."
    orchestration: "Use the sales_analyst tool for every question about sales, units, category or region."
  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "sales_analyst"
        description: "Answers questions about daily sales"
  tool_resources:
    sales_analyst:
      semantic_view: "COWORK_DEMO.SALES.DAILY_SALES_SV"
      execution_environment:
        type: warehouse
        warehouse: COMPUTE_WH
  $$;

------------------------------------------------------------
-- 5. Add the agent to CoWork
--    Without this the agent does not show up in the CoWork dropdown.
--    Agent Studio shows "Added to CoWork" as No until this is done.
------------------------------------------------------------
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
  ADD AGENT COWORK_DEMO.SALES.SALES_DIGEST_AGENT;

------------------------------------------------------------
-- 6. Cost check
--    Use SELECT * on the view if you want to see every available column.
------------------------------------------------------------
SELECT AGENT_NAME, TOKEN_CREDITS, AGENT_DATABASE_NAME, USER_NAME
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
ORDER BY START_TIME DESC
LIMIT 10;

------------------------------------------------------------
-- 7. Admin controls (optional, needs an admin role)
------------------------------------------------------------
-- Turn automations off for everyone
-- REVOKE EXECUTE AGENT TASK ON ACCOUNT FROM ROLE PUBLIC;

-- Allow only a specific role
-- REVOKE EXECUTE AGENT TASK ON ACCOUNT FROM ROLE PUBLIC;
-- GRANT EXECUTE AGENT TASK ON ACCOUNT TO ROLE ANALYST_ROLE;

------------------------------------------------------------
-- 8. Cleanup (optional)
--    Delete the automation in CoWork first, then drop the database.
--    The automation is stored in your personal database, not in COWORK_DEMO.
------------------------------------------------------------
-- DROP DATABASE IF EXISTS COWORK_DEMO;
