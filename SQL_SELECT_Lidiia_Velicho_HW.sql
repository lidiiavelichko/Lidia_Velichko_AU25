-- SQL_SELECT_Homework.sql
-- Comprehensive SQL solutions for all tasks using CTE, Subquery, and JOIN approaches

-- =============================================
-- PART 1: BASIC SQL QUERIES
-- =============================================

-- Task 1.1: Animation movies between 2017-2019 with rate > 1, sorted alphabetically
-- Business logic: Filter by category, year range, rental rate for family-friendly promotion

-- CTE Solution
WITH animation_movies AS (
    SELECT 
        f.film_id,
        f.title,
        f.release_year,
        f.rental_rate,
        c.name AS category_name
    FROM public.film f
    INNER JOIN public.film_category fc ON f.film_id = fc.film_id
    INNER JOIN public.category c ON fc.category_id = c.category_id
    WHERE c.name = 'Animation'
      AND f.release_year BETWEEN 2017 AND 2019
      AND f.rental_rate > 1
)
SELECT 
    film_id,
    title,
    release_year,
    rental_rate,
    category_name
FROM animation_movies
ORDER BY title ASC;

-- Subquery Solution
SELECT 
    f.film_id,
    f.title,
    f.release_year,
    f.rental_rate,
    cat.name AS category_name
FROM public.film f
INNER JOIN public.film_category fc ON f.film_id = fc.film_id
INNER JOIN public.category cat ON fc.category_id = cat.category_id
WHERE cat.name = 'Animation'
  AND f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
  AND f.film_id IN (
      SELECT fc2.film_id 
      FROM public.film_category fc2
      INNER JOIN public.category c2 ON fc2.category_id = c2.category_id
      WHERE c2.name = 'Animation'
  )
ORDER BY f.title ASC;

-- JOIN Solution
SELECT 
    f.film_id,
    f.title,
    f.release_year,
    f.rental_rate,
    c.name AS category_name
FROM public.film f
INNER JOIN public.film_category fc ON f.film_id = fc.film_id
INNER JOIN public.category c ON fc.category_id = c.category_id
WHERE c.name = 'Animation'
  AND f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title ASC;

-- =============================================
-- Task 1.2: Store revenue after March 2017
-- Business logic: Sum payments from April 2017 onwards, group by store with combined address

-- CTE Solution
WITH store_revenue AS (
    SELECT 
        s.store_id,
        CONCAT(a.address, COALESCE(' ' || a.address2, '')) AS full_address,
        SUM(p.amount) AS total_revenue
    FROM public.payment p
    INNER JOIN public.rental r ON p.rental_id = r.rental_id
    INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
    INNER JOIN public.store s ON i.store_id = s.store_id
    INNER JOIN public.address a ON s.address_id = a.address_id
    WHERE p.payment_date >= '2017-04-01'
    GROUP BY s.store_id, a.address, a.address2
)
SELECT 
    store_id,
    full_address,
    total_revenue
FROM store_revenue
ORDER BY total_revenue DESC;

-- Subquery Solution
SELECT 
    store_info.store_id,
    store_info.full_address,
    (SELECT SUM(p.amount)
     FROM public.payment p
     INNER JOIN public.rental r ON p.rental_id = r.rental_id
     INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
     WHERE i.store_id = store_info.store_id
       AND p.payment_date >= '2017-04-01'
    ) AS total_revenue
FROM (
    SELECT 
        s.store_id,
        CONCAT(a.address, COALESCE(' ' || a.address2, '')) AS full_address
    FROM public.store s
    INNER JOIN public.address a ON s.address_id = a.address_id
) AS store_info
WHERE (SELECT SUM(p.amount)
       FROM public.payment p
       INNER JOIN public.rental r ON p.rental_id = r.rental_id
       INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
       WHERE i.store_id = store_info.store_id
         AND p.payment_date >= '2017-04-01'
      ) IS NOT NULL
ORDER BY total_revenue DESC;

-- JOIN Solution
SELECT 
    s.store_id,
    CONCAT(a.address, COALESCE(' ' || a.address2, '')) AS full_address,
    SUM(p.amount) AS total_revenue
FROM public.payment p
INNER JOIN public.rental r ON p.rental_id = r.rental_id
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.store s ON i.store_id = s.store_id
INNER JOIN public.address a ON s.address_id = a.address_id
WHERE p.payment_date >= '2017-04-01'
GROUP BY s.store_id, a.address, a.address2
ORDER BY total_revenue DESC;

