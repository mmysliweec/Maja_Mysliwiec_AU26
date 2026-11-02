-- ============================================================================
-- Part 1: Write SQL queries to retrieve the following data.
-- ============================================================================

-- ============================================================================
-- TASK 1: The marketing team needs a list of animation movies between 2017 
-- and 2019 to promote family-friendly content.
--
-- ASSUMPTIONS & BUSINESS LOGIC:
-- 1. We assume the timeframe is inclusive (BETWEEN operator covers 2017 and 2019).
-- 2. "Animation" is identified by the category name.
-- 3. Rental rate must be strictly greater than 1 (> 1).
--
-- ADVANTAGES & DISADVANTAGES:
-- JOIN: 
-- Pros: Native to relational databases, easily optimized by the query planner, simple to read.
-- Cons: Can lead to duplicate rows if the relation is one-to-many (though not an issue here).
-- SUBQUERY: 
-- Pros: Good for isolating specific IDs before joining, preventing duplicates early.
-- Cons: Can be slower if executed row-by-row (correlated) or if the subquery returns a massive dataset.
-- CTE: 
-- Pros: Excellent readability, clearly separates the logic of finding the "Animation" category.
-- Cons: Slight overhead for very simple queries compared to standard JOINs.
--
-- PRODUCTION RECOMMENDATION:
-- I would use the JOIN solution. It is the most direct, standard approach for basic filtering across relational tables, and the database engine will optimize it perfectly.
-- ============================================================================

-- JOIN
SELECT f.title, f.release_year, f.rental_rate
FROM public.film f
-- keeping only the rows that match in both tables (only films with an assigned category)
INNER JOIN public.film_category fc ON f.film_id = fc.film_id
INNER JOIN public.category c ON fc.category_id = c.category_id
WHERE c.name = 'Animation'
  AND f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title ASC;

-- SUBQUERY
SELECT f.title, f.release_year, f.rental_rate
FROM public.film f
WHERE f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
  AND f.film_id IN (
      SELECT fc.film_id
      FROM public.film_category fc
      INNER JOIN public.category c ON fc.category_id = c.category_id
      WHERE c.name = 'Animation'
  )
ORDER BY f.title ASC;

-- CTE
WITH AnimationCategory AS (
    SELECT fc.film_id
    FROM public.film_category fc
    INNER JOIN public.category c ON fc.category_id = c.category_id
    WHERE c.name = 'Animation'
)
SELECT f.title, f.release_year, f.rental_rate
FROM public.film f
INNER JOIN AnimationCategory ac ON f.film_id = ac.film_id
WHERE f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title ASC;


-- ============================================================================
-- TASK 2: The finance department requires a report on store performance to assess profitability...
--
-- ASSUMPTIONS & BUSINESS LOGIC:
-- 1. "Profitability/performance" is calculated as the sum of payment amounts per store.
-- 2. Timeframe starts from '2017-04-01' (inclusive).
--
-- ADVANTAGES & DISADVANTAGES:
-- JOIN: 
-- Pros: Consolidates all relations in one block, easy to write.
-- Cons: Grouping happens at the very end after all joins, which can process a large intermediate dataset.
-- SUBQUERY: 
-- Pros: Pre-defines the address dataset, isolating specific logic.
-- Cons: Inline views in the FROM/JOIN clause can make the query look cluttered.
-- CTE: 
-- Pros: Makes the complex relation between rental, inventory, store, and address highly readable before joining payments.
-- Cons: Takes up more lines of code.
--
-- PRODUCTION RECOMMENDATION:
-- I would use the CTE solution. Separating the store-address mapping into a CTE makes the main query focused solely on calculating revenue, which greatly improves maintainability.
-- ============================================================================

-- JOIN
SELECT 
    CONCAT_WS(', ', a.address, a.address2) AS full_address, 
    SUM(p.amount) AS revenue
