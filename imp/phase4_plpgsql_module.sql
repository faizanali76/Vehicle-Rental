-- =============================================================
-- VEHICLE RENTAL SYSTEM - PHASE IV PL/pgSQL MODULE
-- Database: Supabase PostgreSQL
-- Note: Supabase uses PostgreSQL PL/pgSQL rather than Oracle PL/SQL.
-- Package requirement is implemented with package-style prefixes:
--   rental_ops_* for reservation/contract business routines
--   fleet_ops_*  for fleet reporting routines
-- =============================================================

-- -------------------------------------------------------------
-- 1. Package-style routine: rental_ops_create_reservation
-- Business problem: prevent invalid bookings and calculate amount.
-- -------------------------------------------------------------
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
    SELECT status, daily_rate
    INTO v_vehicle_status, v_daily_rate
    FROM vehicle
    WHERE vehicle_id = p_vehicle_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vehicle not found: %', p_vehicle_id;
    END IF;

    IF v_vehicle_status != 'Available' THEN
        RAISE EXCEPTION 'Vehicle is not available. Current status: %', v_vehicle_status;
    END IF;

    v_days := EXTRACT(EPOCH FROM (p_return_date - p_pickup_date)) / 86400;
    v_total := v_daily_rate * v_days;

    INSERT INTO reservation (
        customer_id, vehicle_id, pickup_branch_id, return_branch_id,
        pickup_date, return_date, status, total_amount
    )
    VALUES (
        p_customer_id, p_vehicle_id, p_pickup_branch, p_return_branch,
        p_pickup_date, p_return_date, 'Confirmed', v_total
    )
    RETURNING reservation_id INTO v_reservation_id;

    RETURN v_reservation_id;
END;
$$;

-- -------------------------------------------------------------
-- 2. Package-style routine: rental_ops_close_contract
-- Business problem: close a contract atomically and calculate final bill.
-- -------------------------------------------------------------
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
    SELECT * INTO v_contract
    FROM contract
    WHERE contract_id = p_contract_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Contract not found: %', p_contract_id;
    END IF;

    IF v_contract.status != 'Active' THEN
        RAISE EXCEPTION 'Contract is not active. Status: %', v_contract.status;
    END IF;

    v_days := GREATEST(1, EXTRACT(DAY FROM (p_actual_return_date - v_contract.actual_pickup_date)));
    v_base_amount := v_contract.agreed_daily_rate * v_days;
    v_total := v_base_amount + p_additional_charges;

    UPDATE contract
    SET actual_return_date = p_actual_return_date,
        base_amount = v_base_amount,
        additional_charges = p_additional_charges,
        total_amount = v_total,
        status = 'Closed'
    WHERE contract_id = p_contract_id;

    RETURN v_total;
END;
$$;

-- -------------------------------------------------------------
-- 3. Explicit cursor routine
-- Business problem: find long-running active contracts and flag them.
-- -------------------------------------------------------------
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

        UPDATE contract
        SET status = 'Disputed'
        WHERE contract.contract_id = rec.contract_id;

        contract_id := rec.contract_id;
        customer_name := rec.customer_name;
        days_overdue := rec.days_overdue;
        RETURN NEXT;
    END LOOP;
    CLOSE cur_overdue;
END;
$$;

-- -------------------------------------------------------------
-- 4. Fleet package-style functions
-- -------------------------------------------------------------
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
        v.vehicle_id,
        v.license_plate::TEXT,
        m.make::TEXT,
        m.model_name::TEXT,
        m.year,
        v.daily_rate,
        b.name::TEXT
    FROM vehicle v
    JOIN model m ON v.model_id = m.model_id
    JOIN branch b ON v.branch_id = b.branch_id
    WHERE v.status = 'Available'
      AND (p_branch_id IS NULL OR v.branch_id = p_branch_id)
      AND v.vehicle_id NOT IN (
          SELECT r.vehicle_id
          FROM reservation r
          WHERE r.status IN ('Pending', 'Confirmed')
            AND (r.pickup_date, r.return_date) OVERLAPS (p_pickup_date, p_return_date)
      );