-- =============================================
-- Task 1.3: Top-5 actors by number of movies released after 2015
-- Business logic: Count films per actor from 2015 onwards, rank by count for marketing promotion

-- CTE Solution
WITH actor_movie_counts AS (
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        COUNT(f.film_id) AS number_of_movies
    FROM public.actor a
    INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN public.film f ON fa.film_id = f.film_id
    WHERE f.release_year >= 2015
    GROUP BY a.actor_id, a.first_name, a.last_name
)
SELECT 
    first_name,
    last_name,
    number_of_movies
FROM actor_movie_counts
ORDER BY number_of_movies DESC
LIMIT 5;

-- Subquery Solution
SELECT 
    a.first_name,
    a.last_name,
    (SELECT COUNT(*) 
     FROM public.film_actor fa
     INNER JOIN public.film f ON fa.film_id = f.film_id
     WHERE fa.actor_id = a.actor_id 
       AND f.release_year >= 2015
    ) AS number_of_movies
FROM public.actor a
WHERE (SELECT COUNT(*) 
       FROM public.film_actor fa
       INNER JOIN public.film f ON fa.film_id = f.film_id
       WHERE fa.actor_id = a.actor_id 
         AND f.release_year >= 2015
      ) > 0
ORDER BY number_of_movies DESC
LIMIT 5;

-- JOIN Solution
SELECT 
    a.first_name,
    a.last_name,
    COUNT(f.film_id) AS number_of_movies
FROM public.actor a
INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
INNER JOIN public.film f ON fa.film_id = f.film_id
WHERE f.release_year >= 2015
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY number_of_movies DESC
LIMIT 5;

-- =============================================
-- Task 1.4: Count Drama, Travel, Documentary films per year
-- Business logic: Track three specific genres over time with NULL handling for marketing strategy planning

-- CTE Solution
WITH yearly_films AS (
    SELECT 
        f.release_year,
        c.name AS category_name,
        COUNT(f.film_id) AS movie_count
    FROM public.film f
    INNER JOIN public.film_category fc ON f.film_id = fc.film_id
    INNER JOIN public.category c ON fc.category_id = c.category_id
    WHERE c.name IN ('Drama', 'Travel', 'Documentary')
    GROUP BY f.release_year, c.name
),
all_years AS (
    SELECT DISTINCT release_year 
    FROM public.film
)
SELECT 
    ay.release_year,
    COALESCE(MAX(CASE WHEN yf.category_name = 'Drama' THEN yf.movie_count END), 0) AS number_of_drama_movies,
    COALESCE(MAX(CASE WHEN yf.category_name = 'Travel' THEN yf.movie_count END), 0) AS number_of_travel_movies,
    COALESCE(MAX(CASE WHEN yf.category_name = 'Documentary' THEN yf.movie_count END), 0) AS number_of_documentary_movies
FROM all_years ay
LEFT JOIN yearly_films yf ON ay.release_year = yf.release_year
GROUP BY ay.release_year
ORDER BY ay.release_year DESC;

-- Subquery Solution
SELECT 
    years.release_year,
    COALESCE((
        SELECT COUNT(*) 
        FROM public.film f
        INNER JOIN public.film_category fc ON f.film_id = fc.film_id
        INNER JOIN public.category c ON fc.category_id = c.category_id
        WHERE f.release_year = years.release_year 
          AND c.name = 'Drama'
    ), 0) AS number_of_drama_movies,
    COALESCE((
        SELECT COUNT(*) 
        FROM public.film f
        INNER JOIN public.film_category fc ON f.film_id = fc.film_id
        INNER JOIN public.category c ON fc.category_id = c.category_id
        WHERE f.release_year = years.release_year 
          AND c.name = 'Travel'
    ), 0) AS number_of_travel_movies,
    COALESCE((
        SELECT COUNT(*) 
        FROM public.film f
        INNER JOIN public.film_category fc ON f.film_id = fc.film_id
        INNER JOIN public.category c ON fc.category_id = c.category_id
        WHERE f.release_year = years.release_year 
          AND c.name = 'Documentary'
    ), 0) AS number_of_documentary_movies
FROM (
    SELECT DISTINCT release_year 
    FROM public.film
) AS years
ORDER BY years.release_year DESC;