FROM public.payment p
-- rejecting payments not related to any rental
INNER JOIN public.rental r ON p.rental_id = r.rental_id
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.store s ON i.store_id = s.store_id
-- retai ing all shops, even if some data is missing from the ‘address’ table - will return NULL
LEFT JOIN public.address a ON s.address_id = a.address_id
WHERE p.payment_date >= '2017-04-01'
GROUP BY a.address, a.address2;

-- SUBQUERY
SELECT 
    CONCAT_WS(', ', addr.address, addr.address2) AS full_address,
    SUM(p.amount) AS revenue
FROM public.payment p
INNER JOIN (
    SELECT r.rental_id, a.address, a.address2
    FROM public.rental r
    INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
    INNER JOIN public.store s ON i.store_id = s.store_id
    LEFT JOIN public.address a ON s.address_id = a.address_id
) addr ON p.rental_id = addr.rental_id
WHERE p.payment_date >= '2017-04-01'
GROUP BY addr.address, addr.address2;

-- CTE
WITH StoreRentals AS (
    SELECT r.rental_id, a.address, a.address2
    FROM public.rental r
    INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
    INNER JOIN public.store s ON i.store_id = s.store_id
    LEFT JOIN public.address a ON s.address_id = a.address_id
)
SELECT 
    CONCAT_WS(', ', sr.address, sr.address2) AS full_address,
    SUM(p.amount) AS revenue
FROM public.payment p
INNER JOIN StoreRentals sr ON p.rental_id = sr.rental_id
WHERE p.payment_date >= '2017-04-01'
GROUP BY sr.address, sr.address2;


-- ============================================================================
-- TASK 3: The marketing department aims to identify the most successful actors since 2015...
--
-- ASSUMPTIONS & BUSINESS LOGIC:
-- 1. "Most successful" is defined purely by the highest count of film appearances.
-- 2. Only films released in or after 2015 are considered.
-- 3. The top 5 actors are required.
--
-- ADVANTAGES & DISADVANTAGES:
-- JOIN: 
-- Pros: Shortest syntax.
-- Cons: Requires grouping by multiple actor columns (id, first_name, last_name).
-- SUBQUERY: 
-- Pros: Selects the count directly in the SELECT clause without needing a global GROUP BY.
-- Cons: Correlated subquery – it executes the count for EVERY actor row, which is terrible for performance on large databases.
-- CTE: 
-- Pros: Pre-aggregates film counts by actor_id first, meaning the final join to the actor table is lightweight and performant.
-- Cons: Slightly more verbose.
--
-- PRODUCTION RECOMMENDATION:
-- I would use the CTE solution. Pre-aggregating data by ID before joining descriptive tables (like actor names) is a best practice for query performance and readability.
-- ============================================================================

-- JOIN
SELECT a.first_name, a.last_name, COUNT(f.film_id) AS number_of_movies
FROM public.actor a
-- filtering out actors with no movies and movies with no actors
INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
INNER JOIN public.film f ON fa.film_id = f.film_id
WHERE f.release_year >= 2015
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY number_of_movies DESC
LIMIT 5;

-- SUBQUERY
SELECT a.first_name, a.last_name, 
       (SELECT COUNT(*) 
        FROM public.film_actor fa 
        INNER JOIN public.film f ON fa.film_id = f.film_id 
        WHERE fa.actor_id = a.actor_id AND f.release_year >= 2015) AS number_of_movies
FROM public.actor a
ORDER BY number_of_movies DESC
LIMIT 5;

-- CTE
WITH ActorMovieCounts AS (
    SELECT fa.actor_id, COUNT(f.film_id) AS number_of_movies
    FROM public.film_actor fa
    INNER JOIN public.film f ON fa.film_id = f.film_id
    WHERE f.release_year >= 2015
    GROUP BY fa.actor_id
)
SELECT a.first_name, a.last_name, amc.number_of_movies
FROM public.actor a
INNER JOIN ActorMovieCounts amc ON a.actor_id = amc.actor_id
ORDER BY amc.number_of_movies DESC
LIMIT 5;