END;
$$;

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
        COUNT(*) AS total_contracts,
        COALESCE(SUM(ct.total_amount), 0) AS total_revenue,
        AVG(EXTRACT(DAY FROM (ct.actual_return_date - ct.actual_pickup_date))) AS avg_days
    FROM contract ct
    WHERE ct.pickup_branch_id = p_branch_id
      AND ct.status = 'Closed'
      AND ct.actual_pickup_date::DATE BETWEEN p_from_date AND p_to_date
    GROUP BY DATE_TRUNC('month', ct.actual_pickup_date)
    ORDER BY DATE_TRUNC('month', ct.actual_pickup_date);
END;
$$;

-- -------------------------------------------------------------
-- 5. Trigger functions and triggers
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_audit_trigger()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_record_id UUID;
BEGIN
    v_record_id := COALESCE(NEW.contract_id, NEW.reservation_id, NEW.payment_id, OLD.contract_id, OLD.reservation_id, OLD.payment_id);

    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log(table_name, operation, record_id, new_data)
        VALUES (TG_TABLE_NAME, 'INSERT', v_record_id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log(table_name, operation, record_id, old_data, new_data)
        VALUES (TG_TABLE_NAME, 'UPDATE', v_record_id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSE
        INSERT INTO audit_log(table_name, operation, record_id, old_data)
        VALUES (TG_TABLE_NAME, 'DELETE', v_record_id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION fn_prevent_double_booking()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_conflict_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_conflict_count
    FROM reservation r
    WHERE r.vehicle_id = NEW.vehicle_id
      AND r.reservation_id <> COALESCE(NEW.reservation_id, uuid_nil())
      AND r.status IN ('Pending', 'Confirmed')
      AND (r.pickup_date, r.return_date) OVERLAPS (NEW.pickup_date, NEW.return_date);

    IF v_conflict_count > 0 THEN
        RAISE EXCEPTION 'Vehicle already has an overlapping reservation.';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION fn_sync_reservation_on_close()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = 'Closed' AND OLD.status <> 'Closed' AND NEW.reservation_id IS NOT NULL THEN
        UPDATE reservation
        SET status = 'Completed'
        WHERE reservation_id = NEW.reservation_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_double_booking ON reservation;
CREATE TRIGGER trg_prevent_double_booking
BEFORE INSERT OR UPDATE ON reservation
FOR EACH ROW EXECUTE FUNCTION fn_prevent_double_booking();

DROP TRIGGER IF EXISTS trg_audit_contract ON contract;
CREATE TRIGGER trg_audit_contract
AFTER INSERT OR UPDATE OR DELETE ON contract
FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_reservation ON reservation;
CREATE TRIGGER trg_audit_reservation
AFTER INSERT OR UPDATE OR DELETE ON reservation
FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_payment ON payment;
CREATE TRIGGER trg_audit_payment
AFTER INSERT OR UPDATE OR DELETE ON payment
FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_sync_reservation_on_close ON contract;
CREATE TRIGGER trg_sync_reservation_on_close
AFTER UPDATE ON contract
FOR EACH ROW EXECUTE FUNCTION fn_sync_reservation_on_close();

-- -------------------------------------------------------------
-- 6. Object-oriented database feature: composite object types
-- -------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'vehicle_summary_t') THEN
        CREATE TYPE vehicle_summary_t AS (
            vehicle_id    UUID,
            display_name  TEXT,
            license_plate TEXT,
            daily_rate    DECIMAL(10,2),
            status        TEXT,
            branch        TEXT
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rental_invoice_t') THEN
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
    END IF;
END $$;

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
    JOIN vehicle v ON ct.vehicle_id = v.vehicle_id
    JOIN model m ON v.model_id = m.model_id
    WHERE ct.contract_id = p_contract_id;

    RETURN v_invoice;
END;
$$;

-- -------------------------------------------------------------
-- 7. Verification calls for screenshots
-- -------------------------------------------------------------
SELECT * FROM fleet_ops_available_vehicles(
    NOW(),
    NOW() + INTERVAL '2 days',
    NULL
);

SELECT * FROM rental_ops_flag_overdue_contracts();
