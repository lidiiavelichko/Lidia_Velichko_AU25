-- Step 1: Add top-3 favorite movies to film table
BEGIN;

WITH lang_id AS (
    SELECT language_id FROM public.language WHERE name = 'English' LIMIT 1
),
new_films AS (
    SELECT 
        title,
        description,
        release_year,
        (SELECT language_id FROM lang_id) as language_id,
        rental_duration,
        rental_rate,
        length,
        replacement_cost,
        rating,
        special_features
    FROM (VALUES 
        ('Inception', 'A thief who steals corporate secrets through dream-sharing technology', 2010, 1, 4.99, 148, 20.99, 'PG-13'::mpaa_rating, '{"Behind the Scenes","Commentaries"}'),
        ('The Dark Knight', 'Batman faces the Joker, a criminal mastermind seeking to undermine society', 2008, 2, 9.99, 152, 25.99, 'PG-13'::mpaa_rating, '{"Behind the Scenes","Deleted Scenes"}'),
        ('Pulp Fiction', 'The lives of two mob hitmen, a boxer, and a gangster intertwine in four tales of violence', 1994, 3, 19.99, 154, 22.99, 'R'::mpaa_rating, '{"Commentaries","Trailers"}')
    ) AS films(title, description, release_year, rental_duration, rental_rate, length, replacement_cost, rating, special_features)
)
INSERT INTO public.film (
    title, description, release_year, language_id, 
    rental_duration, rental_rate, length, replacement_cost, 
    rating, special_features, last_update
)
SELECT 
    nf.title,
    nf.description,
    nf.release_year,
    nf.language_id,
    nf.rental_duration,
    nf.rental_rate,
    nf.length,
    nf.replacement_cost,
    nf.rating,
    nf.special_features,
    CURRENT_DATE
FROM new_films nf
WHERE NOT EXISTS (
    SELECT 1 FROM public.film f WHERE f.title = nf.title
)
RETURNING film_id, title;

COMMIT;


-- Step 2: Add actors and link them to films
BEGIN;

WITH new_actors AS (
    INSERT INTO public.actor (first_name, last_name, last_update)
    SELECT first_name, last_name, CURRENT_DATE
    FROM (VALUES 
        ('Leonardo', 'DiCaprio'),
        ('Joseph', 'Gordon-Levitt'),
        ('Ellen', 'Page'),
        ('Christian', 'Bale'),
        ('Heath', 'Ledger'),
        ('Aaron', 'Eckhart'),
        ('John', 'Travolta'),
        ('Samuel', 'L. Jackson'),
        ('Uma', 'Thurman')
    ) AS actor_data(first_name, last_name)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.actor a 
        WHERE a.first_name = actor_data.first_name AND a.last_name = actor_data.last_name
    )
    RETURNING actor_id, first_name, last_name
),
film_data AS (
    SELECT film_id, title FROM public.film 
    WHERE title IN ('Inception', 'The Dark Knight', 'Pulp Fiction')
)
INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT 
    na.actor_id,
    fd.film_id,
    CURRENT_DATE
FROM new_actors na
CROSS JOIN film_data fd
WHERE 
    (na.first_name = 'Leonardo' AND na.last_name = 'DiCaprio' AND fd.title = 'Inception') OR
    (na.first_name = 'Joseph' AND na.last_name = 'Gordon-Levitt' AND fd.title = 'Inception') OR
    (na.first_name = 'Ellen' AND na.last_name = 'Page' AND fd.title = 'Inception') OR
    (na.first_name = 'Christian' AND na.last_name = 'Bale' AND fd.title = 'The Dark Knight') OR
    (na.first_name = 'Heath' AND na.last_name = 'Ledger' AND fd.title = 'The Dark Knight') OR
    (na.first_name = 'Aaron' AND na.last_name = 'Eckhart' AND fd.title = 'The Dark Knight') OR
    (na.first_name = 'John' AND na.last_name = 'Travolta' AND fd.title = 'Pulp Fiction') OR
    (na.first_name = 'Samuel' AND na.last_name = 'Jackson' AND fd.title = 'Pulp Fiction') OR
    (na.first_name = 'Uma' AND na.last_name = 'Thurman' AND fd.title = 'Pulp Fiction')