-- ============================================================================
-- TASK 4: The marketing team needs to track the production trends of Drama, Travel, and Documentary films...
--
-- ASSUMPTIONS & BUSINESS LOGIC:
-- 1. "Trends" implies grouping by release_year and pivoting the counts of specific categories.
-- 2. We only care about films that belong to one of these three categories.
--
-- ADVANTAGES & DISADVANTAGES:
-- JOIN: 
-- Pros: Single query block, efficient filtering using IN clause.
-- Cons: The CASE statements can make the SELECT clause a bit bulky.
-- SUBQUERY: 
-- Pros: Filters categories before joining, theoretically reducing the dataset early.
-- Cons: Often unnecessary as the query optimizer does this automatically.
-- CTE: 
-- Pros: Cleans up the main query by pre-joining and filtering the raw dataset.
-- Cons: Might be considered overkill for a simple pivot table.
--
-- PRODUCTION RECOMMENDATION:
-- I would use the JOIN solution. It is straightforward, handles the conditional aggregation (pivoting) effectively, and the database engine will optimize the WHERE IN clause efficiently without needing extra CTE overhead.
-- ============================================================================

-- JOIN
SELECT 
    f.release_year,
    SUM(CASE WHEN c.name = 'Drama' THEN 1 ELSE 0 END) AS number_of_drama_movies,
    SUM(CASE WHEN c.name = 'Travel' THEN 1 ELSE 0 END) AS number_of_travel_movies,
    SUM(CASE WHEN c.name = 'Documentary' THEN 1 ELSE 0 END) AS number_of_documentary_movies
FROM public.film f
-- only films with assigned categories are processed
INNER JOIN public.film_category fc ON f.film_id = fc.film_id
INNER JOIN public.category c ON fc.category_id = c.category_id
WHERE c.name IN ('Drama', 'Travel', 'Documentary')
GROUP BY f.release_year
ORDER BY f.release_year DESC;

-- SUBQUERY
SELECT 
    f.release_year,
    SUM(CASE WHEN c.name = 'Drama' THEN 1 ELSE 0 END) AS number_of_drama_movies,
    SUM(CASE WHEN c.name = 'Travel' THEN 1 ELSE 0 END) AS number_of_travel_movies,
    SUM(CASE WHEN c.name = 'Documentary' THEN 1 ELSE 0 END) AS number_of_documentary_movies
FROM public.film f
INNER JOIN public.film_category fc ON f.film_id = fc.film_id
-- restricting the set of categories prior to the actual join
INNER JOIN (
    SELECT category_id, name 
    FROM public.category 
    WHERE name IN ('Drama', 'Travel', 'Documentary')
) c ON fc.category_id = c.category_id
GROUP BY f.release_year
ORDER BY f.release_year DESC;

-- CTE
WITH CategoryData AS (
    SELECT f.release_year, c.name AS category_name
    FROM public.film f
    INNER JOIN public.film_category fc ON f.film_id = fc.film_id
    INNER JOIN public.category c ON fc.category_id = c.category_id
    WHERE c.name IN ('Drama', 'Travel', 'Documentary')
)
SELECT 
    release_year,
    SUM(CASE WHEN category_name = 'Drama' THEN 1 ELSE 0 END) AS number_of_drama_movies,
    SUM(CASE WHEN category_name = 'Travel' THEN 1 ELSE 0 END) AS number_of_travel_movies,
    SUM(CASE WHEN category_name = 'Documentary' THEN 1 ELSE 0 END) AS number_of_documentary_movies
FROM CategoryData
GROUP BY release_year
ORDER BY release_year DESC;


-- ============================================================================
-- Part 2: Solve the following problems using SQL
-- ============================================================================

