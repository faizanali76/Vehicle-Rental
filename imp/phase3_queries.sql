-- =============================================================
-- VEHICLE RENTAL SYSTEM - PHASE III ADVANCED SQL OPERATIONS
-- Database: Supabase PostgreSQL
-- Purpose: Joins, set operations, subqueries, and performance proof
-- =============================================================

-- 1. INNER JOIN: vehicles with their model, category, and branch.
SELECT
    v.license_plate,
    m.make,
    m.model_name,
    c.name AS category,
    b.name AS branch,
    b.city,
    v.daily_rate,
    v.status
FROM vehicle v
INNER JOIN model m ON v.model_id = m.model_id
INNER JOIN category c ON m.category_id = c.category_id
INNER JOIN branch b ON v.branch_id = b.branch_id
ORDER BY b.city, v.license_plate;

-- 2. LEFT OUTER JOIN: every customer, including customers with no contracts.
SELECT
    cu.customer_id,
    cu.first_name || ' ' || cu.last_name AS customer_name,
    cu.email,
    COUNT(ct.contract_id) AS total_contracts,
    COALESCE(SUM(ct.total_amount), 0) AS total_spent
FROM customer cu
LEFT JOIN contract ct ON cu.customer_id = ct.customer_id
GROUP BY cu.customer_id, cu.first_name, cu.last_name, cu.email
ORDER BY total_spent DESC;

-- 3. RIGHT OUTER JOIN: every branch, including branches with no closed contracts.
SELECT
    b.branch_id,
    b.name AS branch_name,
    b.city,
    ct.contract_id,
    ct.status,
    ct.total_amount
FROM contract ct
RIGHT JOIN branch b ON ct.pickup_branch_id = b.branch_id
ORDER BY b.name, ct.created_at DESC;

-- 4. FULL OUTER JOIN: vehicles and their maintenance records.
SELECT
    v.vehicle_id,
    v.license_plate,
    mt.maintenance_id,
    mt.maintenance_type,
    mt.status AS maintenance_status,
    mt.cost,
    mt.start_date
FROM vehicle v
FULL OUTER JOIN maintenance mt ON v.vehicle_id = mt.vehicle_id
ORDER BY v.license_plate, mt.start_date DESC;

-- 5. UNION: all contact emails across customers and staff.
SELECT email, 'Customer' AS contact_type FROM customer
UNION
SELECT email, 'Staff' AS contact_type FROM staff
ORDER BY contact_type, email;

-- 6. INTERSECT: vehicles that have both damage reports and maintenance records.
SELECT vehicle_id FROM damage_report
INTERSECT
SELECT vehicle_id FROM maintenance;

-- 7. EXCEPT: PostgreSQL equivalent of Oracle MINUS.
-- Vehicles that have never appeared in a contract.
SELECT vehicle_id, license_plate FROM vehicle
EXCEPT
SELECT v.vehicle_id, v.license_plate
FROM vehicle v
INNER JOIN contract ct ON v.vehicle_id = ct.vehicle_id;

-- 8. Non-correlated subquery: customers who spent more than average closed contract value.
SELECT
    customer_name,
    email,
    total_rentals,
    total_spent
FROM vw_customer_history
WHERE total_spent > (
    SELECT AVG(total_amount)
    FROM contract
    WHERE status = 'Closed'
)
ORDER BY total_spent DESC;

-- 9. Correlated subquery: vehicles priced above their category average.
SELECT
    v.license_plate,
    v.daily_rate,
    m.make,
    m.model_name,
    c.name AS category
FROM vehicle v
JOIN model m ON v.model_id = m.model_id
JOIN category c ON m.category_id = c.category_id
WHERE v.daily_rate > (
    SELECT AVG(v2.daily_rate)
    FROM vehicle v2
    JOIN model m2 ON v2.model_id = m2.model_id
    WHERE m2.category_id = m.category_id
)
ORDER BY c.name, v.daily_rate DESC;

-- 10. EXISTS: branches that currently have at least one active contract.
SELECT b.branch_id, b.name, b.city
FROM branch b
WHERE EXISTS (
    SELECT 1
    FROM contract ct
    WHERE ct.pickup_branch_id = b.branch_id
      AND ct.status = 'Active'
);

-- 11. NOT EXISTS: vehicles with no reservations.
SELECT v.vehicle_id, v.license_plate, v.status
FROM vehicle v
WHERE NOT EXISTS (
    SELECT 1
    FROM reservation r
    WHERE r.vehicle_id = v.vehicle_id
)
ORDER BY v.license_plate;

-- 12. Complex business query: revenue by branch and category.
SELECT
    b.name AS branch_name,
    c.name AS category,
    COUNT(ct.contract_id) AS closed_contracts,
    COALESCE(SUM(ct.total_amount), 0) AS revenue
FROM branch b
JOIN contract ct ON ct.pickup_branch_id = b.branch_id
JOIN vehicle v ON ct.vehicle_id = v.vehicle_id
JOIN model m ON v.model_id = m.model_id
JOIN category c ON m.category_id = c.category_id
WHERE ct.status = 'Closed'
GROUP BY b.name, c.name
ORDER BY b.name, revenue DESC;

-- 13. Performance proof: indexes created in schema_and_seed.sql.
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
      'idx_vehicle_status',
      'idx_vehicle_branch',
      'idx_reservation_dates',
      'idx_contract_dates',
      'idx_payment_contract',
      'idx_audit_log_table'
  )
ORDER BY indexname;

-- 14. Optional EXPLAIN proof for report screenshots.
EXPLAIN ANALYZE
SELECT *
FROM vehicle
WHERE status = 'Available'
  AND branch_id = 'cccccccc-0000-0000-0000-000000000001';