-- JOIN Solution
SELECT 
    f.release_year,
    COUNT(CASE WHEN c.name = 'Drama' THEN 1 END) AS number_of_drama_movies,
    COUNT(CASE WHEN c.name = 'Travel' THEN 1 END) AS number_of_travel_movies,
    COUNT(CASE WHEN c.name = 'Documentary' THEN 1 END) AS number_of_documentary_movies
FROM public.film f
LEFT JOIN public.film_category fc ON f.film_id = fc.film_id
LEFT JOIN public.category c ON fc.category_id = c.category_id
GROUP BY f.release_year
ORDER BY f.release_year DESC;

-- =============================================
-- PART 2: ADVANCED SQL QUERIES
-- =============================================

-- Task 2.1: Top 3 revenue-generating employees in 2017
-- Business logic: Calculate total revenue per employee, determine last store worked, rank by revenue

-- CTE Solution
WITH employee_revenue AS (
    SELECT 
        p.staff_id,
        SUM(p.amount) AS total_revenue
    FROM public.payment p
    WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
    GROUP BY p.staff_id
),
last_store_worked AS (
    SELECT DISTINCT ON (p.staff_id)
        p.staff_id,
        i.store_id
    FROM public.payment p
    INNER JOIN public.rental r ON p.rental_id = r.rental_id
    INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
    WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
    ORDER BY p.staff_id, p.payment_date DESC
)
SELECT 
    s.staff_id,
    s.first_name,
    s.last_name,
    lsw.store_id AS last_store_worked,
    er.total_revenue
FROM employee_revenue er
INNER JOIN public.staff s ON er.staff_id = s.staff_id
INNER JOIN last_store_worked lsw ON er.staff_id = lsw.staff_id
ORDER BY er.total_revenue DESC
LIMIT 3;

-- Subquery Solution
SELECT 
    s.staff_id,
    s.first_name,
    s.last_name,
    (
        SELECT i.store_id
        FROM public.payment p
        INNER JOIN public.rental r ON p.rental_id = r.rental_id
        INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
        WHERE p.staff_id = s.staff_id
          AND EXTRACT(YEAR FROM p.payment_date) = 2017
        ORDER BY p.payment_date DESC
        LIMIT 1
    ) AS last_store_worked,
    (
        SELECT SUM(amount)
        FROM public.payment
        WHERE staff_id = s.staff_id
          AND EXTRACT(YEAR FROM payment_date) = 2017
    ) AS total_revenue
FROM public.staff s
WHERE EXISTS (
    SELECT 1
    FROM public.payment p
    WHERE p.staff_id = s.staff_id
      AND EXTRACT(YEAR FROM p.payment_date) = 2017
)
ORDER BY total_revenue DESC
LIMIT 3;

-- JOIN Solution
WITH revenue_data AS (
    SELECT 
        p.staff_id,
        SUM(p.amount) AS total_revenue
    FROM public.payment p
    WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
    GROUP BY p.staff_id
),
store_data AS (
    SELECT 
        p.staff_id,
        i.store_id,
        p.payment_date,
        ROW_NUMBER() OVER (PARTITION BY p.staff_id ORDER BY p.payment_date DESC) as rn
    FROM public.payment p
    INNER JOIN public.rental r ON p.rental_id = r.rental_id
    INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
    WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
)
SELECT 
    s.staff_id,
    s.first_name,
    s.last_name,
    sd.store_id AS last_store_worked,
    rd.total_revenue
FROM revenue_data rd
INNER JOIN public.staff s ON rd.staff_id = s.staff_id
INNER JOIN store_data sd ON rd.staff_id = sd.staff_id AND sd.rn = 1
ORDER BY rd.total_revenue DESC
LIMIT 3;

-- =============================================
-- Task 2.2: Top 5 movies by rental count with expected audience age from MPA ratings
-- Business logic: Count rentals per movie, map MPA ratings to age groups for marketing optimization