-- ============================================================================
-- TASK 1: The HR department aims to reward top-performing employees in 2017 with bonuses...
-- Show which three employees generated the most revenue in 2017?
-- 
-- ASSUMPTIONS & BUSINESS LOGIC:
-- 1. Staff could work in several stores; indicate the last one based on payment_date.
-- 2. Top 3 employees are determined by total sum of payments processed in 2017.
-- 3. If staff processed the payment, they work in the same store associated with that rental/inventory.
--
-- ADVANTAGES & DISADVANTAGES:
-- JOIN ONLY: Not feasible without window functions or subqueries (see explanation below).
-- SUBQUERY: 
-- Pros: Gets the last store ID inline for each aggregated staff member.
-- Cons: Correlated subquery with ORDER BY and LIMIT 1 can be extremely slow on large tables.
-- CTE: 
-- Pros: Modularity. We clearly separate total revenue calculation from finding the max date, and then finding the store for that max date.
-- Cons: Requires multiple passes over the payment table.
--
-- PRODUCTION RECOMMENDATION:
-- Without window functions (which would be best here using ROW_NUMBER), the CTE solution is much safer for production than a correlated subquery, as it avoids executing a sort/limit operation per row.
--
-- MISSING SOLUTION EXPLANATION (JOIN ONLY):
-- Executing this task using ONLY standard JOINs (without Subqueries, CTEs, or Window Functions) is logically impossible. The query requires aggregation on two different levels simultaneously: 
-- 1. Summing total revenue per staff for 2017.
-- 2. Fetching a non-aggregated attribute (store_id) corresponding to the exact row with the MAX(payment_date) for that staff. 
-- Standard GROUP BY cannot return a specific unaggregated row's details without a subquery or CTE to isolate the max date first.
-- ============================================================================

-- CTE
WITH StaffRevenue AS (
    SELECT p.staff_id, SUM(p.amount) AS total_revenue
    FROM public.payment p
    WHERE p.payment_date >= '2017-01-01' AND p.payment_date < '2018-01-01'
    GROUP BY p.staff_id
),
LastPaymentDates AS (
    SELECT p.staff_id, MAX(p.payment_date) AS max_date
    FROM public.payment p
    WHERE p.payment_date >= '2017-01-01' AND p.payment_date < '2018-01-01'
    GROUP BY p.staff_id
),
LastStore AS (
    SELECT lp.staff_id, i.store_id
    FROM LastPaymentDates lp
    -- filtering only those payments that match the maximum date exactly
    INNER JOIN public.payment p ON lp.staff_id = p.staff_id AND lp.max_date = p.payment_date
    INNER JOIN public.rental r ON p.rental_id = r.rental_id
    INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
)
SELECT s.first_name, s.last_name, sr.total_revenue, ls.store_id AS last_store_id
FROM public.staff s
INNER JOIN StaffRevenue sr ON s.staff_id = sr.staff_id
LEFT JOIN LastStore ls ON s.staff_id = ls.staff_id
ORDER BY sr.total_revenue DESC
LIMIT 3;

-- SUBQUERY
SELECT 
    s.first_name, 
    s.last_name, 
    SUM(p.amount) AS total_revenue,
    (
        SELECT i.store_id 
        FROM public.payment p2 
        INNER JOIN public.rental r ON p2.rental_id = r.rental_id
        INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
        WHERE p2.staff_id = s.staff_id 
          AND p2.payment_date >= '2017-01-01' 
          AND p2.payment_date < '2018-01-01'
        ORDER BY p2.payment_date DESC 
        LIMIT 1
    ) AS last_store_id
FROM public.staff s
--  only records with matches, excluding staff with no transactions
INNER JOIN public.payment p ON s.staff_id = p.staff_id
WHERE p.payment_date >= '2017-01-01' AND p.payment_date < '2018-01-01'
GROUP BY s.staff_id, s.first_name, s.last_name
ORDER BY total_revenue DESC
LIMIT 3;


