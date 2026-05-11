-- =============================================================
--  VEHICLE RENTAL SYSTEM — SUPABASE MIGRATION SCRIPT
--  Database: PostgreSQL (Supabase)
--  Covers: DDL, DCL, Views, Triggers, Functions, Seed Data
-- =============================================================

-- ─────────────────────────────────────────────
-- SECTION 0: EXTENSIONS
-- ─────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─────────────────────────────────────────────
-- SECTION 1: TABLE DEFINITIONS (DDL)
-- ─────────────────────────────────────────────

-- 1.1 CATEGORY — Vehicle classification tiers
CREATE TABLE IF NOT EXISTS category (
    category_id   UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    name          VARCHAR(50)  NOT NULL UNIQUE,
    description   TEXT,
    base_daily_rate DECIMAL(10,2) NOT NULL CHECK (base_daily_rate > 0),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 1.2 MODEL — Manufacturer / make / model info
CREATE TABLE IF NOT EXISTS model (
    model_id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id       UUID        NOT NULL REFERENCES category(category_id) ON DELETE RESTRICT,
    make              VARCHAR(50) NOT NULL,
    model_name        VARCHAR(50) NOT NULL,
    year              SMALLINT    NOT NULL CHECK (year BETWEEN 1990 AND 2030),
    passenger_capacity SMALLINT   NOT NULL CHECK (passenger_capacity > 0 AND passenger_capacity <= 20),
    fuel_type         VARCHAR(20) NOT NULL CHECK (fuel_type IN ('Petrol','Diesel','Electric','Hybrid')),
    transmission      VARCHAR(20) NOT NULL CHECK (transmission IN ('Manual','Automatic')),
    UNIQUE (make, model_name, year)
);

-- 1.3 BRANCH — Physical rental locations
CREATE TABLE IF NOT EXISTS branch (
    branch_id   UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(100) NOT NULL,
    address     TEXT         NOT NULL,
    city        VARCHAR(50)  NOT NULL,
    phone       VARCHAR(20)  NOT NULL,
    email       VARCHAR(100),
    manager_id  UUID,                    -- FK added after staff table
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 1.4 STAFF — Employees across all branches
CREATE TABLE IF NOT EXISTS staff (
    staff_id    UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id   UUID         NOT NULL REFERENCES branch(branch_id) ON DELETE RESTRICT,
    first_name  VARCHAR(50)  NOT NULL,
    last_name   VARCHAR(50)  NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE,
    phone       VARCHAR(20)  NOT NULL,
    role        VARCHAR(30)  NOT NULL CHECK (role IN ('Manager','Agent','Mechanic','Cleaner')),
    hire_date   DATE         NOT NULL,
    salary      DECIMAL(10,2) NOT NULL CHECK (salary > 0),
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Link manager_id back to staff (deferred FK)
ALTER TABLE branch
    ADD CONSTRAINT fk_branch_manager
    FOREIGN KEY (manager_id) REFERENCES staff(staff_id) ON DELETE SET NULL;

-- 1.5 VEHICLE — Individual physical vehicles
CREATE TABLE IF NOT EXISTS vehicle (
    vehicle_id    UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_id      UUID         NOT NULL REFERENCES model(model_id) ON DELETE RESTRICT,
    branch_id     UUID         NOT NULL REFERENCES branch(branch_id) ON DELETE RESTRICT,
    license_plate VARCHAR(20)  NOT NULL UNIQUE,
    vin           VARCHAR(17)  NOT NULL UNIQUE,
    color         VARCHAR(30)  NOT NULL,
    mileage       INTEGER      NOT NULL DEFAULT 0 CHECK (mileage >= 0),
    status        VARCHAR(20)  NOT NULL DEFAULT 'Available'
                               CHECK (status IN ('Available','Rented','Maintenance','Retired')),
    daily_rate    DECIMAL(10,2) NOT NULL CHECK (daily_rate > 0),
    purchase_date DATE         NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 1.6 INSURANCE — Policy per vehicle
CREATE TABLE IF NOT EXISTS insurance (
    insurance_id   UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id     UUID         NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
    provider       VARCHAR(100) NOT NULL,
    policy_number  VARCHAR(50)  NOT NULL UNIQUE,
    coverage_type  VARCHAR(30)  NOT NULL CHECK (coverage_type IN ('Basic','Comprehensive','Third-Party')),
    start_date     DATE         NOT NULL,
    end_date       DATE         NOT NULL,
    premium_amount DECIMAL(10,2) NOT NULL CHECK (premium_amount > 0),
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_insurance_dates CHECK (end_date > start_date)
);

-- 1.7 CUSTOMER — Registered rental customers
CREATE TABLE IF NOT EXISTS customer (
    customer_id       UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    first_name        VARCHAR(50)  NOT NULL,
    last_name         VARCHAR(50)  NOT NULL,
    email             VARCHAR(100) NOT NULL UNIQUE,
    phone             VARCHAR(20)  NOT NULL,
    address           TEXT         NOT NULL,
    driver_license_no VARCHAR(30)  NOT NULL UNIQUE,
    license_expiry    DATE         NOT NULL,
    date_of_birth     DATE         NOT NULL,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_min_age CHECK (date_of_birth < CURRENT_DATE - INTERVAL '18 years')
);

-- 1.8 RESERVATION — Pre-booking before contract
CREATE TABLE IF NOT EXISTS reservation (
    reservation_id  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id     UUID        NOT NULL REFERENCES customer(customer_id) ON DELETE RESTRICT,
    vehicle_id      UUID        NOT NULL REFERENCES vehicle(vehicle_id)  ON DELETE RESTRICT,
    pickup_branch_id UUID       NOT NULL REFERENCES branch(branch_id),
    return_branch_id UUID       NOT NULL REFERENCES branch(branch_id),
    pickup_date     TIMESTAMPTZ NOT NULL,
    return_date     TIMESTAMPTZ NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'Pending'
                                CHECK (status IN ('Pending','Confirmed','Cancelled','Completed')),
    total_amount    DECIMAL(10,2) CHECK (total_amount >= 0),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_reservation_dates CHECK (return_date > pickup_date)
);

-- 1.9 CONTRACT — Actual signed rental agreement
CREATE TABLE IF NOT EXISTS contract (
    contract_id        UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    reservation_id     UUID         REFERENCES reservation(reservation_id) ON DELETE SET NULL,
    customer_id        UUID         NOT NULL REFERENCES customer(customer_id) ON DELETE RESTRICT,
    vehicle_id         UUID         NOT NULL REFERENCES vehicle(vehicle_id)  ON DELETE RESTRICT,
    staff_id           UUID         NOT NULL REFERENCES staff(staff_id)      ON DELETE RESTRICT,
    pickup_branch_id   UUID         NOT NULL REFERENCES branch(branch_id),
    return_branch_id   UUID         NOT NULL REFERENCES branch(branch_id),
    actual_pickup_date TIMESTAMPTZ  NOT NULL,
    actual_return_date TIMESTAMPTZ,
    agreed_daily_rate  DECIMAL(10,2) NOT NULL CHECK (agreed_daily_rate > 0),
    base_amount        DECIMAL(10,2) CHECK (base_amount >= 0),
    additional_charges DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (additional_charges >= 0),
    total_amount       DECIMAL(10,2) CHECK (total_amount >= 0),
    status             VARCHAR(20)  NOT NULL DEFAULT 'Active'
                                    CHECK (status IN ('Active','Closed','Disputed')),
    notes              TEXT,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 1.10 PAYMENT — Payments linked to contracts
CREATE TABLE IF NOT EXISTS payment (
    payment_id     UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    contract_id    UUID         NOT NULL REFERENCES contract(contract_id) ON DELETE RESTRICT,
    amount         DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    payment_date   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    payment_method VARCHAR(30)  NOT NULL CHECK (payment_method IN ('Cash','Credit Card','Debit Card','Bank Transfer','Online')),
    status         VARCHAR(20)  NOT NULL DEFAULT 'Completed'
                                CHECK (status IN ('Pending','Completed','Refunded','Failed')),
    transaction_id VARCHAR(100) UNIQUE,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 1.11 DAMAGE_REPORT — Damage found on return
CREATE TABLE IF NOT EXISTS damage_report (
    damage_id    UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id   UUID        NOT NULL REFERENCES vehicle(vehicle_id)  ON DELETE RESTRICT,
    contract_id  UUID        REFERENCES contract(contract_id)         ON DELETE SET NULL,
    reported_by  UUID        NOT NULL REFERENCES staff(staff_id)      ON DELETE RESTRICT,
    report_date  DATE        NOT NULL DEFAULT CURRENT_DATE,
    description  TEXT        NOT NULL,
    severity     VARCHAR(20) NOT NULL CHECK (severity IN ('Minor','Moderate','Severe')),
    repair_cost  DECIMAL(10,2) CHECK (repair_cost >= 0),
    status       VARCHAR(20) NOT NULL DEFAULT 'Reported'
                             CHECK (status IN ('Reported','Under Repair','Resolved')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 1.12 MAINTENANCE — Scheduled/actual vehicle servicing
CREATE TABLE IF NOT EXISTS maintenance (
    maintenance_id   UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id       UUID        NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE RESTRICT,
    branch_id        UUID        NOT NULL REFERENCES branch(branch_id),
    staff_id         UUID        REFERENCES staff(staff_id) ON DELETE SET NULL,
    maintenance_type VARCHAR(50) NOT NULL CHECK (maintenance_type IN
                      ('Oil Change','Tire Rotation','Brake Service','Engine Check',
                       'Full Service','Damage Repair','Other')),
    start_date       DATE        NOT NULL,
    end_date         DATE,
    cost             DECIMAL(10,2) CHECK (cost >= 0),
    description      TEXT,
    status           VARCHAR(20) NOT NULL DEFAULT 'Scheduled'
                                 CHECK (status IN ('Scheduled','In Progress','Completed','Cancelled')),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_maintenance_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- 1.13 AUDIT_LOG — Auto-populated by triggers
CREATE TABLE IF NOT EXISTS audit_log (
    log_id      UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name  VARCHAR(50) NOT NULL,
    operation   VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
    record_id   UUID        NOT NULL,
    old_data    JSONB,
    new_data    JSONB,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by  TEXT        NOT NULL DEFAULT current_user
);

-- ─────────────────────────────────────────────
-- SECTION 2: INDEXES (Performance Optimization)
-- ─────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_vehicle_status        ON vehicle(status);
CREATE INDEX IF NOT EXISTS idx_vehicle_branch        ON vehicle(branch_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_model         ON vehicle(model_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_plate         ON vehicle(license_plate);

CREATE INDEX IF NOT EXISTS idx_reservation_customer  ON reservation(customer_id);
CREATE INDEX IF NOT EXISTS idx_reservation_vehicle   ON reservation(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_reservation_dates     ON reservation(pickup_date, return_date);
CREATE INDEX IF NOT EXISTS idx_reservation_status    ON reservation(status);

CREATE INDEX IF NOT EXISTS idx_contract_customer     ON contract(customer_id);
CREATE INDEX IF NOT EXISTS idx_contract_vehicle      ON contract(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_contract_status       ON contract(status);
CREATE INDEX IF NOT EXISTS idx_contract_dates        ON contract(actual_pickup_date, actual_return_date);

CREATE INDEX IF NOT EXISTS idx_payment_contract      ON payment(contract_id);
CREATE INDEX IF NOT EXISTS idx_payment_status        ON payment(status);

CREATE INDEX IF NOT EXISTS idx_maintenance_vehicle   ON maintenance(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_status    ON maintenance(status);

CREATE INDEX IF NOT EXISTS idx_damage_vehicle        ON damage_report(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_damage_status         ON damage_report(status);

CREATE INDEX IF NOT EXISTS idx_audit_log_table       ON audit_log(table_name, changed_at);
CREATE INDEX IF NOT EXISTS idx_insurance_vehicle     ON insurance(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_staff_branch          ON staff(branch_id);


-- ─────────────────────────────────────────────
-- SECTION 3: VIEWS
-- ─────────────────────────────────────────────

-- 3.1 Available vehicles with full model and branch detail
CREATE OR REPLACE VIEW vw_available_vehicles AS
SELECT
    v.vehicle_id,
    v.license_plate,
    v.color,
    v.mileage,
    v.daily_rate,
    v.status,
    m.make,
    m.model_name,
    m.year,
    m.fuel_type,
    m.transmission,
    m.passenger_capacity,
    c.name          AS category,
    c.base_daily_rate,
    b.name          AS branch_name,
    b.city          AS branch_city
FROM vehicle v
JOIN model    m ON v.model_id    = m.model_id
JOIN category c ON m.category_id = c.category_id
JOIN branch   b ON v.branch_id   = b.branch_id
WHERE v.status = 'Available';

-- 3.2 Active contracts with customer and vehicle summary
CREATE OR REPLACE VIEW vw_active_contracts AS
SELECT
    ct.contract_id,
    ct.actual_pickup_date,
    ct.actual_return_date,
    ct.agreed_daily_rate,
    ct.total_amount,
    ct.status,
    cu.first_name || ' ' || cu.last_name  AS customer_name,
    cu.email                               AS customer_email,
    cu.phone                               AS customer_phone,
    v.license_plate,
    m.make || ' ' || m.model_name          AS vehicle_name,
    pb.name                                AS pickup_branch,
    rb.name                                AS return_branch,
    s.first_name || ' ' || s.last_name     AS handled_by
FROM contract ct
JOIN customer cu ON ct.customer_id       = cu.customer_id
JOIN vehicle  v  ON ct.vehicle_id        = v.vehicle_id
JOIN model    m  ON v.model_id           = m.model_id
JOIN branch   pb ON ct.pickup_branch_id  = pb.branch_id
JOIN branch   rb ON ct.return_branch_id  = rb.branch_id
JOIN staff    s  ON ct.staff_id          = s.staff_id
WHERE ct.status = 'Active';

-- 3.3 Revenue summary per branch
CREATE OR REPLACE VIEW vw_branch_revenue AS
SELECT
    b.branch_id,
    b.name          AS branch_name,
    b.city,
    COUNT(ct.contract_id)             AS total_contracts,
    COALESCE(SUM(ct.total_amount), 0) AS total_revenue,
    COALESCE(AVG(ct.total_amount), 0) AS avg_contract_value
FROM branch b
LEFT JOIN contract ct ON ct.pickup_branch_id = b.branch_id
                      AND ct.status = 'Closed'
GROUP BY b.branch_id, b.name, b.city;

-- 3.4 Customer rental history
CREATE OR REPLACE VIEW vw_customer_history AS
SELECT
    cu.customer_id,
    cu.first_name || ' ' || cu.last_name AS customer_name,
    cu.email,
    cu.driver_license_no,
    COUNT(ct.contract_id)                AS total_rentals,
    COALESCE(SUM(ct.total_amount), 0)    AS total_spent,
    MAX(ct.actual_pickup_date)           AS last_rental_date
FROM customer cu
LEFT JOIN contract ct ON cu.customer_id = ct.customer_id
GROUP BY cu.customer_id, cu.first_name, cu.last_name, cu.email, cu.driver_license_no;

-- 3.5 Vehicles due for maintenance (no completed maintenance in last 90 days)
CREATE OR REPLACE VIEW vw_vehicles_due_maintenance AS
SELECT
    v.vehicle_id,
    v.license_plate,
    v.mileage,
    m.make || ' ' || m.model_name AS vehicle_name,
    b.name                        AS branch_name,
    MAX(mt.end_date)              AS last_service_date,
    CURRENT_DATE - MAX(mt.end_date) AS days_since_service
FROM vehicle v
JOIN model  m  ON v.model_id  = m.model_id
JOIN branch b  ON v.branch_id = b.branch_id
LEFT JOIN maintenance mt ON v.vehicle_id = mt.vehicle_id AND mt.status = 'Completed'
WHERE v.status != 'Retired'
GROUP BY v.vehicle_id, v.license_plate, v.mileage, m.make, m.model_name, b.name
HAVING MAX(mt.end_date) IS NULL OR MAX(mt.end_date) < CURRENT_DATE - INTERVAL '90 days';

-- 3.6 Insurance expiry tracker
CREATE OR REPLACE VIEW vw_insurance_expiry AS
SELECT
    i.insurance_id,
    i.policy_number,
    i.provider,
    i.coverage_type,
    i.end_date,
    i.end_date - CURRENT_DATE AS days_until_expiry,
    v.license_plate,
    m.make || ' ' || m.model_name AS vehicle_name,
    b.name AS branch_name,
    CASE
        WHEN i.end_date < CURRENT_DATE THEN 'Expired'
        WHEN i.end_date < CURRENT_DATE + INTERVAL '30 days' THEN 'Expiring Soon'
        ELSE 'Active'
    END AS expiry_status
FROM insurance i
JOIN vehicle v ON i.vehicle_id = v.vehicle_id
JOIN model   m ON v.model_id   = m.model_id
JOIN branch  b ON v.branch_id  = b.branch_id
ORDER BY i.end_date ASC;


-- ─────────────────────────────────────────────
-- SECTION 4: PL/pgSQL — TRIGGERS
-- ─────────────────────────────────────────────

-- 4.1 Generic audit trigger function (reused across tables)
DROP FUNCTION IF EXISTS fn_audit_trigger() CASCADE;

CREATE OR REPLACE FUNCTION fn_audit_trigger()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_record_id UUID;
    v_id_col    TEXT := TG_TABLE_NAME || '_id';
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_record_id := (to_jsonb(NEW) ->> v_id_col)::UUID;
        INSERT INTO audit_log(table_name, operation, record_id, new_data)
        VALUES (TG_TABLE_NAME, 'INSERT', v_record_id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        v_record_id := (to_jsonb(NEW) ->> v_id_col)::UUID;
        INSERT INTO audit_log(table_name, operation, record_id, old_data, new_data)
        VALUES (TG_TABLE_NAME, 'UPDATE', v_record_id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        v_record_id := (to_jsonb(OLD) ->> v_id_col)::UUID;
        INSERT INTO audit_log(table_name, operation, record_id, old_data)
        VALUES (TG_TABLE_NAME, 'DELETE', v_record_id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$;

-- Apply audit trigger to key tables
CREATE OR REPLACE TRIGGER trg_audit_contract
    AFTER INSERT OR UPDATE OR DELETE ON contract
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

CREATE OR REPLACE TRIGGER trg_audit_reservation
    AFTER INSERT OR UPDATE OR DELETE ON reservation
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

CREATE OR REPLACE TRIGGER trg_audit_payment
    AFTER INSERT OR UPDATE OR DELETE ON payment
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

-- 4.2 BEFORE trigger: auto-set vehicle status to 'Rented' when contract is created
CREATE OR REPLACE FUNCTION fn_contract_vehicle_status()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE vehicle SET status = 'Rented' WHERE vehicle_id = NEW.vehicle_id;
    ELSIF TG_OP = 'UPDATE' AND NEW.status = 'Closed' AND OLD.status = 'Active' THEN
        -- Calculate base_amount and total when contract is closed
        NEW.base_amount := NEW.agreed_daily_rate *
            EXTRACT(DAY FROM (NEW.actual_return_date - NEW.actual_pickup_date));
        NEW.total_amount := NEW.base_amount + NEW.additional_charges;
        -- Free the vehicle
        UPDATE vehicle SET status = 'Available' WHERE vehicle_id = NEW.vehicle_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_contract_vehicle_status
    BEFORE INSERT OR UPDATE ON contract
    FOR EACH ROW EXECUTE FUNCTION fn_contract_vehicle_status();

-- 4.3 BEFORE trigger: set vehicle to 'Maintenance' on maintenance insert
CREATE OR REPLACE FUNCTION fn_maintenance_vehicle_status()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.status = 'In Progress' THEN
        UPDATE vehicle SET status = 'Maintenance' WHERE vehicle_id = NEW.vehicle_id;
    ELSIF TG_OP = 'UPDATE' AND NEW.status = 'Completed' AND OLD.status != 'Completed' THEN
        UPDATE vehicle SET status = 'Available' WHERE vehicle_id = NEW.vehicle_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_maintenance_vehicle_status
    AFTER INSERT OR UPDATE ON maintenance
    FOR EACH ROW EXECUTE FUNCTION fn_maintenance_vehicle_status();

-- 4.4 BEFORE trigger: prevent double-booking a vehicle
CREATE OR REPLACE FUNCTION fn_prevent_double_booking()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_conflict_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_conflict_count
    FROM reservation
    WHERE vehicle_id = NEW.vehicle_id
      AND reservation_id != COALESCE(NEW.reservation_id, uuid_generate_v4())
      AND status NOT IN ('Cancelled','Completed')
      AND (pickup_date, return_date) OVERLAPS (NEW.pickup_date, NEW.return_date);

    IF v_conflict_count > 0 THEN
        RAISE EXCEPTION 'Vehicle % is already reserved for this period.', NEW.vehicle_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_prevent_double_booking
    BEFORE INSERT OR UPDATE ON reservation
    FOR EACH ROW EXECUTE FUNCTION fn_prevent_double_booking();

-- 4.5 AFTER trigger: mark reservation as Completed when contract closes
CREATE OR REPLACE FUNCTION fn_sync_reservation_on_close()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = 'Closed' AND OLD.status = 'Active' AND NEW.reservation_id IS NOT NULL THEN
        UPDATE reservation SET status = 'Completed' WHERE reservation_id = NEW.reservation_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_sync_reservation_on_close
    AFTER UPDATE ON contract
    FOR EACH ROW EXECUTE FUNCTION fn_sync_reservation_on_close();


-- ─────────────────────────────────────────────
-- SECTION 5: PL/pgSQL — FUNCTIONS & PROCEDURES
-- (Simulating Package Spec + Body in PostgreSQL)
-- ─────────────────────────────────────────────

-- ── PACKAGE: rental_ops (Reservation & Contract operations) ──

-- fn_create_reservation: validates and creates a reservation
CREATE OR REPLACE FUNCTION rental_ops_create_reservation(
    p_customer_id    UUID,
    p_vehicle_id     UUID,
    p_pickup_branch  UUID,
    p_return_branch  UUID,
    p_pickup_date    TIMESTAMPTZ,
    p_return_date    TIMESTAMPTZ
)
RETURNS UUID LANGUAGE plpgsql AS $$
DECLARE
    v_reservation_id UUID;
    v_vehicle_status TEXT;
    v_daily_rate     DECIMAL(10,2);
    v_days           NUMERIC;
    v_total          DECIMAL(10,2);
BEGIN
    -- Validate vehicle exists and is available
    SELECT status, daily_rate INTO v_vehicle_status, v_daily_rate
    FROM vehicle WHERE vehicle_id = p_vehicle_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vehicle not found: %', p_vehicle_id;
    END IF;
    IF v_vehicle_status != 'Available' THEN
        RAISE EXCEPTION 'Vehicle is not available. Current status: %', v_vehicle_status;
    END IF;

    -- Calculate total
    v_days  := EXTRACT(EPOCH FROM (p_return_date - p_pickup_date)) / 86400;
    v_total := v_daily_rate * v_days;

    -- Insert reservation
    INSERT INTO reservation (
        customer_id, vehicle_id, pickup_branch_id, return_branch_id,
        pickup_date, return_date, status, total_amount
    ) VALUES (
        p_customer_id, p_vehicle_id, p_pickup_branch, p_return_branch,
        p_pickup_date, p_return_date, 'Confirmed', v_total
    ) RETURNING reservation_id INTO v_reservation_id;

    RETURN v_reservation_id;
END;
$$;

-- fn_close_contract: closes a contract and calculates final charges
CREATE OR REPLACE FUNCTION rental_ops_close_contract(
    p_contract_id        UUID,
    p_actual_return_date TIMESTAMPTZ,
    p_additional_charges DECIMAL DEFAULT 0
)
RETURNS DECIMAL LANGUAGE plpgsql AS $$
DECLARE
    v_contract       contract%ROWTYPE;
    v_days           NUMERIC;
    v_base_amount    DECIMAL(10,2);
    v_total          DECIMAL(10,2);
BEGIN
    SELECT * INTO v_contract FROM contract WHERE contract_id = p_contract_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Contract not found: %', p_contract_id;
    END IF;
    IF v_contract.status != 'Active' THEN
        RAISE EXCEPTION 'Contract is not active. Status: %', v_contract.status;
    END IF;

    v_days        := GREATEST(1, EXTRACT(DAY FROM (p_actual_return_date - v_contract.actual_pickup_date)));
    v_base_amount := v_contract.agreed_daily_rate * v_days;
    v_total       := v_base_amount + p_additional_charges;

    UPDATE contract
    SET actual_return_date = p_actual_return_date,
        base_amount        = v_base_amount,
        additional_charges = p_additional_charges,
        total_amount       = v_total,
        status             = 'Closed'
    WHERE contract_id = p_contract_id;

    RETURN v_total;
END;
$$;

-- ── PACKAGE: fleet_ops (Fleet & Maintenance management) ──

-- fn_get_available_vehicles: returns available vehicles for a date range
CREATE OR REPLACE FUNCTION fleet_ops_available_vehicles(
    p_pickup_date  TIMESTAMPTZ,
    p_return_date  TIMESTAMPTZ,
    p_branch_id    UUID DEFAULT NULL
)
RETURNS TABLE (
    vehicle_id    UUID,
    license_plate TEXT,
    make          TEXT,
    model_name    TEXT,
    year          SMALLINT,
    daily_rate    DECIMAL,
    branch_name   TEXT
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        v.vehicle_id, v.license_plate::TEXT,
        m.make::TEXT, m.model_name::TEXT, m.year,
        v.daily_rate, b.name::TEXT
    FROM vehicle v
    JOIN model  m ON v.model_id  = m.model_id
    JOIN branch b ON v.branch_id = b.branch_id
    WHERE v.status = 'Available'
      AND (p_branch_id IS NULL OR v.branch_id = p_branch_id)
      AND v.vehicle_id NOT IN (
          SELECT r.vehicle_id FROM reservation r
          WHERE r.status IN ('Pending','Confirmed')
            AND (r.pickup_date, r.return_date) OVERLAPS (p_pickup_date, p_return_date)
      );
END;
$$;

-- fn_branch_revenue_report: revenue summary for a branch over a date range
CREATE OR REPLACE FUNCTION fleet_ops_branch_revenue(
    p_branch_id UUID,
    p_from_date DATE,
    p_to_date   DATE
)
RETURNS TABLE (
    month_label     TEXT,
    total_contracts BIGINT,
    total_revenue   DECIMAL,
    avg_days        NUMERIC
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        TO_CHAR(DATE_TRUNC('month', ct.actual_pickup_date), 'Mon YYYY') AS month_label,
        COUNT(*)                                                          AS total_contracts,
        COALESCE(SUM(ct.total_amount), 0)                                AS total_revenue,
        AVG(EXTRACT(DAY FROM (ct.actual_return_date - ct.actual_pickup_date))) AS avg_days
    FROM contract ct
    WHERE ct.pickup_branch_id = p_branch_id
      AND ct.status           = 'Closed'
      AND ct.actual_pickup_date::DATE BETWEEN p_from_date AND p_to_date
    GROUP BY DATE_TRUNC('month', ct.actual_pickup_date)
    ORDER BY DATE_TRUNC('month', ct.actual_pickup_date);
END;
$$;

-- ── CURSOR USAGE EXAMPLE: Process overdue contracts ──
-- (Exposed as a callable function that returns a result set)
CREATE OR REPLACE FUNCTION rental_ops_flag_overdue_contracts()
RETURNS TABLE (contract_id UUID, customer_name TEXT, days_overdue INT)
LANGUAGE plpgsql AS $$
DECLARE
    cur_overdue CURSOR FOR
        SELECT
            ct.contract_id,
            cu.first_name || ' ' || cu.last_name AS customer_name,
            EXTRACT(DAY FROM NOW() - ct.actual_pickup_date)::INT AS days_overdue
        FROM contract ct
        JOIN customer cu ON ct.customer_id = cu.customer_id
        WHERE ct.status = 'Active'
          AND ct.actual_return_date IS NULL
          AND ct.actual_pickup_date < NOW() - INTERVAL '30 days';
    rec RECORD;
BEGIN
    OPEN cur_overdue;
    LOOP
        FETCH cur_overdue INTO rec;
        EXIT WHEN NOT FOUND;

        -- update to Disputed if overdue > 30 days
        UPDATE contract SET status = 'Disputed' WHERE contract.contract_id = rec.contract_id;

        contract_id   := rec.contract_id;
        customer_name := rec.customer_name;
        days_overdue  := rec.days_overdue;
        RETURN NEXT;
    END LOOP;
    CLOSE cur_overdue;
END;
$$;


-- ─────────────────────────────────────────────
-- SECTION 6: CUSTOM TYPES (Object-Oriented DB)
-- ─────────────────────────────────────────────

-- Composite type: vehicle summary
CREATE TYPE vehicle_summary_t AS (
    vehicle_id    UUID,
    display_name  TEXT,
    license_plate TEXT,
    daily_rate    DECIMAL(10,2),
    status        TEXT,
    branch        TEXT
);

-- Composite type: rental invoice
CREATE TYPE rental_invoice_t AS (
    contract_id        UUID,
    customer_name      TEXT,
    vehicle_name       TEXT,
    pickup_date        TIMESTAMPTZ,
    return_date        TIMESTAMPTZ,
    days               INT,
    daily_rate         DECIMAL(10,2),
    base_amount        DECIMAL(10,2),
    additional_charges DECIMAL(10,2),
    total_amount       DECIMAL(10,2)
);

-- Function returning custom type
CREATE OR REPLACE FUNCTION get_rental_invoice(p_contract_id UUID)
RETURNS rental_invoice_t LANGUAGE plpgsql AS $$
DECLARE
    v_invoice rental_invoice_t;
BEGIN
    SELECT
        ct.contract_id,
        cu.first_name || ' ' || cu.last_name,
        m.make || ' ' || m.model_name,
        ct.actual_pickup_date,
        ct.actual_return_date,
        EXTRACT(DAY FROM (ct.actual_return_date - ct.actual_pickup_date))::INT,
        ct.agreed_daily_rate,
        ct.base_amount,
        ct.additional_charges,
        ct.total_amount
    INTO v_invoice
    FROM contract ct
    JOIN customer cu ON ct.customer_id = cu.customer_id
    JOIN vehicle   v ON ct.vehicle_id  = v.vehicle_id
    JOIN model     m ON v.model_id     = m.model_id
    WHERE ct.contract_id = p_contract_id;

    RETURN v_invoice;
END;
$$;


-- ─────────────────────────────────────────────
-- SECTION 7: DCL — ROLES & PERMISSIONS
-- ─────────────────────────────────────────────

-- Create application roles
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'rental_readonly') THEN
        CREATE ROLE rental_readonly;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'rental_agent') THEN
        CREATE ROLE rental_agent;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'rental_manager') THEN
        CREATE ROLE rental_manager;
    END IF;
END
$$;

-- readonly: can only query core tables
GRANT SELECT ON vehicle, model, category, branch, customer, reservation TO rental_readonly;

-- agent: full CRUD on operational tables
GRANT SELECT, INSERT, UPDATE ON
    customer, reservation, contract, payment, damage_report
    TO rental_agent;
GRANT SELECT ON vehicle, model, category, branch, staff, insurance TO rental_agent;

-- manager: full access except audit_log modifications
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO rental_manager;
REVOKE DELETE ON audit_log FROM rental_manager;

-- Revoke direct delete on contracts from agents (must go through function)
REVOKE DELETE ON contract FROM rental_agent;


-- ─────────────────────────────────────────────
-- SECTION 8: SEED DATA (15 records per table)
-- ─────────────────────────────────────────────

-- 8.1 Categories
INSERT INTO category (category_id, name, description, base_daily_rate) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Economy',    'Compact fuel-efficient cars',           25.00),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'Sedan',      'Standard 4-door sedans',                35.00),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'SUV',        'Sport Utility Vehicles',                55.00),
  ('aaaaaaaa-0000-0000-0000-000000000004', 'Luxury',     'Premium class vehicles',                95.00),
  ('aaaaaaaa-0000-0000-0000-000000000005', 'Pickup',     'Utility pickup trucks',                 45.00),
  ('aaaaaaaa-0000-0000-0000-000000000006', 'Van',        'Passenger and cargo vans',              60.00),
  ('aaaaaaaa-0000-0000-0000-000000000007', 'Mini SUV',   'Compact crossovers for city rentals',   48.00),
  ('aaaaaaaa-0000-0000-0000-000000000008', 'Executive',  'Business class premium sedans',         80.00),
  ('aaaaaaaa-0000-0000-0000-000000000009', 'Electric',   'Battery electric vehicles',             70.00),
  ('aaaaaaaa-0000-0000-0000-000000000010', 'Commercial', 'High-capacity business utility vehicles',65.00);

-- 8.2 Models (15 records)
INSERT INTO model (model_id, category_id, make, model_name, year, passenger_capacity, fuel_type, transmission) VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','Toyota','Yaris',      2022, 5, 'Petrol',   'Manual'),
  ('bbbbbbbb-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001','Honda', 'Fit',        2023, 5, 'Petrol',   'Automatic'),
  ('bbbbbbbb-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000002','Toyota','Corolla',    2023, 5, 'Hybrid',   'Automatic'),
  ('bbbbbbbb-0000-0000-0000-000000000004','aaaaaaaa-0000-0000-0000-000000000002','Honda', 'Civic',      2022, 5, 'Petrol',   'Automatic'),
  ('bbbbbbbb-0000-0000-0000-000000000005','aaaaaaaa-0000-0000-0000-000000000002','Nissan','Sentra',     2021, 5, 'Petrol',   'Manual'),
  ('bbbbbbbb-0000-0000-0000-000000000006','aaaaaaaa-0000-0000-0000-000000000003','Toyota','RAV4',       2023, 5, 'Hybrid',   'Automatic'),
  ('bbbbbbbb-0000-0000-0000-000000000007','aaaaaaaa-0000-0000-0000-000000000003','Ford',  'Explorer',   2022, 7, 'Petrol',   'Automatic'),
  ('bbbbbbbb-0000-0000-0000-000000000008','aaaaaaaa-0000-0000-0000-000000000003','Hyundai','Tucson',    2023, 5, 'Diesel',   'Automatic'),
  ('bbbbbbbb-0000-0000-0000-000000000009','aaaaaaaa-0000-0000-0000-000000000004','BMW',   '5 Series',   2023, 5, 'Petrol',   'Automatic'),
  ('bbbbbbbb-0000-0000-0000-000000000010','aaaaaaaa-0000-0000-0000-000000000004','Mercedes','E-Class',  2022, 5, 'Diesel',   'Automatic'),
  ('bbbbbbbb-0000-0000-0000-000000000011','aaaaaaaa-0000-0000-0000-000000000004','Audi',  'A6',         2023, 5, 'Petrol',   'Automatic'),
  ('bbbbbbbb-0000-0000-0000-000000000012','aaaaaaaa-0000-0000-0000-000000000005','Ford',  'F-150',      2022, 5, 'Petrol',   'Automatic'),
  ('bbbbbbbb-0000-0000-0000-000000000013','aaaaaaaa-0000-0000-0000-000000000005','Toyota','Tacoma',     2023, 5, 'Petrol',   'Manual'),
  ('bbbbbbbb-0000-0000-0000-000000000014','aaaaaaaa-0000-0000-0000-000000000006','Ford',  'Transit',    2022,12, 'Diesel',   'Manual'),
  ('bbbbbbbb-0000-0000-0000-000000000015','aaaaaaaa-0000-0000-0000-000000000001','Tesla', 'Model 3',    2023, 5, 'Electric', 'Automatic');

-- 8.3 Branches (5 records — FK to staff not yet set, manager_id updated after staff insert)
INSERT INTO branch (branch_id, name, address, city, phone, email) VALUES
  ('cccccccc-0000-0000-0000-000000000001','Downtown Branch',  '15 Main Street',      'Lahore',    '+92-42-1234567', 'downtown@vrental.com'),
  ('cccccccc-0000-0000-0000-000000000002','Airport Branch',   '3 Airport Road',      'Karachi',   '+92-21-2345678', 'airport@vrental.com'),
  ('cccccccc-0000-0000-0000-000000000003','North City Branch','72 GT Road',          'Islamabad', '+92-51-3456789', 'north@vrental.com'),
  ('cccccccc-0000-0000-0000-000000000004','East Side Branch', '200 Ring Road',       'Lahore',    '+92-42-4567890', 'east@vrental.com'),
  ('cccccccc-0000-0000-0000-000000000005','South Plaza Branch','9 Commercial Zone',  'Karachi',   '+92-21-5678901', 'south@vrental.com'),
  ('cccccccc-0000-0000-0000-000000000006','University Branch','12 Campus Road',      'Lahore',    '+92-42-6678901', 'university@vrental.com'),
  ('cccccccc-0000-0000-0000-000000000007','Seaview Branch',   '88 Seaview Avenue',   'Karachi',   '+92-21-6678902', 'seaview@vrental.com'),
  ('cccccccc-0000-0000-0000-000000000008','Blue Area Branch', '44 Jinnah Avenue',    'Islamabad', '+92-51-6678903', 'bluearea@vrental.com'),
  ('cccccccc-0000-0000-0000-000000000009','Cantt Branch',     '19 Mall Road Cantt',  'Rawalpindi','+92-51-6678904', 'cantt@vrental.com'),
  ('cccccccc-0000-0000-0000-000000000010','Bahria Branch',    '27 Bahria Town',      'Lahore',    '+92-42-6678905', 'bahria@vrental.com');

-- 8.4 Staff (15 records)
INSERT INTO staff (staff_id, branch_id, first_name, last_name, email, phone, role, hire_date, salary) VALUES
  ('dddddddd-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001','Ahmed',  'Khan',    'ahmed.khan@vrental.com',   '+923001111111','Manager',  '2020-01-15', 85000),
  ('dddddddd-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000001','Sana',   'Malik',   'sana.malik@vrental.com',   '+923002222222','Agent',    '2021-03-10', 45000),
  ('dddddddd-0000-0000-0000-000000000003','cccccccc-0000-0000-0000-000000000001','Usman',  'Ali',     'usman.ali@vrental.com',    '+923003333333','Mechanic', '2021-06-20', 50000),
  ('dddddddd-0000-0000-0000-000000000004','cccccccc-0000-0000-0000-000000000002','Fatima', 'Hussain', 'fatima.h@vrental.com',     '+923004444444','Manager',  '2019-11-05', 88000),
  ('dddddddd-0000-0000-0000-000000000005','cccccccc-0000-0000-0000-000000000002','Bilal',  'Ahmed',   'bilal.ahmed@vrental.com',  '+923005555555','Agent',    '2022-02-14', 44000),
  ('dddddddd-0000-0000-0000-000000000006','cccccccc-0000-0000-0000-000000000002','Zara',   'Qureshi', 'zara.q@vrental.com',       '+923006666666','Agent',    '2022-07-01', 43000),
  ('dddddddd-0000-0000-0000-000000000007','cccccccc-0000-0000-0000-000000000003','Hassan', 'Shah',    'hassan.shah@vrental.com',  '+923007777777','Manager',  '2020-05-18', 87000),
  ('dddddddd-0000-0000-0000-000000000008','cccccccc-0000-0000-0000-000000000003','Ayesha', 'Baig',    'ayesha.b@vrental.com',     '+923008888888','Agent',    '2023-01-09', 42000),
  ('dddddddd-0000-0000-0000-000000000009','cccccccc-0000-0000-0000-000000000003','Raza',   'Mir',     'raza.mir@vrental.com',     '+923009999999','Mechanic', '2021-09-15', 52000),
  ('dddddddd-0000-0000-0000-000000000010','cccccccc-0000-0000-0000-000000000004','Nadia',  'Iqbal',   'nadia.i@vrental.com',      '+923010101010','Manager',  '2020-08-22', 84000),
  ('dddddddd-0000-0000-0000-000000000011','cccccccc-0000-0000-0000-000000000004','Omar',   'Farooq',  'omar.f@vrental.com',       '+923011111111','Agent',    '2022-11-03', 45000),
  ('dddddddd-0000-0000-0000-000000000012','cccccccc-0000-0000-0000-000000000004','Hina',   'Riaz',    'hina.r@vrental.com',       '+923012121212','Cleaner',  '2023-03-01', 32000),
  ('dddddddd-0000-0000-0000-000000000013','cccccccc-0000-0000-0000-000000000005','Tariq',  'Mehmood', 'tariq.m@vrental.com',      '+923013131313','Manager',  '2019-04-10', 90000),
  ('dddddddd-0000-0000-0000-000000000014','cccccccc-0000-0000-0000-000000000005','Sara',   'Nawaz',   'sara.n@vrental.com',       '+923014141414','Agent',    '2022-06-15', 43500),
  ('dddddddd-0000-0000-0000-000000000015','cccccccc-0000-0000-0000-000000000005','Khalid', 'Javed',   'khalid.j@vrental.com',     '+923015151515','Mechanic', '2020-12-01', 51000);

-- Update branch managers
UPDATE branch SET manager_id = 'dddddddd-0000-0000-0000-000000000001' WHERE branch_id = 'cccccccc-0000-0000-0000-000000000001';
UPDATE branch SET manager_id = 'dddddddd-0000-0000-0000-000000000004' WHERE branch_id = 'cccccccc-0000-0000-0000-000000000002';
UPDATE branch SET manager_id = 'dddddddd-0000-0000-0000-000000000007' WHERE branch_id = 'cccccccc-0000-0000-0000-000000000003';
UPDATE branch SET manager_id = 'dddddddd-0000-0000-0000-000000000010' WHERE branch_id = 'cccccccc-0000-0000-0000-000000000004';
UPDATE branch SET manager_id = 'dddddddd-0000-0000-0000-000000000013' WHERE branch_id = 'cccccccc-0000-0000-0000-000000000005';

-- 8.5 Vehicles (15 records)
INSERT INTO vehicle (vehicle_id, model_id, branch_id, license_plate, vin, color, mileage, status, daily_rate, purchase_date) VALUES
  ('eeeeeeee-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001','LHR-001','VIN00000000000001','White',  12000,'Available', 25.00,'2022-03-01'),
  ('eeeeeeee-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000003','cccccccc-0000-0000-0000-000000000001','LHR-002','VIN00000000000002','Silver', 8500, 'Available', 38.00,'2023-01-15'),
  ('eeeeeeee-0000-0000-0000-000000000003','bbbbbbbb-0000-0000-0000-000000000006','cccccccc-0000-0000-0000-000000000001','LHR-003','VIN00000000000003','Black',  5200, 'Available', 58.00,'2023-06-10'),
  ('eeeeeeee-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000009','cccccccc-0000-0000-0000-000000000001','LHR-004','VIN00000000000004','Blue',   3100, 'Available', 98.00,'2023-08-20'),
  ('eeeeeeee-0000-0000-0000-000000000005','bbbbbbbb-0000-0000-0000-000000000004','cccccccc-0000-0000-0000-000000000002','KHI-001','VIN00000000000005','Red',    22000,'Available', 36.00,'2021-11-05'),
  ('eeeeeeee-0000-0000-0000-000000000006','bbbbbbbb-0000-0000-0000-000000000007','cccccccc-0000-0000-0000-000000000002','KHI-002','VIN00000000000006','White',  18000,'Available', 57.00,'2022-07-12'),
  ('eeeeeeee-0000-0000-0000-000000000007','bbbbbbbb-0000-0000-0000-000000000010','cccccccc-0000-0000-0000-000000000002','KHI-003','VIN00000000000007','Grey',   6700, 'Available', 97.00,'2022-12-01'),
  ('eeeeeeee-0000-0000-0000-000000000008','bbbbbbbb-0000-0000-0000-000000000012','cccccccc-0000-0000-0000-000000000003','ISB-001','VIN00000000000008','White',  31000,'Available', 46.00,'2021-04-18'),
  ('eeeeeeee-0000-0000-0000-000000000009','bbbbbbbb-0000-0000-0000-000000000015','cccccccc-0000-0000-0000-000000000003','ISB-002','VIN00000000000009','Red',    4100, 'Available', 72.00,'2023-09-01'),
  ('eeeeeeee-0000-0000-0000-000000000010','bbbbbbbb-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000003','ISB-003','VIN00000000000010','Blue',   9800, 'Available', 27.00,'2023-02-14'),
  ('eeeeeeee-0000-0000-0000-000000000011','bbbbbbbb-0000-0000-0000-000000000008','cccccccc-0000-0000-0000-000000000004','LHR-101','VIN00000000000011','Black',  14500,'Available', 59.00,'2023-04-05'),
  ('eeeeeeee-0000-0000-0000-000000000012','bbbbbbbb-0000-0000-0000-000000000011','cccccccc-0000-0000-0000-000000000004','LHR-102','VIN00000000000012','Silver', 2800, 'Available', 99.00,'2023-10-22'),
  ('eeeeeeee-0000-0000-0000-000000000013','bbbbbbbb-0000-0000-0000-000000000014','cccccccc-0000-0000-0000-000000000004','LHR-103','VIN00000000000013','White',  27000,'Available', 62.00,'2021-09-30'),
  ('eeeeeeee-0000-0000-0000-000000000014','bbbbbbbb-0000-0000-0000-000000000005','cccccccc-0000-0000-0000-000000000005','KHI-101','VIN00000000000014','Grey',   19000,'Available', 37.00,'2021-07-07'),
  ('eeeeeeee-0000-0000-0000-000000000015','bbbbbbbb-0000-0000-0000-000000000013','cccccccc-0000-0000-0000-000000000005','KHI-102','VIN00000000000015','Blue',   11000,'Available', 47.00,'2022-05-25');

-- 8.6 Insurance (15 records)
INSERT INTO insurance (vehicle_id, provider, policy_number, coverage_type, start_date, end_date, premium_amount) VALUES
  ('eeeeeeee-0000-0000-0000-000000000001','Jubilee Insurance','POL-2024-001','Comprehensive','2024-01-01','2025-12-31', 1200.00),
  ('eeeeeeee-0000-0000-0000-000000000002','EFU Life',         'POL-2024-002','Comprehensive','2024-01-01','2025-12-31', 1400.00),
  ('eeeeeeee-0000-0000-0000-000000000003','Adamjee',          'POL-2024-003','Comprehensive','2024-03-01','2026-02-28', 2100.00),
  ('eeeeeeee-0000-0000-0000-000000000004','Jubilee Insurance','POL-2024-004','Comprehensive','2024-06-01','2026-05-31', 3500.00),
  ('eeeeeeee-0000-0000-0000-000000000005','EFU Life',         'POL-2024-005','Third-Party',  '2024-01-01','2025-12-31',  800.00),
  ('eeeeeeee-0000-0000-0000-000000000006','Adamjee',          'POL-2024-006','Comprehensive','2024-02-01','2026-01-31', 2200.00),
  ('eeeeeeee-0000-0000-0000-000000000007','Jubilee Insurance','POL-2024-007','Comprehensive','2024-04-01','2026-03-31', 3600.00),
  ('eeeeeeee-0000-0000-0000-000000000008','EFU Life',         'POL-2024-008','Basic',        '2024-01-01','2025-12-31',  950.00),
  ('eeeeeeee-0000-0000-0000-000000000009','Adamjee',          'POL-2024-009','Comprehensive','2024-07-01','2026-06-30', 2800.00),
  ('eeeeeeee-0000-0000-0000-000000000010','Jubilee Insurance','POL-2024-010','Third-Party',  '2024-01-01','2025-12-31',  750.00),
  ('eeeeeeee-0000-0000-0000-000000000011','EFU Life',         'POL-2024-011','Comprehensive','2024-05-01','2026-04-30', 2300.00),
  ('eeeeeeee-0000-0000-0000-000000000012','Adamjee',          'POL-2024-012','Comprehensive','2024-08-01','2026-07-31', 3700.00),
  ('eeeeeeee-0000-0000-0000-000000000013','Jubilee Insurance','POL-2024-013','Basic',        '2024-01-01','2025-12-31', 1100.00),
  ('eeeeeeee-0000-0000-0000-000000000014','EFU Life',         'POL-2024-014','Third-Party',  '2024-01-01','2025-12-31',  820.00),
  ('eeeeeeee-0000-0000-0000-000000000015','Adamjee',          'POL-2024-015','Comprehensive','2024-06-01','2026-05-31', 1900.00);

-- 8.7 Customers (15 records)
INSERT INTO customer (customer_id, first_name, last_name, email, phone, address, driver_license_no, license_expiry, date_of_birth) VALUES
  ('ffffffff-0000-0000-0000-000000000001','Ali',     'Raza',    'ali.raza@gmail.com',    '+923100001111','12 Model Town Lahore',   'DL-LHR-10001','2027-05-10','1990-04-15'),
  ('ffffffff-0000-0000-0000-000000000002','Sara',    'Ahmed',   'sara.ahmed@gmail.com',  '+923100002222','45 Gulshan Karachi',     'DL-KHI-10002','2026-08-20','1992-09-22'),
  ('ffffffff-0000-0000-0000-000000000003','Hamza',   'Khan',    'hamza.khan@gmail.com',  '+923100003333','7 F-7 Islamabad',        'DL-ISB-10003','2028-03-14','1988-12-01'),
  ('ffffffff-0000-0000-0000-000000000004','Maryam',  'Iqbal',   'maryam.i@gmail.com',   '+923100004444','33 DHA Lahore',          'DL-LHR-10004','2025-11-30','1995-07-08'),
  ('ffffffff-0000-0000-0000-000000000005','Usman',   'Tariq',   'usman.t@gmail.com',    '+923100005555','19 Clifton Karachi',     'DL-KHI-10005','2027-02-18','1987-03-25'),
  ('ffffffff-0000-0000-0000-000000000006','Zainab',  'Haider',  'zainab.h@gmail.com',   '+923100006666','88 G-9 Islamabad',       'DL-ISB-10006','2026-06-12','1993-11-14'),
  ('ffffffff-0000-0000-0000-000000000007','Faisal',  'Siddiqui','faisal.s@gmail.com',   '+923100007777','22 Johar Town Lahore',   'DL-LHR-10007','2028-09-05','1985-06-30'),
  ('ffffffff-0000-0000-0000-000000000008','Amna',    'Butt',    'amna.butt@gmail.com',  '+923100008888','5 PECHS Karachi',        'DL-KHI-10008','2027-12-01','1997-02-10'),
  ('ffffffff-0000-0000-0000-000000000009','Kamran',  'Malik',   'kamran.m@gmail.com',   '+923100009999','14 E-11 Islamabad',      'DL-ISB-10009','2026-04-20','1989-08-17'),
  ('ffffffff-0000-0000-0000-000000000010','Hira',    'Shah',    'hira.shah@gmail.com',  '+923100010000','67 Gulberg Lahore',      'DL-LHR-10010','2025-07-15','1994-05-28'),
  ('ffffffff-0000-0000-0000-000000000011','Asad',    'Nawaz',   'asad.n@gmail.com',     '+923100011111','31 North Nazimabad KHI', 'DL-KHI-10011','2028-01-22','1986-10-05'),
  ('ffffffff-0000-0000-0000-000000000012','Rabia',   'Chaudhry','rabia.c@gmail.com',    '+923100012222','9 Bahria Town ISB',      'DL-ISB-10012','2027-03-08','1991-07-19'),
  ('ffffffff-0000-0000-0000-000000000013','Waqas',   'Javed',   'waqas.j@gmail.com',   '+923100013333','55 Shadman Lahore',      'DL-LHR-10013','2026-10-27','1984-01-12'),
  ('ffffffff-0000-0000-0000-000000000014','Sobia',   'Rehman',  'sobia.r@gmail.com',   '+923100014444','18 Defence KHI',         'DL-KHI-10014','2027-08-14','1996-04-03'),
  ('ffffffff-0000-0000-0000-000000000015','Imran',   'Ghani',   'imran.g@gmail.com',   '+923100015555','42 I-8 Islamabad',       'DL-ISB-10015','2025-05-31','1983-09-20');

-- 8.8 Reservations (15 records — only vehicles that are currently Available)
INSERT INTO reservation (reservation_id, customer_id, vehicle_id, pickup_branch_id, return_branch_id, pickup_date, return_date, status, total_amount) VALUES
  ('11111111-0000-0000-0000-000000000001','ffffffff-0000-0000-0000-000000000001','eeeeeeee-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001','2026-05-10 10:00:00+05','2026-05-13 10:00:00+05','Confirmed', 75.00),
  ('11111111-0000-0000-0000-000000000002','ffffffff-0000-0000-0000-000000000002','eeeeeeee-0000-0000-0000-000000000005','cccccccc-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000002','2026-05-12 09:00:00+05','2026-05-15 09:00:00+05','Confirmed', 108.00),
  ('11111111-0000-0000-0000-000000000003','ffffffff-0000-0000-0000-000000000003','eeeeeeee-0000-0000-0000-000000000009','cccccccc-0000-0000-0000-000000000003','cccccccc-0000-0000-0000-000000000003','2026-05-14 08:00:00+05','2026-05-19 08:00:00+05','Confirmed', 360.00),
  ('11111111-0000-0000-0000-000000000004','ffffffff-0000-0000-0000-000000000004','eeeeeeee-0000-0000-0000-000000000011','cccccccc-0000-0000-0000-000000000004','cccccccc-0000-0000-0000-000000000001','2026-05-08 12:00:00+05','2026-05-10 12:00:00+05','Completed', 118.00),
  ('11111111-0000-0000-0000-000000000005','ffffffff-0000-0000-0000-000000000005','eeeeeeee-0000-0000-0000-000000000007','cccccccc-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000002','2026-04-20 10:00:00+05','2026-04-25 10:00:00+05','Completed', 485.00),
  ('11111111-0000-0000-0000-000000000006','ffffffff-0000-0000-0000-000000000006','eeeeeeee-0000-0000-0000-000000000003','cccccccc-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001','2026-04-15 09:00:00+05','2026-04-18 09:00:00+05','Completed', 174.00),
  ('11111111-0000-0000-0000-000000000007','ffffffff-0000-0000-0000-000000000007','eeeeeeee-0000-0000-0000-000000000012','cccccccc-0000-0000-0000-000000000004','cccccccc-0000-0000-0000-000000000004','2026-05-20 10:00:00+05','2026-05-24 10:00:00+05','Confirmed', 396.00),
  ('11111111-0000-0000-0000-000000000008','ffffffff-0000-0000-0000-000000000008','eeeeeeee-0000-0000-0000-000000000014','cccccccc-0000-0000-0000-000000000005','cccccccc-0000-0000-0000-000000000005','2026-05-06 08:00:00+05','2026-05-09 08:00:00+05','Confirmed', 111.00),
  ('11111111-0000-0000-0000-000000000009','ffffffff-0000-0000-0000-000000000009','eeeeeeee-0000-0000-0000-000000000010','cccccccc-0000-0000-0000-000000000003','cccccccc-0000-0000-0000-000000000003','2026-04-01 10:00:00+05','2026-04-05 10:00:00+05','Completed', 108.00),
  ('11111111-0000-0000-0000-000000000010','ffffffff-0000-0000-0000-000000000010','eeeeeeee-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001','2026-03-20 09:00:00+05','2026-03-24 09:00:00+05','Completed', 152.00),
  ('11111111-0000-0000-0000-000000000011','ffffffff-0000-0000-0000-000000000011','eeeeeeee-0000-0000-0000-000000000008','cccccccc-0000-0000-0000-000000000003','cccccccc-0000-0000-0000-000000000004','2026-05-25 10:00:00+05','2026-05-30 10:00:00+05','Confirmed', 230.00),
  ('11111111-0000-0000-0000-000000000012','ffffffff-0000-0000-0000-000000000012','eeeeeeee-0000-0000-0000-000000000015','cccccccc-0000-0000-0000-000000000005','cccccccc-0000-0000-0000-000000000005','2026-04-10 08:00:00+05','2026-04-14 08:00:00+05','Completed', 188.00),
  ('11111111-0000-0000-0000-000000000013','ffffffff-0000-0000-0000-000000000013','eeeeeeee-0000-0000-0000-000000000004','cccccccc-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000002','2026-03-05 10:00:00+05','2026-03-10 10:00:00+05','Completed', 490.00),
  ('11111111-0000-0000-0000-000000000014','ffffffff-0000-0000-0000-000000000014','eeeeeeee-0000-0000-0000-000000000006','cccccccc-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000002','2026-06-01 09:00:00+05','2026-06-05 09:00:00+05','Pending',   228.00),
  ('11111111-0000-0000-0000-000000000015','ffffffff-0000-0000-0000-000000000015','eeeeeeee-0000-0000-0000-000000000013','cccccccc-0000-0000-0000-000000000004','cccccccc-0000-0000-0000-000000000005','2026-03-12 10:00:00+05','2026-03-15 10:00:00+05','Cancelled', 186.00);

-- 8.9 Contracts (12 records — for past/completed reservations)
-- NOTE: Inserting contracts will trigger vehicle status change to 'Rented' for active ones
INSERT INTO contract (contract_id, reservation_id, customer_id, vehicle_id, staff_id, pickup_branch_id, return_branch_id, actual_pickup_date, actual_return_date, agreed_daily_rate, base_amount, additional_charges, total_amount, status) VALUES
  ('22222222-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000004','ffffffff-0000-0000-0000-000000000004','eeeeeeee-0000-0000-0000-000000000011','dddddddd-0000-0000-0000-000000000011','cccccccc-0000-0000-0000-000000000004','cccccccc-0000-0000-0000-000000000001','2026-05-08 12:00:00+05','2026-05-10 12:00:00+05', 59.00, 118.00,   0.00,  118.00,'Closed'),
  ('22222222-0000-0000-0000-000000000002','11111111-0000-0000-0000-000000000005','ffffffff-0000-0000-0000-000000000005','eeeeeeee-0000-0000-0000-000000000007','dddddddd-0000-0000-0000-000000000005','cccccccc-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000002','2026-04-20 10:00:00+05','2026-04-25 11:00:00+05', 97.00, 485.00,  50.00,  535.00,'Closed'),
  ('22222222-0000-0000-0000-000000000003','11111111-0000-0000-0000-000000000006','ffffffff-0000-0000-0000-000000000006','eeeeeeee-0000-0000-0000-000000000003','dddddddd-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001','2026-04-15 09:00:00+05','2026-04-18 09:00:00+05', 58.00, 174.00,   0.00,  174.00,'Closed'),
  ('22222222-0000-0000-0000-000000000004','11111111-0000-0000-0000-000000000009','ffffffff-0000-0000-0000-000000000009','eeeeeeee-0000-0000-0000-000000000010','dddddddd-0000-0000-0000-000000000008','cccccccc-0000-0000-0000-000000000003','cccccccc-0000-0000-0000-000000000003','2026-04-01 10:00:00+05','2026-04-05 10:00:00+05', 27.00, 108.00,   0.00,  108.00,'Closed'),
  ('22222222-0000-0000-0000-000000000005','11111111-0000-0000-0000-000000000010','ffffffff-0000-0000-0000-000000000010','eeeeeeee-0000-0000-0000-000000000002','dddddddd-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001','2026-03-20 09:00:00+05','2026-03-24 09:00:00+05', 38.00, 152.00,   0.00,  152.00,'Closed'),
  ('22222222-0000-0000-0000-000000000006','11111111-0000-0000-0000-000000000012','ffffffff-0000-0000-0000-000000000012','eeeeeeee-0000-0000-0000-000000000015','dddddddd-0000-0000-0000-000000000014','cccccccc-0000-0000-0000-000000000005','cccccccc-0000-0000-0000-000000000005','2026-04-10 08:00:00+05','2026-04-14 08:00:00+05', 47.00, 188.00,   0.00,  188.00,'Closed'),
  ('22222222-0000-0000-0000-000000000007','11111111-0000-0000-0000-000000000013','ffffffff-0000-0000-0000-000000000013','eeeeeeee-0000-0000-0000-000000000004','dddddddd-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000002','2026-03-05 10:00:00+05','2026-03-10 10:00:00+05', 98.00, 490.00, 150.00,  640.00,'Closed'),
  -- Active contracts (vehicles will be set to 'Rented' by trigger)
  ('22222222-0000-0000-0000-000000000008', NULL,                                 'ffffffff-0000-0000-0000-000000000001','eeeeeeee-0000-0000-0000-000000000001','dddddddd-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001','2026-05-03 10:00:00+05', NULL,                    25.00,  NULL,   0.00,    NULL,'Active'),
  ('22222222-0000-0000-0000-000000000009', NULL,                                 'ffffffff-0000-0000-0000-000000000003','eeeeeeee-0000-0000-0000-000000000006','dddddddd-0000-0000-0000-000000000005','cccccccc-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000002','2026-05-01 08:00:00+05', NULL,                    57.00,  NULL,   0.00,    NULL,'Active'),
  ('22222222-0000-0000-0000-000000000010', NULL,                                 'ffffffff-0000-0000-0000-000000000007','eeeeeeee-0000-0000-0000-000000000004','dddddddd-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001','2026-04-28 10:00:00+05', NULL,                    98.00,  NULL,   0.00,    NULL,'Active'),
  ('22222222-0000-0000-0000-000000000011', NULL,                                 'ffffffff-0000-0000-0000-000000000011','eeeeeeee-0000-0000-0000-000000000008','dddddddd-0000-0000-0000-000000000008','cccccccc-0000-0000-0000-000000000003','cccccccc-0000-0000-0000-000000000003','2026-04-30 09:00:00+05', NULL,                    46.00,  NULL,   0.00,    NULL,'Active'),
  ('22222222-0000-0000-0000-000000000012', NULL,                                 'ffffffff-0000-0000-0000-000000000015','eeeeeeee-0000-0000-0000-000000000014','dddddddd-0000-0000-0000-000000000014','cccccccc-0000-0000-0000-000000000005','cccccccc-0000-0000-0000-000000000005','2026-05-02 11:00:00+05', NULL,                    37.00,  NULL,   0.00,    NULL,'Active');

-- 8.10 Payments (15 records)
INSERT INTO payment (contract_id, amount, payment_date, payment_method, status, transaction_id) VALUES
  ('22222222-0000-0000-0000-000000000001',118.00, '2026-05-10 13:00:00+05','Credit Card','Completed','TXN-20260510-001'),
  ('22222222-0000-0000-0000-000000000002',535.00, '2026-04-25 12:00:00+05','Debit Card', 'Completed','TXN-20260425-002'),
  ('22222222-0000-0000-0000-000000000003',174.00, '2026-04-18 10:00:00+05','Cash',       'Completed','TXN-20260418-003'),
  ('22222222-0000-0000-0000-000000000004',108.00, '2026-04-05 11:00:00+05','Online',     'Completed','TXN-20260405-004'),
  ('22222222-0000-0000-0000-000000000005',152.00, '2026-03-24 10:00:00+05','Credit Card','Completed','TXN-20260324-005'),
  ('22222222-0000-0000-0000-000000000006',188.00, '2026-04-14 09:00:00+05','Cash',       'Completed','TXN-20260414-006'),
  ('22222222-0000-0000-0000-000000000007',640.00, '2026-03-10 11:00:00+05','Bank Transfer','Completed','TXN-20260310-007'),
  -- Partial/advance payments for active contracts
  ('22222222-0000-0000-0000-000000000008', 50.00, '2026-05-03 10:30:00+05','Cash',       'Completed','TXN-20260503-008'),
  ('22222222-0000-0000-0000-000000000009',100.00, '2026-05-01 08:30:00+05','Credit Card','Completed','TXN-20260501-009'),
  ('22222222-0000-0000-0000-000000000010',200.00, '2026-04-28 10:30:00+05','Debit Card', 'Completed','TXN-20260428-010'),
  ('22222222-0000-0000-0000-000000000011', 90.00, '2026-04-30 09:30:00+05','Online',     'Completed','TXN-20260430-011'),
  ('22222222-0000-0000-0000-000000000012', 75.00, '2026-05-02 11:30:00+05','Cash',       'Completed','TXN-20260502-012'),
  -- Refunded payment example
  ('22222222-0000-0000-0000-000000000003', 50.00, '2026-04-19 10:00:00+05','Credit Card','Refunded', 'TXN-20260419-013'),
  ('22222222-0000-0000-0000-000000000002',100.00, '2026-04-26 10:00:00+05','Online',     'Completed','TXN-20260426-014'),
  ('22222222-0000-0000-0000-000000000007',150.00, '2026-03-11 09:00:00+05','Bank Transfer','Completed','TXN-20260311-015');

-- 8.11 Damage Reports (10 records)
INSERT INTO damage_report (vehicle_id, contract_id, reported_by, report_date, description, severity, repair_cost, status) VALUES
  ('eeeeeeee-0000-0000-0000-000000000007','22222222-0000-0000-0000-000000000002','dddddddd-0000-0000-0000-000000000005','2026-04-25','Front bumper scratch from parking lot',          'Minor',    150.00,'Resolved'),
  ('eeeeeeee-0000-0000-0000-000000000004','22222222-0000-0000-0000-000000000007','dddddddd-0000-0000-0000-000000000002','2026-03-10','Left door dent, paint damage',                    'Moderate', 850.00,'Resolved'),
  ('eeeeeeee-0000-0000-0000-000000000011','22222222-0000-0000-0000-000000000001','dddddddd-0000-0000-0000-000000000011','2026-05-10','Rear windshield crack',                            'Moderate',1200.00,'Under Repair'),
  ('eeeeeeee-0000-0000-0000-000000000003', NULL,                                'dddddddd-0000-0000-0000-000000000003','2026-05-01','Engine oil leak noticed during inspection',        'Severe',  2500.00,'Under Repair'),
  ('eeeeeeee-0000-0000-0000-000000000010','22222222-0000-0000-0000-000000000004','dddddddd-0000-0000-0000-000000000009','2026-04-05','Interior fabric tear on driver seat',             'Minor',    200.00,'Resolved'),
  ('eeeeeeee-0000-0000-0000-000000000015','22222222-0000-0000-0000-000000000006','dddddddd-0000-0000-0000-000000000015','2026-04-14','Side mirror broken',                              'Minor',    300.00,'Resolved'),
  ('eeeeeeee-0000-0000-0000-000000000013', NULL,                                'dddddddd-0000-0000-0000-000000000003','2026-04-20','Tyre blowout damage to wheel rim',                'Moderate', 600.00,'Reported'),
  ('eeeeeeee-0000-0000-0000-000000000005','22222222-0000-0000-0000-000000000005','dddddddd-0000-0000-0000-000000000005','2026-03-24','Minor paint chip on rear bumper',                  'Minor',     80.00,'Resolved'),
  ('eeeeeeee-0000-0000-0000-000000000002','22222222-0000-0000-0000-000000000005','dddddddd-0000-0000-0000-000000000002','2026-03-24','Headlight housing cracked',                        'Minor',    350.00,'Resolved'),
  ('eeeeeeee-0000-0000-0000-000000000008', NULL,                                'dddddddd-0000-0000-0000-000000000009','2026-05-03','Brake pad wear noticed, requires replacement',     'Moderate', 450.00,'Reported');

-- 8.12 Maintenance (12 records)
INSERT INTO maintenance (vehicle_id, branch_id, staff_id, maintenance_type, start_date, end_date, cost, description, status) VALUES
  ('eeeeeeee-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001','dddddddd-0000-0000-0000-000000000003','Oil Change',       '2026-01-10','2026-01-10', 35.00, 'Routine oil and filter change','Completed'),
  ('eeeeeeee-0000-0000-0000-000000000005','cccccccc-0000-0000-0000-000000000002','dddddddd-0000-0000-0000-000000000005','Tire Rotation',    '2026-02-05','2026-02-05', 40.00, 'Tire rotation and pressure check','Completed'),
  ('eeeeeeee-0000-0000-0000-000000000007','cccccccc-0000-0000-0000-000000000002','dddddddd-0000-0000-0000-000000000006','Full Service',     '2026-03-01','2026-03-03',320.00, 'Full A–Z service including filters and fluids','Completed'),
  ('eeeeeeee-0000-0000-0000-000000000003','cccccccc-0000-0000-0000-000000000001','dddddddd-0000-0000-0000-000000000003','Damage Repair',    '2026-05-02', NULL,       2500.00,'Fixing engine oil leak identified in damage report','In Progress'),
  ('eeeeeeee-0000-0000-0000-000000000008','cccccccc-0000-0000-0000-000000000003','dddddddd-0000-0000-0000-000000000009','Brake Service',    '2026-05-05','2026-05-06', 450.00,'Replace front and rear brake pads','In Progress'),
  ('eeeeeeee-0000-0000-0000-000000000010','cccccccc-0000-0000-0000-000000000003','dddddddd-0000-0000-0000-000000000009','Oil Change',       '2026-02-20','2026-02-20',  35.00,'Routine oil change','Completed'),
  ('eeeeeeee-0000-0000-0000-000000000013','cccccccc-0000-0000-0000-000000000004','dddddddd-0000-0000-0000-000000000003','Damage Repair',    '2026-04-22', NULL,         600.00,'Replace damaged wheel rim','Scheduled'),
  ('eeeeeeee-0000-0000-0000-000000000014','cccccccc-0000-0000-0000-000000000005','dddddddd-0000-0000-0000-000000000015','Engine Check',     '2026-01-15','2026-01-16', 180.00,'Full engine diagnostics','Completed'),
  ('eeeeeeee-0000-0000-0000-000000000009','cccccccc-0000-0000-0000-000000000003','dddddddd-0000-0000-0000-000000000009','Full Service',     '2026-04-01','2026-04-02', 290.00,'Routine full service for Tesla Model 3','Completed'),
  ('eeeeeeee-0000-0000-0000-000000000012','cccccccc-0000-0000-0000-000000000004','dddddddd-0000-0000-0000-000000000003','Oil Change',       '2026-03-10','2026-03-10',  35.00,'Routine oil change for Audi A6','Completed'),
  ('eeeeeeee-0000-0000-0000-000000000015','cccccccc-0000-0000-0000-000000000005','dddddddd-0000-0000-0000-000000000015','Tire Rotation',    '2026-02-28','2026-02-28',  40.00,'Tire rotation and pressure check','Completed'),
  ('eeeeeeee-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000001','dddddddd-0000-0000-0000-000000000003','Brake Service',    '2026-05-08','2026-05-09', 380.00,'Replace front brake pads, headlight housing fixed','Completed');

-- =============================================================
-- END OF MIGRATION SCRIPT
-- =============================================================