-- CTE Solution
WITH movie_rental_counts AS (
    SELECT 
        f.film_id,
        f.title,
        f.rating,
        COUNT(r.rental_id) AS rental_count
    FROM public.film f
    INNER JOIN public.inventory i ON f.film_id = i.film_id
    INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
    GROUP BY f.film_id, f.title, f.rating
),
mpa_age_groups AS (
    SELECT 
        mrc.film_id,
        mrc.title,
        mrc.rating,
        mrc.rental_count,
        CASE 
            WHEN mrc.rating = 'G' THEN 'All ages'
            WHEN mrc.rating = 'PG' THEN 'All ages (Parental Guidance)'
            WHEN mrc.rating = 'PG-13' THEN '13+ (Parents Strongly Cautioned)'
            WHEN mrc.rating = 'R' THEN '17+ (Restricted)'
            WHEN mrc.rating = 'NC-17' THEN 'Adults Only (18+)'
            ELSE 'Rating not specified'
        END AS expected_audience_age
    FROM movie_rental_counts mrc
)
SELECT 
    title,
    rating,
    rental_count,
    expected_audience_age
FROM mpa_age_groups
ORDER BY rental_count DESC
LIMIT 5;

-- Subquery Solution  ?
SELECT 
    film_data.title,
    film_data.rating,
    film_data.rental_count,
    CASE 
        WHEN film_data.rating = 'G' THEN 'All ages'
        WHEN film_data.rating = 'PG' THEN 'All ages (Parental Guidance)'
        WHEN film_data.rating = 'PG-13' THEN '13+ (Parents Strongly Cautioned)'
        WHEN film_data.rating = 'R' THEN '17+ (Restricted)'
        WHEN film_data.rating = 'NC-17' THEN 'Adults Only (18+)'
        ELSE 'Rating not specified'
    END AS expected_audience_age
FROM (
    SELECT 
        f.film_id,
        f.title,
        f.rating,
        (SELECT COUNT(*) 
         FROM public.rental r
         INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
         WHERE i.film_id = f.film_id
        ) AS rental_count
    FROM public.film f
) AS film_data
WHERE film_data.rental_count > 0
ORDER BY film_data.rental_count DESC
LIMIT 5;

-- JOIN Solution
SELECT 
    f.title,
    f.rating,
    COUNT(r.rental_id) AS rental_count,
    CASE 
        WHEN f.rating = 'G' THEN 'All ages'
        WHEN f.rating = 'PG' THEN 'All ages (Parental Guidance)'
        WHEN f.rating = 'PG-13' THEN '13+ (Parents Strongly Cautioned)'
        WHEN f.rating = 'R' THEN '17+ (Restricted)'
        WHEN f.rating = 'NC-17' THEN 'Adults Only (18+)'
        ELSE 'Rating not specified'
    END AS expected_audience_age
FROM public.film f
INNER JOIN public.inventory i ON f.film_id = i.film_id
INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
GROUP BY f.film_id, f.title, f.rating
ORDER BY rental_count DESC
LIMIT 5;

-- =============================================
-- PART 3: ACTOR INACTIVITY ANALYSIS
-- =============================================

-- VERSION 1: Gap between latest release_year and current year per actor

-- CTE Solution for V1
WITH actor_last_films AS (
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        MAX(f.release_year) AS last_release_year
    FROM public.actor a
    INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN public.film f ON fa.film_id = f.film_id
    GROUP BY a.actor_id, a.first_name, a.last_name
)
SELECT 
    actor_id,
    first_name,
    last_name,
    last_release_year,
    (EXTRACT(YEAR FROM CURRENT_DATE) - last_release_year) AS years_inactive
FROM actor_last_films
ORDER BY years_inactive DESC
LIMIT 10;

-- Subquery Solution for V1
SELECT 
    a.actor_id,
    a.first_name,
    a.last_name,
    (
        SELECT MAX(f.release_year)
        FROM public.film f
        INNER JOIN public.film_actor fa ON f.film_id = fa.film_id
        WHERE fa.actor_id = a.actor_id
    ) AS last_release_year,
    (EXTRACT(YEAR FROM CURRENT_DATE) - (
        SELECT MAX(f.release_year)
        FROM public.film f
        INNER JOIN public.film_actor fa ON f.film_id = fa.film_id
        WHERE fa.actor_id = a.actor_id
    )) AS years_inactive
FROM public.actor a
WHERE EXISTS (
    SELECT 1
    FROM public.film_actor fa
    INNER JOIN public.film f ON fa.film_id = f.film_id
    WHERE fa.actor_id = a.actor_id
)
ORDER BY years_inactive DESC
LIMIT 10;

-- JOIN Solution for V1
SELECT 
    a.actor_id,
    a.first_name,
    a.last_name,
    MAX(f.release_year) AS last_release_year,
    (EXTRACT(YEAR FROM CURRENT_DATE) - MAX(f.release_year)) AS years_inactive