-- ============================================================================
-- TASK 2: The management team wants to identify the most popular movies and their target audience age groups...
-- Show which 5 movies were rented more than others... use 'Motion Picture Association film rating system'
--
-- ASSUMPTIONS & BUSINESS LOGIC:
-- 1. "Most popular" is determined by the highest count of rental_id.
-- 2. MPAA ratings map to ages logically (G=All, PG=7+, PG-13=13+, R=17+, NC-17=18+).
--
-- ADVANTAGES & DISADVANTAGES:
-- JOIN: 
-- Pros: Simple and direct grouping.
-- Cons: Requires grouping by rating, which is fine here but bulky in wider tables.
-- SUBQUERY: 
-- Pros: Avoids joining massive rental tables in the main FROM clause.
-- Cons: Correlated subquery executes the count per film row, which is inefficient.
-- CTE: 
-- Pros: Pre-calculates rentals per film_id first, avoiding massive Cartesian products before grouping.
-- Cons: Verbose setup.
--
-- PRODUCTION RECOMMENDATION:
-- CTE is highly recommended here. Aggregating the `rental` table down to `film_id` counts first before joining the textual `film` data reduces memory footprint during query execution.
-- ============================================================================

-- JOIN
SELECT 
    f.title, 
    COUNT(r.rental_id) AS number_of_rentals,
    CASE f.rating
        WHEN 'G' THEN 'All ages'
        WHEN 'PG' THEN '7+'
        WHEN 'PG-13' THEN '13+'
        WHEN 'R' THEN '17+'
        WHEN 'NC-17' THEN '18+'
        ELSE 'Unknown'
    END AS expected_age
FROM public.film f
-- I only count those films that have actually been added to inventory and rented
INNER JOIN public.inventory i ON f.film_id = i.film_id
INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
GROUP BY f.film_id, f.title, f.rating
ORDER BY number_of_rentals DESC
LIMIT 5;

-- SUBQUERY
SELECT 
    f.title, 
    (
        SELECT COUNT(*) 
        FROM public.rental r 
        INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id 
        WHERE i.film_id = f.film_id
    ) AS number_of_rentals,
    CASE f.rating
        WHEN 'G' THEN 'All ages'
        WHEN 'PG' THEN '7+'
        WHEN 'PG-13' THEN '13+'
        WHEN 'R' THEN '17+'
        WHEN 'NC-17' THEN '18+'
        ELSE 'Unknown'
    END AS expected_age
FROM public.film f
ORDER BY number_of_rentals DESC
LIMIT 5;

-- CTE
WITH MovieRentals AS (
    SELECT i.film_id, COUNT(r.rental_id) AS number_of_rentals
    FROM public.inventory i
    INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
    GROUP BY i.film_id
)
SELECT 
    f.title, 
    mr.number_of_rentals,
    CASE f.rating
        WHEN 'G' THEN 'All ages'
        WHEN 'PG' THEN '7+'
        WHEN 'PG-13' THEN '13+'
        WHEN 'R' THEN '17+'
        WHEN 'NC-17' THEN '18+'
        ELSE 'Unknown'
    END AS expected_age
FROM public.film f
-- assigning the calculated totals to films, excluding those with no rentals
INNER JOIN MovieRentals mr ON f.film_id = mr.film_id
ORDER BY mr.number_of_rentals DESC
LIMIT 5;


-- ============================================================================
-- Part 3: Which actors/actresses didn't act for a longer period of time than the others? 
--
-- ASSUMPTIONS & BUSINESS LOGIC:
-- 1. We provide two interpretations (V1: time since last movie, V2: max gap between sequential movies).
-- 2. V1 uses CURRENT_DATE to find the gap since their absolute last role.
-- 3. V2 uses complex self-joins to find gaps between consecutive release years during their career.
--
-- ADVANTAGES & DISADVANTAGES:
-- JOIN (V1): Pros: Extremely fast and straightforward. Cons: Only checks the final career gap.
-- SUBQUERY (V1): Pros: Keeps SELECT list clean. Cons: Correlated subquery checks max year row-by-row.
-- CTE (V2): Pros: The only readable way to calculate sequential career gaps without Window Functions (LEAD/LAG). Cons: Heavy query footprint due to self-joins.
--
-- PRODUCTION RECOMMENDATION:
-- For V1, the JOIN approach is best. For V2 (sequential gaps), I would normally use Window Functions (LAG) in production. Since they are restricted here, the CTE approach is the only logically maintainable way to structure sequential self-joins.
-- ============================================================================

