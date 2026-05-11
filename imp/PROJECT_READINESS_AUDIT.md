# Vehicle Rental System - Project Readiness Audit

## Overall Status

The project is ready for viva after running `supplemental_seed_min_counts.sql` on the already-created Supabase database. The main schema file has also been updated so a fresh setup satisfies the data population requirement.

## Phase I: Conceptual and Logical Design

| Requirement | Status | Evidence |
|---|---|---|
| ERD | Complete | User-created ERD: `vehicle_rental_erd.drawio` |
| EERD | Complete | `imp/vehicle_rental_eerd.drawio` |
| Specialization | Complete | Staff specializes into Manager, Agent, Mechanic, Cleaner |
| Generalization | Complete | Category generalizes rental classes such as Economy, Sedan, SUV, Luxury |
| Aggregation | Complete | Contract aggregates reservation, customer, vehicle, staff, branches, dates, and billing |
| Relational schema | Complete | `schema_and_seed.sql`, `DESIGN_DOCUMENT.md` |
| Normalization up to 3NF/BCNF | Complete | `Phase_I_Normalization_Document.docx` |

## Phase II: Implementation and Population

| Requirement | Status | Evidence |
|---|---|---|
| DDL tables | Complete | 13 tables in `schema_and_seed.sql` |
| Primary keys | Complete | UUID primary keys on all tables |
| Foreign keys | Complete | Relationships across category, model, vehicle, branch, staff, customer, reservation, contract, payment, maintenance, insurance, damage report |
| NOT NULL constraints | Complete | Required attributes use NOT NULL |
| UNIQUE constraints | Complete | email, VIN, license plate, policy number, transaction ID, model natural key |
| CHECK constraints | Complete | dates, status values, payment methods, positive money values, age rule |
| DCL | Complete | roles: rental_readonly, rental_agent, rental_manager with GRANT/REVOKE |
| Data population | Complete after supplemental seed | Most tables have 10-15 rows; supplemental seed raises category and branch to 10 |

## Phase III: Advanced SQL Operations

| Requirement | Status | Evidence |
|---|---|---|
| Inner join | Complete | `phase3_queries.sql` |
| Left outer join | Complete | `phase3_queries.sql` |
| Right outer join | Complete | `phase3_queries.sql` |
| Full outer join | Complete | `phase3_queries.sql` |
| UNION | Complete | `phase3_queries.sql` |
| INTERSECT | Complete | `phase3_queries.sql` |
| MINUS equivalent | Complete | PostgreSQL `EXCEPT` query in `phase3_queries.sql` |
| Correlated subquery | Complete | category average vehicle price query |
| Non-correlated subquery | Complete | above-average customer spending query |
| Indexing | Complete | 21 indexes in `schema_and_seed.sql` |

## Phase IV: Programming and Automation

| Requirement | Status | Evidence |
|---|---|---|
| Blocks/named routines | Complete | PL/pgSQL functions in `schema_and_seed.sql` and `phase4_plpgsql_module.sql` |
| Packages | Adapted for PostgreSQL | Supabase PostgreSQL does not support Oracle package spec/body; package-style prefixes `rental_ops_*` and `fleet_ops_*` are used |
| Explicit cursor | Complete | `rental_ops_flag_overdue_contracts()` |
| Triggers | Complete | audit, double-booking prevention, vehicle status sync, reservation sync |
| Object types | Complete for PostgreSQL | composite types `vehicle_summary_t` and `rental_invoice_t` |
| Type bodies | Adapted for PostgreSQL | PostgreSQL has composite types plus functions, not Oracle type bodies |

## Frontend Requirement

| Requirement | Status | Evidence |
|---|---|---|
| Working frontend | Complete | Next.js app connected to Supabase |
| CRUD operations | Complete | Create, read, update, and business-delete actions in CRUD tab |
| Views for frontend | Complete | Dashboard and SQL Views tab read database views |
| Business logic through DB | Complete | Reservation create and contract close call DB RPC functions |

## Important Viva Note

This project uses Supabase PostgreSQL, so the procedural language is PL/pgSQL, not Oracle PL/SQL. If asked about packages and type bodies, explain that PostgreSQL does not provide Oracle-style package spec/body or type body syntax. The equivalent design used here is grouped function naming (`rental_ops_*`, `fleet_ops_*`) plus composite object types and functions returning those types.
