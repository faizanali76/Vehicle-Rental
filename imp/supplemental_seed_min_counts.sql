-- =============================================================
-- VEHICLE RENTAL SYSTEM - SUPPLEMENTAL SEED DATA
-- Purpose: Run this on an already-created Supabase database if
-- schema_and_seed.sql was executed before category and branch
-- seed counts were increased to 10 records.
-- =============================================================

INSERT INTO category (category_id, name, description, base_daily_rate) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000007', 'Mini SUV',   'Compact crossovers for city rentals',    48.00),
  ('aaaaaaaa-0000-0000-0000-000000000008', 'Executive',  'Business class premium sedans',          80.00),
  ('aaaaaaaa-0000-0000-0000-000000000009', 'Electric',   'Battery electric vehicles',              70.00),
  ('aaaaaaaa-0000-0000-0000-000000000010', 'Commercial', 'High-capacity business utility vehicles', 65.00)
ON CONFLICT (category_id) DO NOTHING;

INSERT INTO branch (branch_id, name, address, city, phone, email) VALUES
  ('cccccccc-0000-0000-0000-000000000006','University Branch','12 Campus Road',       'Lahore',    '+92-42-6678901', 'university@vrental.com'),
  ('cccccccc-0000-0000-0000-000000000007','Seaview Branch',   '88 Seaview Avenue',    'Karachi',   '+92-21-6678902', 'seaview@vrental.com'),
  ('cccccccc-0000-0000-0000-000000000008','Blue Area Branch', '44 Jinnah Avenue',     'Islamabad', '+92-51-6678903', 'bluearea@vrental.com'),
  ('cccccccc-0000-0000-0000-000000000009','Cantt Branch',     '19 Mall Road Cantt',   'Rawalpindi','+92-51-6678904', 'cantt@vrental.com'),
  ('cccccccc-0000-0000-0000-000000000010','Bahria Branch',    '27 Bahria Town',       'Lahore',    '+92-42-6678905', 'bahria@vrental.com')
ON CONFLICT (branch_id) DO NOTHING;

-- Verification query for screenshots.
SELECT 'category' AS table_name, COUNT(*) AS row_count FROM category
UNION ALL
SELECT 'branch', COUNT(*) FROM branch
ORDER BY table_name;