-- V1: gap between the latest release_year and current year per each actor

-- JOIN
SELECT 
    a.first_name, 
    a.last_name, 
    (EXTRACT(YEAR FROM CURRENT_DATE) - MAX(f.release_year)) AS years_since_last_movie
FROM public.actor a
-- rejecting actors who have not appeared in any films
INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
INNER JOIN public.film f ON fa.film_id = f.film_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY years_since_last_movie DESC
LIMIT 5;

-- SUBQUERY
SELECT 
    a.first_name, 
    a.last_name,
    (EXTRACT(YEAR FROM CURRENT_DATE) - (
        SELECT MAX(f.release_year)
        FROM public.film_actor fa
        INNER JOIN public.film f ON fa.film_id = f.film_id
        WHERE fa.actor_id = a.actor_id
    )) AS years_since_last_movie
FROM public.actor a
ORDER BY years_since_last_movie DESC
LIMIT 5;

-- CTE
WITH ActorLatestMovie AS (
    SELECT fa.actor_id, MAX(f.release_year) AS latest_year
    FROM public.film_actor fa
    INNER JOIN public.film f ON fa.film_id = f.film_id
    GROUP BY fa.actor_id
)
SELECT 
    a.first_name, 
    a.last_name, 
    (EXTRACT(YEAR FROM CURRENT_DATE) - alm.latest_year) AS years_since_last_movie
FROM public.actor a
INNER JOIN ActorLatestMovie alm ON a.actor_id = alm.actor_id
ORDER BY years_since_last_movie DESC
LIMIT 5;


-- V2: gaps between sequential films per each actor

-- CTE
WITH ActorYears AS (
    -- unique years
    SELECT DISTINCT fa.actor_id, f.release_year
    FROM public.film_actor fa
    INNER JOIN public.film f ON fa.film_id = f.film_id
),
SequentialYears AS (
    -- ‘the next’ film for a given year by finding the smallest year greater than the current one
    SELECT 
        ay1.actor_id, 
        ay1.release_year AS current_year,
        MIN(ay2.release_year) AS next_year
    FROM ActorYears ay1
    -- product of the years, but only the later ones (excluding final year)
    INNER JOIN ActorYears ay2 ON ay1.actor_id = ay2.actor_id AND ay1.release_year < ay2.release_year
    GROUP BY ay1.actor_id, ay1.release_year
),
MaxGaps AS (
    -- maximum difference between the ‘next’ and the ‘current’ year
    SELECT actor_id, MAX(next_year - current_year) AS max_gap
    FROM SequentialYears
    GROUP BY actor_id
)
SELECT a.first_name, a.last_name, mg.max_gap
FROM public.actor a
INNER JOIN MaxGaps mg ON a.actor_id = mg.actor_id
ORDER BY mg.max_gap DESC
LIMIT 5;

-- SUBQUERY
SELECT a.first_name, a.last_name, mg.max_gap
FROM public.actor a
-- simulating temporary tables nested deeply
INNER JOIN (
    SELECT seq.actor_id, MAX(seq.next_year - seq.current_year) AS max_gap
    FROM (
        SELECT y1.actor_id, y1.release_year AS current_year, MIN(y2.release_year) AS next_year
        FROM (
            SELECT DISTINCT fa.actor_id, f.release_year
            FROM public.film_actor fa
            INNER JOIN public.film f ON fa.film_id = f.film_id
        ) y1
        INNER JOIN (
            SELECT DISTINCT fa.actor_id, f.release_year
            FROM public.film_actor fa
            INNER JOIN public.film f ON fa.film_id = f.film_id
        ) y2 ON y1.actor_id = y2.actor_id AND y1.release_year < y2.release_year
        GROUP BY y1.actor_id, y1.release_year
    ) seq
    GROUP BY seq.actor_id
) mg ON a.actor_id = mg.actor_id
ORDER BY mg.max_gap DESC
LIMIT 5;