ON CONFLICT (actor_id, film_id) DO NOTHING
RETURNING actor_id, film_id;

COMMIT;

BEGIN;

INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT 
    f.film_id,
    1 as store_id,
    CURRENT_DATE
FROM public.film f
WHERE f.title IN ('Inception', 'The Dark Knight', 'Pulp Fiction')
AND NOT EXISTS (
    SELECT 1 FROM public.inventory i 
    WHERE i.film_id = f.film_id AND i.store_id = 1
)
RETURNING inventory_id, film_id, store_id;

COMMIT;


-- Step 4: Update customer record with personal data
BEGIN;

WITH qualified_customer AS (
    SELECT c.customer_id
    FROM public.customer c
    WHERE (
        SELECT COUNT(*) FROM public.rental r 
        WHERE r.customer_id = c.customer_id
    ) >= 43
    AND (
        SELECT COUNT(*) FROM public.payment p 
        WHERE p.customer_id = c.customer_id
    ) >= 43
    LIMIT 1
),
valid_address AS (
    SELECT address_id FROM public.address LIMIT 1
)
UPDATE public.customer 
SET 
    first_name = 'Alex',
    last_name = 'Johnson',
    email = 'alex.johnson@email.com',
    address_id = (SELECT address_id FROM valid_address),
    last_update = CURRENT_DATE
WHERE customer_id = (SELECT customer_id FROM qualified_customer)
RETURNING customer_id, first_name, last_name, email;

COMMIT;


-- Step 5: Remove related records except Customer and Inventory
BEGIN;

SELECT 'Rentals to delete:', COUNT(*) 
FROM public.rental r 
JOIN public.customer c ON r.customer_id = c.customer_id 
WHERE c.first_name = 'Alex' AND c.last_name = 'Johnson';

SELECT 'Payments to delete:', COUNT(*) 
FROM public.payment p 
JOIN public.customer c ON p.customer_id = c.customer_id 
WHERE c.first_name = 'Alex' AND c.last_name = 'Johnson';

DELETE FROM public.payment 
WHERE customer_id IN (
    SELECT customer_id FROM public.customer 
    WHERE first_name = 'Alex' AND last_name = 'Johnson'
);

DELETE FROM public.rental 
WHERE customer_id IN (
    SELECT customer_id FROM public.customer 
    WHERE first_name = 'Alex' AND last_name = 'Johnson'
);

COMMIT;

-- Step 6: Rent favorite movies and make payments
BEGIN;

WITH my_customer AS (
    SELECT customer_id FROM public.customer 
    WHERE first_name = 'Alex' AND last_name = 'Johnson'
    LIMIT 1
),
film_inventory AS (
    SELECT i.inventory_id, f.film_id, f.title, f.rental_rate
    FROM public.inventory i
    JOIN public.film f ON i.film_id = f.film_id
    WHERE f.title IN ('Inception', 'The Dark Knight', 'Pulp Fiction')
    AND i.store_id = 1
    AND NOT EXISTS (
        SELECT 1 FROM public.rental r 
        WHERE r.inventory_id = i.inventory_id 
        AND r.return_date IS NULL
    )
    LIMIT 3 
),
new_rentals AS (
    INSERT INTO public.rental (
        rental_date, inventory_id, customer_id, 
        staff_id, last_update
    )
    SELECT 
        CURRENT_TIMESTAMP,
        fi.inventory_id,
        mc.customer_id,
        1 as staff_id,
        CURRENT_DATE
    FROM my_customer mc
    CROSS JOIN film_inventory fi
    RETURNING rental_id, inventory_id, customer_id
)
INSERT INTO public.payment (
    customer_id, staff_id, rental_id, amount, payment_date, last_update
)
SELECT 
    nr.customer_id,
    1 as staff_id,
    nr.rental_id,
    fi.rental_rate as amount,
    '2017-03-15 14:30:00'::timestamp as payment_date,
    CURRENT_DATE
FROM new_rentals nr
JOIN film_inventory fi ON nr.inventory_id = fi.inventory_id
RETURNING payment_id, rental_id, amount;

COMMIT;