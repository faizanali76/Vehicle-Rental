# 🚗 Vehicle Rental System — Full Implementation Plan

> **Stack:** Supabase (PostgreSQL) · Next.js 14 (App Router) · TypeScript · Tailwind CSS
> **DB File:** `schema_and_seed.sql` — paste once into Supabase SQL Editor to set up everything

---

## ✅ Schema Status — `schema_and_seed.sql`

| Requirement | Status |
|---|---|
| All 10 entities + `category`, `payment`, `audit_log` | ✅ |
| Primary keys (UUID), NOT NULL, UNIQUE, CHECK constraints | ✅ |
| Foreign keys with proper ON DELETE rules | ✅ |
| 15+ seed records per table | ✅ |
| 18 performance indexes | ✅ |
| 6 complex views | ✅ |
| BEFORE & AFTER triggers | ✅ |
| PL/pgSQL functions (package pattern) | ✅ |
| Explicit cursor function | ✅ |
| Custom composite types | ✅ |
| DCL: GRANT / REVOKE (3 roles) | ✅ |
| **Syntax bug on lines 374–401** | ✅ **FIXED** |

### Can You Paste the Whole File at Once in Supabase?
**Yes.** The bug has been fixed. Paste the entire file in Supabase SQL Editor and click **Run**. All DDL → indexes → views → triggers → functions → DCL → seed data will execute in one shot. If anything fails, the Output panel shows the exact line.

---

## Phase I — Conceptual & Logical Design

> **Deliverable:** ERD + EERD diagrams (PNG/PDF) + Normalization writeup

### Entity List & Primary Keys

| Entity | PK | Key Attributes |
|---|---|---|
| `category` | `category_id` | name, base_daily_rate |
| `model` | `model_id` | make, model_name, year, fuel_type, transmission |
| `branch` | `branch_id` | name, city, manager_id (FK → staff) |
| `staff` | `staff_id` | role, salary, hire_date |
| `vehicle` | `vehicle_id` | license_plate, vin, status, daily_rate |
| `insurance` | `insurance_id` | policy_number, coverage_type, end_date |
| `customer` | `customer_id` | driver_license_no, date_of_birth |
| `reservation` | `reservation_id` | pickup_date, return_date, status |
| `contract` | `contract_id` | agreed_daily_rate, total_amount, status |
| `payment` | `payment_id` | amount, payment_method, status |
| `damage_report` | `damage_id` | severity, repair_cost, status |
| `maintenance` | `maintenance_id` | maintenance_type, start_date, cost |
| `audit_log` | `log_id` | table_name, operation, old_data, new_data |

### Relationships (for ERD)

| From | Relationship | To | Cardinality |
|---|---|---|---|
| category | classifies | model | 1 : N |
| model | describes | vehicle | 1 : N |
| branch | houses | vehicle | 1 : N |
| branch | employs | staff | 1 : N |
| branch | managed by | staff (manager_id) | 1 : 1 |
| vehicle | covered by | insurance | 1 : N |
| customer | makes | reservation | 1 : N |
| vehicle | reserved in | reservation | 1 : N |
| branch | is pickup/return for | reservation | 1 : N |
| reservation | leads to | contract | 1 : 1 |
| customer | signs | contract | 1 : N |
| vehicle | rented in | contract | 1 : N |
| staff | processes | contract | 1 : N |
| contract | paid via | payment | 1 : N |
| vehicle | has | damage_report | 1 : N |
| contract | generates | damage_report | 1 : N |
| vehicle | undergoes | maintenance | 1 : N |
| staff | conducts | maintenance | 1 : N |

### EERD Features

| Feature | Where Applied |
|---|---|
| **Specialization** | `staff.role` → {Manager, Agent, Mechanic, Cleaner} — disjoint, total |
| **Generalization** | `category` generalizes vehicle type groups (Economy, SUV, Luxury…) |
| **Aggregation** | `contract` aggregates {reservation + vehicle + customer + staff} |