FROM public.actor a
INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
INNER JOIN public.film f ON fa.film_id = f.film_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY years_inactive DESC
LIMIT 10;

-- VERSION 2: Gaps between sequential films per actor

-- CTE Solution for V2 (using window functions)
WITH actor_films_ordered AS (
    SELECT 
        fa.actor_id,
        f.film_id,
        f.release_year,
        LAG(f.release_year) OVER (PARTITION BY fa.actor_id ORDER BY f.release_year) AS prev_release_year
    FROM public.film_actor fa
    INNER JOIN public.film f ON fa.film_id = f.film_id
),
actor_gaps AS (
    SELECT 
        actor_id,
        release_year,
        prev_release_year,
        (release_year - prev_release_year) AS year_gap
    FROM actor_films_ordered
    WHERE prev_release_year IS NOT NULL
),
max_gaps AS (
    SELECT 
        actor_id,
        MAX(year_gap) AS max_gap_between_films
    FROM actor_gaps
    GROUP BY actor_id
)
SELECT 
    a.actor_id,
    a.first_name,
    a.last_name,
    mg.max_gap_between_films
FROM public.actor a
INNER JOIN max_gaps mg ON a.actor_id = mg.actor_id
ORDER BY mg.max_gap_between_films DESC
LIMIT 10;

-- Subquery Solution for V2 (without window functions)
SELECT 
    a.actor_id,
    a.first_name,
    a.last_name,
    (
        SELECT MAX(f2.release_year - f1.release_year)
        FROM public.film_actor fa1
        INNER JOIN public.film f1 ON fa1.film_id = f1.film_id
        INNER JOIN public.film_actor fa2 ON fa1.actor_id = fa2.actor_id
        INNER JOIN public.film f2 ON fa2.film_id = f2.film_id
        WHERE fa1.actor_id = a.actor_id
          AND f2.release_year > f1.release_year
          AND NOT EXISTS (
              SELECT 1
              FROM public.film_actor fa3
              INNER JOIN public.film f3 ON fa3.film_id = f3.film_id
              WHERE fa3.actor_id = a.actor_id
                AND f3.release_year > f1.release_year
                AND f3.release_year < f2.release_year
          )
    ) AS max_gap_between_films
FROM public.actor a
WHERE EXISTS (
    SELECT 1
    FROM public.film_actor fa
    INNER JOIN public.film f ON fa.film_id = f.film_id
    WHERE fa.actor_id = a.actor_id
    HAVING COUNT(DISTINCT f.release_year) > 1
)
ORDER BY max_gap_between_films DESC
LIMIT 10;

-- JOIN Solution for V2 (using self-join)
WITH actor_film_years AS (
    SELECT DISTINCT
        fa.actor_id,
        f.release_year
    FROM public.film_actor fa
    INNER JOIN public.film f ON fa.film_id = f.film_id
)
SELECT 
    a.actor_id,
    a.first_name,
    a.last_name,
    MAX(afy2.release_year - afy1.release_year) AS max_gap_between_films
FROM public.actor a
INNER JOIN actor_film_years afy1 ON a.actor_id = afy1.actor_id
INNER JOIN actor_film_years afy2 ON a.actor_id = afy2.actor_id
WHERE afy2.release_year > afy1.release_year
  AND NOT EXISTS (
      SELECT 1
      FROM actor_film_years afy3
      WHERE afy3.actor_id = a.actor_id
        AND afy3.release_year > afy1.release_year
        AND afy3.release_year < afy2.release_year
  )
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY max_gap_between_films DESC
LIMIT 10;

/* 
Summary: CTE vs Subquery vs JOIN

CTE (WITH):
- Pros: Very readable for multi-step logic; good for structuring complex queries; easy to reuse intermediate results.
- Cons: Sometimes unnecessary for simple tasks; in some DBs/versions can be an optimization barrier and use extra memory.

Subqueries:
- Pros: Good for local calculations per row (e.g. counts, existence checks); EXISTS/IN are very readable.
- Cons: Correlated subqueries may be executed many times (N+1 pattern) and become slow on large data; logic can be duplicated and harder to maintain.

JOIN:
- Pros: Usually the best performance; optimizer understands JOINs well; aggregation with GROUP BY is efficient and scalable.
- Cons: Queries with many JOINs can become hard to read; easier to introduce duplicate rows if you dont control joins and grouping carefully.
*/
