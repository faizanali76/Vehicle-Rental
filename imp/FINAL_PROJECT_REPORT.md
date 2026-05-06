# Vehicle Rental Database System

## 1. Title Page and Introduction

Project title: Vehicle Rental Database System  
Database platform: Supabase PostgreSQL  
Frontend stack: Next.js, TypeScript, Tailwind CSS, lucide-react  

The objective of this project is to design and implement a complete database system for a vehicle rental company. The database is the central deliverable. The frontend exists to prove that the schema, constraints, views, functions, triggers, and CRUD operations work in a usable application.

## 2. SRS Document

### Functional Requirements

1. The system shall store vehicle categories, models, vehicles, branches, staff, customers, reservations, contracts, payments, maintenance jobs, insurance policies, damage reports, and audit logs.
2. The system shall allow staff to create and update customers, vehicles, reservations, contracts, payments, maintenance records, damage reports, insurance policies, branches, categories, and models.
3. The system shall prevent invalid reservation date ranges.
4. The system shall prevent double booking for overlapping reservations.
5. The system shall calculate reservation totals and final contract totals.
6. The system shall track branch revenue, customer rental history, active contracts, available vehicles, maintenance due, and insurance expiry.
7. The system shall keep an audit trail for reservation, contract, and payment changes.
8. The frontend shall provide working CRUD-style operations against the Supabase database.

### System Requirements

1. The database shall enforce primary keys, foreign keys, NOT NULL, UNIQUE, and CHECK constraints.
2. The database shall use indexes on frequent search and join columns.
3. Business operations shall be atomic through stored database routines.
4. Privileges shall be separated using rental_readonly, rental_agent, and rental_manager roles.
5. The application shall use server-side Supabase access for protected operations.

## 3. Design Diagrams and Normalized Schema

See `imp/DESIGN_DOCUMENT.md` for the ERD/EERD source, relationship summary, and normalization proof through BCNF.

Key normalized tables:

| Table | Main Role |
|---|---|
| category | Stores rental class and base pricing |
| model | Stores reusable vehicle model information |
| vehicle | Stores individual vehicle units |
| branch | Stores rental locations |
| staff | Stores employees and role specialization |
| customer | Stores licensed renters |
| reservation | Stores pre-contract bookings |
| contract | Stores signed rentals and final billing |
| payment | Stores contract payments |
| maintenance | Stores service jobs |
| insurance | Stores policies |
| damage_report | Stores vehicle damage cases |
| audit_log | Stores trigger-written history |

## 4. Implementation Logs

Run `imp/schema_and_seed.sql` in Supabase SQL Editor. Take screenshots for these commands:

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
```

```sql
SELECT 'category' AS table_name, COUNT(*) FROM category
UNION ALL SELECT 'model', COUNT(*) FROM model
UNION ALL SELECT 'branch', COUNT(*) FROM branch
UNION ALL SELECT 'staff', COUNT(*) FROM staff
UNION ALL SELECT 'vehicle', COUNT(*) FROM vehicle
UNION ALL SELECT 'insurance', COUNT(*) FROM insurance
UNION ALL SELECT 'customer', COUNT(*) FROM customer
UNION ALL SELECT 'reservation', COUNT(*) FROM reservation
UNION ALL SELECT 'contract', COUNT(*) FROM contract
UNION ALL SELECT 'payment', COUNT(*) FROM payment
UNION ALL SELECT 'damage_report', COUNT(*) FROM damage_report
UNION ALL SELECT 'maintenance', COUNT(*) FROM maintenance
UNION ALL SELECT 'audit_log', COUNT(*) FROM audit_log;
```

DCL proof:

```sql
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('rental_readonly', 'rental_agent', 'rental_manager')
ORDER BY grantee, table_name, privilege_type;
```

## 5. Code Appendix

| File | Purpose |
|---|---|
| `imp/schema_and_seed.sql` | Full migration: DDL, DCL, constraints, indexes, views, triggers, functions, seed data |
| `imp/phase3_queries.sql` | Advanced SQL joins, set operations, subqueries, and performance proof |
| `imp/phase4_plpgsql_module.sql` | PL/pgSQL routines, cursor, triggers, and composite object types |
| `lib/data.ts` | Server-side Supabase reads for dashboard and reports |
| `app/api/admin/[resource]/route.ts` | CRUD and RPC-backed API operations |
| `components/AppShell.tsx` | Working frontend console |

## 6. Frontend Overview

The Next.js frontend connects to Supabase using environment variables in `.env.local`. The app displays database counts, branch revenue, available vehicles, due maintenance, insurance expiry, audit logs, and advanced SQL views. The CRUD console supports create, read, update, and business-delete actions for the major database entities.

Reservation creation calls `rental_ops_create_reservation`, so booking validation and total calculation happen inside the database. Contract closing calls `rental_ops_close_contract`, so final billing and status updates are atomic.

## 7. Phase Completion Checklist

| Requirement | Status |
|---|---|
| ERD/EERD design | Covered in `DESIGN_DOCUMENT.md`; export diagram from Mermaid |
| 3NF/BCNF proof | Covered in `DESIGN_DOCUMENT.md` |
| DDL and DCL | Implemented in `schema_and_seed.sql` |
| Data population | Implemented in `schema_and_seed.sql` |
| Joins | Implemented in `phase3_queries.sql` |
| Set operations | Implemented in `phase3_queries.sql` |
| Subqueries | Implemented in `phase3_queries.sql` |
| Indexing | Implemented in `schema_and_seed.sql`, verified in `phase3_queries.sql` |
| Views | Implemented in `schema_and_seed.sql` and displayed in frontend |
| Packages/routines | Implemented with package-style PL/pgSQL prefixes |
| Explicit cursor | Implemented in `rental_ops_flag_overdue_contracts` |
| Triggers | Implemented for audit, validation, sync, and status automation |
| Object types | Implemented with `vehicle_summary_t` and `rental_invoice_t` |
| CRUD frontend | Implemented in Next.js frontend |

## 8. Conclusion

The project implements a complete vehicle rental database system with strong data integrity, normalized schema design, seeded data, advanced SQL operations, procedural database automation, and a working frontend connected to Supabase.