> **Recommended tool:** [dbdiagram.io](https://dbdiagram.io) — paste your DDL and it auto-generates an ERD you can export as PNG.

### Normalization Proof (3NF / BCNF)

**1NF:** All columns are atomic, no repeating groups, every table has a defined PK.

**2NF:** All non-key attributes depend on the *entire* PK (no partial dependencies).
- `model` stores make/year separately from `vehicle` — no partial dep.
- `category` keeps base pricing separate from `model`.

**3NF:** No transitive dependencies.
- `vehicle.daily_rate` is per-vehicle, not derived from `model`.
- `contract.agreed_daily_rate` is a snapshot — not transitively dependent on `vehicle.daily_rate`.
- `branch.city` is a direct attribute, not derived from another non-key.

**BCNF:** Every determinant is a candidate key.
- `insurance.policy_number` is UNIQUE → alternate candidate key → no BCNF violation.
- `customer.driver_license_no` is UNIQUE → alternate candidate key.

---

## Phase II — Implementation & Population

> **Deliverable:** Screenshots of table creation and DCL execution

### Steps After Running the Script

1. Run `schema_and_seed.sql` in Supabase SQL Editor → **Screenshot output**
2. Verify all tables:
   ```sql
   SELECT table_name
   FROM information_schema.tables
   WHERE table_schema = 'public'
   ORDER BY table_name;
   ```
3. Verify row counts (minimum 10–15 per table):
   ```sql
   SELECT 'category'     AS tbl, COUNT(*) FROM category
   UNION ALL SELECT 'model',         COUNT(*) FROM model
   UNION ALL SELECT 'branch',        COUNT(*) FROM branch
   UNION ALL SELECT 'staff',         COUNT(*) FROM staff
   UNION ALL SELECT 'vehicle',       COUNT(*) FROM vehicle
   UNION ALL SELECT 'customer',      COUNT(*) FROM customer
   UNION ALL SELECT 'reservation',   COUNT(*) FROM reservation
   UNION ALL SELECT 'contract',      COUNT(*) FROM contract
   UNION ALL SELECT 'payment',       COUNT(*) FROM payment
   UNION ALL SELECT 'damage_report', COUNT(*) FROM damage_report
   UNION ALL SELECT 'maintenance',   COUNT(*) FROM maintenance
   UNION ALL SELECT 'insurance',     COUNT(*) FROM insurance;
   ```
4. Screenshot the GRANT / REVOKE section output → paste into report

---

## Phase III — Advanced SQL Operations

> Save as `phase3_queries.sql` → add to report appendix

### 3.1 Joins

```sql
-- INNER JOIN: Vehicles with their model, category, and branch
SELECT
    v.license_plate,
    m.make,
    m.model_name,
    c.name        AS category,
    b.name        AS branch,
    v.daily_rate,
    v.status
FROM vehicle v
INNER JOIN model    m ON v.model_id    = m.model_id
INNER JOIN category c ON m.category_id = c.category_id
INNER JOIN branch   b ON v.branch_id   = b.branch_id;

-- LEFT OUTER JOIN: All customers including those with no rentals
SELECT
    cu.first_name,
    cu.last_name,
    cu.email,
    COUNT(ct.contract_id) AS total_contracts,
    COALESCE(SUM(ct.total_amount), 0) AS total_spent
FROM customer cu
LEFT JOIN contract ct ON cu.customer_id = ct.customer_id
GROUP BY cu.customer_id, cu.first_name, cu.last_name, cu.email
ORDER BY total_contracts DESC;

-- RIGHT OUTER JOIN: All branches and their contracts (including branches with none)
SELECT
    b.name AS branch_name,
    b.city,
    ct.contract_id,
    ct.status,
    ct.total_amount
FROM contract ct
RIGHT JOIN branch b ON ct.pickup_branch_id = b.branch_id;

-- FULL OUTER JOIN: All vehicles and their maintenance records
SELECT
    v.license_plate,
    m.maintenance_type,
    m.status     AS maintenance_status,
    m.cost,
    m.start_date
FROM vehicle v
FULL OUTER JOIN maintenance m ON v.vehicle_id = m.vehicle_id;
```

### 3.2 Set Operations

```sql
-- UNION: All contact emails across customers and staff
SELECT email, 'Customer' AS role FROM customer
UNION
SELECT email, 'Staff'    AS role FROM staff
ORDER BY role, email;

-- INTERSECT: Vehicles that have BOTH a damage report AND a maintenance record
SELECT vehicle_id FROM damage_report
INTERSECT
SELECT vehicle_id FROM maintenance;

-- EXCEPT (MINUS in PostgreSQL): Vehicles that have NEVER been rented
SELECT vehicle_id, license_plate FROM vehicle
EXCEPT
SELECT v.vehicle_id, v.license_plate
FROM vehicle v
INNER JOIN contract ct ON v.vehicle_id = ct.vehicle_id;
```

### 3.3 Subqueries

```sql
-- Non-correlated: Customers who spent more than the overall average
SELECT first_name, last_name, total_spent
FROM vw_customer_history
WHERE total_spent > (
    SELECT AVG(total_amount) FROM contract WHERE status = 'Closed'
)
ORDER BY total_spent DESC;

-- Correlated: Vehicles priced above their category's average daily rate
SELECT v.license_plate, v.daily_rate, m.make, m.model_name, c.name AS category
FROM vehicle v
JOIN model    m ON v.model_id    = m.model_id
JOIN category c ON m.category_id = c.category_id
WHERE v.daily_rate > (
    SELECT AVG(v2.daily_rate)
    FROM vehicle v2
    JOIN model m2 ON v2.model_id = m2.model_id
    WHERE m2.category_id = m.category_id
);

-- EXISTS subquery: Branches that have at least one active contract right now
SELECT name, city FROM branch b
WHERE EXISTS (
    SELECT 1 FROM contract ct
    WHERE ct.pickup_branch_id = b.branch_id
      AND ct.status = 'Active'
);

-- NOT EXISTS: Vehicles with no reservations at all
SELECT vehicle_id, license_plate FROM vehicle v
WHERE NOT EXISTS (
    SELECT 1 FROM reservation r WHERE r.vehicle_id = v.vehicle_id
);
```

### 3.4 Index Explanation (for Report)

| Index | Column(s) | Why |
|---|---|---|
| `idx_vehicle_status` | `vehicle.status` | Most common filter — fleet availability |
| `idx_vehicle_branch` | `vehicle.branch_id` | Filter vehicles per branch |
| `idx_reservation_dates` | `pickup_date, return_date` | Speeds up OVERLAPS check for double-booking |
| `idx_contract_dates` | `actual_pickup_date, actual_return_date` | Revenue reports, overdue detection |
| `idx_payment_contract` | `payment.contract_id` | Join from contract to payments |
| `idx_audit_log_table` | `table_name, changed_at` | Audit trail queries by table + time |

---

## Phase IV — PL/SQL (All Already in the Script)

### What's Implemented & Where

| Requirement | Function / Trigger in Script | Business Logic |
|---|---|---|
| **Package (rental_ops)** | `rental_ops_create_reservation()` | Validates availability, calculates cost, inserts reservation |
| **Package (rental_ops)** | `rental_ops_close_contract()` | Calculates final bill (days × rate + extra charges), closes contract |
| **Package (fleet_ops)** | `fleet_ops_available_vehicles()` | Returns vehicles free for a given date range + branch filter |
| **Package (fleet_ops)** | `fleet_ops_branch_revenue()` | Monthly revenue report per branch over a date range |
| **Explicit Cursor** | `rental_ops_flag_overdue_contracts()` | FETCH loop — flags Active contracts > 30 days as Disputed |
| **BEFORE Trigger** | `trg_contract_vehicle_status` | Sets vehicle → 'Rented' on INSERT; calculates amounts on UPDATE (close) |
| **BEFORE Trigger** | `trg_prevent_double_booking` | Raises EXCEPTION if reservation overlaps an existing one |
| **AFTER Trigger** | `trg_audit_contract/reservation/payment` | Writes INSERT/UPDATE/DELETE to audit_log automatically |
| **AFTER Trigger** | `trg_sync_reservation_on_close` | Marks linked reservation → 'Completed' when contract closes |
| **AFTER Trigger** | `trg_maintenance_vehicle_status` | Sets vehicle → 'Maintenance' / 'Available' based on job status |
| **Custom Type** | `vehicle_summary_t` | Composite type for vehicle display info |
| **Custom Type** | `rental_invoice_t` | Composite type for full rental invoice |
| **Type Function** | `get_rental_invoice(UUID)` | Returns `rental_invoice_t` for a given contract |

### Cursor Logic Explained (for Report)

```sql
-- rental_ops_flag_overdue_contracts uses an EXPLICIT CURSOR:
DECLARE
    cur_overdue CURSOR FOR
        SELECT ct.contract_id, cu.first_name || ' ' || cu.last_name, ...
        FROM contract ct JOIN customer cu ...
        WHERE ct.status = 'Active' AND ct.actual_pickup_date < NOW() - INTERVAL '30 days';
    rec RECORD;
BEGIN
    OPEN cur_overdue;
    LOOP
        FETCH cur_overdue INTO rec;
        EXIT WHEN NOT FOUND;
        UPDATE contract SET status = 'Disputed' WHERE contract_id = rec.contract_id;
        RETURN NEXT;
    END LOOP;
    CLOSE cur_overdue;
END;
```

---

## Next.js Frontend Build Plan

### 1. Initial Setup

```bash
# Run inside: d:\PP\Vehicle Rental
npx create-next-app@latest . --typescript --tailwind --app --no-src-dir --import-alias "@/*" --yes
npm install @supabase/supabase-js @supabase/ssr recharts lucide-react
```

**Create `.env.local`:**
```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

### 2. Project File Structure

```
d:\PP\Vehicle Rental\
├── app/
│   ├── layout.tsx                    # Root layout + sidebar
│   ├── page.tsx                      # Dashboard (KPIs + charts)
│   ├── vehicles/
│   │   ├── page.tsx                  # Fleet list with status filter
│   │   ├── new/page.tsx              # Add vehicle form
│   │   └── [id]/page.tsx            # Vehicle detail + insurance
│   ├── customers/
│   │   ├── page.tsx                  # Customer list + search
│   │   ├── new/page.tsx              # Register customer
│   │   └── [id]/page.tsx            # Customer profile + rental history
│   ├── reservations/
│   │   ├── page.tsx                  # All reservations table
│   │   └── new/page.tsx             # New reservation (RPC search + book)
│   ├── contracts/
│   │   ├── page.tsx                  # Contracts table (Active / Closed)
│   │   └── [id]/page.tsx            # Contract detail + close + invoice
│   ├── payments/
│   │   └── page.tsx                  # Payment history
│   ├── maintenance/
│   │   ├── page.tsx                  # Maintenance jobs list
│   │   └── new/page.tsx             # Log new job
│   ├── damage-reports/
│   │   ├── page.tsx                  # Damage reports list
│   │   └── new/page.tsx             # File a report
│   ├── branches/
│   │   └── page.tsx                  # Branch overview + staff
│   ├── reports/
│   │   └── page.tsx                  # Revenue + fleet analytics
│   └── api/
│       ├── vehicles/route.ts
│       ├── customers/route.ts
│       ├── reservations/route.ts
│       ├── contracts/route.ts
│       ├── contracts/[id]/close/route.ts
│       ├── payments/route.ts
│       ├── maintenance/route.ts
│       └── damage-reports/route.ts
├── lib/
│   ├── supabase/
│   │   ├── client.ts                 # Browser client
│   │   └── server.ts                 # Server client (API routes)
│   └── types.ts                      # TypeScript DB types
└── components/
    ├── ui/
    │   ├── DataTable.tsx
    │   ├── StatusBadge.tsx
    │   └── Modal.tsx
    ├── Sidebar.tsx
    └── charts/
        └── RevenueChart.tsx
```

### 3. Supabase Client Setup

**`lib/supabase/client.ts`**
```typescript
import { createBrowserClient } from '@supabase/ssr'

export const createClient = () =>
  createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
```

**`lib/supabase/server.ts`**
```typescript
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export const createClient = () => {
  const cookieStore = cookies()
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: { getAll: () => cookieStore.getAll() } }
  )
}
```

### 4. Standard API Route Pattern

```typescript
// app/api/vehicles/route.ts
import { createClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

// GET — list all vehicles with joined model, category, branch
export async function GET() {
  const supabase = createClient()
  const { data, error } = await supabase
    .from('vehicle')
    .select(`
      *,
      model (make, model_name, year, fuel_type, transmission,
        category (name)),
      branch (name, city)
    `)
    .order('created_at', { ascending: false })

  if (error) return NextResponse.json({ error }, { status: 500 })
  return NextResponse.json(data)
}

// POST — add a new vehicle
export async function POST(req: Request) {
  const supabase = createClient()
  const body = await req.json()
  const { data, error } = await supabase
    .from('vehicle').insert(body).select().single()

  if (error) return NextResponse.json({ error }, { status: 400 })
  return NextResponse.json(data, { status: 201 })
}
```

### 5. Calling Stored Functions (RPC)

```typescript
// Search available vehicles for a date range
const { data: available } = await supabase.rpc('fleet_ops_available_vehicles', {
  p_pickup_date: '2026-05-10T10:00:00+05',
  p_return_date: '2026-05-13T10:00:00+05',
  p_branch_id: null   // null = all branches
})

// Create a reservation
const { data: reservationId } = await supabase.rpc('rental_ops_create_reservation', {
  p_customer_id:   customerId,
  p_vehicle_id:    vehicleId,
  p_pickup_branch: pickupBranchId,
  p_return_branch: returnBranchId,
  p_pickup_date:   pickupDate,
  p_return_date:   returnDate
})

// Close a contract and get the final amount
const { data: totalAmount } = await supabase.rpc('rental_ops_close_contract', {
  p_contract_id:        contractId,
  p_actual_return_date: returnDate,
  p_additional_charges: 50.00
})

// Get a rental invoice (custom type)
const { data: invoice } = await supabase.rpc('get_rental_invoice', {
  p_contract_id: contractId
})

// Revenue report for a branch
const { data: revenue } = await supabase.rpc('fleet_ops_branch_revenue', {
  p_branch_id: branchId,
  p_from_date: '2026-01-01',
  p_to_date:   '2026-12-31'
})
```

### 6. Dashboard Queries

```typescript
// Available vehicles count
const { count: availableCount } = await supabase
  .from('vehicle').select('*', { count: 'exact', head: true })
  .eq('status', 'Available')

// Active contracts count
const { count: activeContracts } = await supabase
  .from('contract').select('*', { count: 'exact', head: true })
  .eq('status', 'Active')

// Revenue by branch (from view)
const { data: branchRevenue } = await supabase
  .from('vw_branch_revenue').select('*')

// Vehicles due for maintenance (from view)
const { data: dueMaintenance } = await supabase
  .from('vw_vehicles_due_maintenance').select('*').limit(5)

// Insurance expiring soon (from view)
const { data: expiringInsurance } = await supabase
  .from('vw_insurance_expiry')
  .neq('expiry_status', 'Active')
  .limit(5)
```

### 7. CRUD Coverage

| Entity | Create | Read | Update | Delete |
|---|---|---|---|---|
| vehicle | ✅ form | ✅ list + detail | ✅ status / mileage | ✅ retire (status=Retired) |
| customer | ✅ form | ✅ list + profile | ✅ edit info | ❌ restricted |
| reservation | ✅ RPC | ✅ table | ✅ cancel | ❌ |
| contract | ✅ form | ✅ table + detail | ✅ close (RPC) | ❌ |
| payment | ✅ form | ✅ history | ✅ refund status | ❌ |
| maintenance | ✅ form | ✅ list | ✅ status update | ❌ |
| damage_report | ✅ form | ✅ list | ✅ resolve status | ❌ |
| insurance | ✅ form | ✅ list | ✅ renew | ❌ |
| branch | ✅ | ✅ | ✅ | ❌ |
| staff | ✅ | ✅ | ✅ | ❌ deactivate flag |

---

## Submission Deliverables Checklist

| Deliverable | Format | Status |
|---|---|---|
| ERD diagram | PNG / PDF | ⬜ Draw in dbdiagram.io |
| EERD diagram | PNG / PDF | ⬜ Add specialization/aggregation |
| Normalization writeup (1NF→BCNF) | PDF section | ⬜ Use tables from Phase I above |
| `schema_and_seed.sql` | `.sql` | ✅ Fixed and ready |
| `phase3_queries.sql` | `.sql` | ⬜ Copy queries from Phase III |
| Screenshot: table creation output | PNG | ⬜ After Supabase run |
| Screenshot: DCL (GRANT/REVOKE) | PNG | ⬜ After Supabase run |
| Working Next.js frontend | Zip / Link | ⬜ Build per plan |
| Final project report PDF | PDF | ⬜ Assemble everything |

---

## Recommended Build Order

```
Day 1  →  Run fixed schema_and_seed.sql in Supabase → verify counts → take screenshots
Day 2  →  npx create-next-app → setup Supabase clients → test a basic query
Day 3  →  Dashboard page (KPI cards + vw_branch_revenue chart)
Day 4  →  Vehicles page (list, filter by status/branch, add vehicle)
Day 5  →  Customers page + New reservation form (RPC: fleet_ops_available_vehicles)
Day 6  →  Contracts page + close-contract flow (RPC) + invoice view
Day 7  →  Payments + Maintenance + Damage Reports pages
Day 8  →  Branches + Staff pages + Reports/analytics page
Day 9  →  Draw ERD + EERD in dbdiagram.io → write normalization section
Day 10 →  Screenshot all SQL execution → assemble final PDF report
```
