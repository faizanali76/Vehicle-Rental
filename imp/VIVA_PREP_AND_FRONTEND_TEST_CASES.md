# Vehicle Rental System - Viva Preparation and Frontend Test Cases

## 1. One-Minute Project Explanation

This is a full database system for a vehicle rental company. The database stores vehicle categories, models, physical vehicles, branches, staff, customers, reservations, contracts, payments, insurance, maintenance, damage reports, and audit logs. The frontend is a Next.js dashboard connected to Supabase PostgreSQL. Most grading weight is in the database: constraints, normalization, views, indexes, triggers, stored routines, cursor logic, and object-like composite types.

## 2. Database Flow

1. Category defines rental class and base pricing.
2. Model belongs to category and stores make/model/year/fuel/transmission.
3. Vehicle belongs to model and branch; it is the physical rentable car.
4. Branch is a rental location.
5. Staff belongs to branch and has a specialized role: Manager, Agent, Mechanic, Cleaner.
6. Customer stores renter and license details.
7. Reservation is a pre-booking between customer and vehicle for dates.
8. Contract is the signed rental transaction. It aggregates customer, vehicle, staff, branches, dates, and rates.
9. Payment belongs to contract.
10. Maintenance and damage_report track operational issues.
11. Audit_log stores trigger-generated change history.

## 3. Normalization Answer

The schema is normalized to BCNF.

1NF: All values are atomic and repeating groups are separated. For example, payments are not stored as payment1/payment2 columns; they are separate rows in the payment table.

2NF: Every non-key attribute depends on the whole key. Since each table has a single UUID primary key, partial dependency is avoided. Model information is separated from vehicle, and category information is separated from model.

3NF: There are no transitive dependencies. Branch address and city are stored in branch, not in contract. Customer license details are stored in customer, not repeated in reservation or contract.

BCNF: Every determinant is a candidate key. Alternate determinants such as vehicle.license_plate, vehicle.vin, customer.email, customer.driver_license_no, insurance.policy_number, and payment.transaction_id are enforced with UNIQUE constraints.

## 4. Views Used by the Frontend

| View | Purpose |
|---|---|
| vw_available_vehicles | Shows rentable available vehicles with model/category/branch detail |
| vw_active_contracts | Shows active rentals with customer and vehicle summary |
| vw_branch_revenue | Shows revenue per branch |
| vw_customer_history | Shows customer rental count and spending |
| vw_vehicles_due_maintenance | Shows vehicles with no completed maintenance in last 90 days |
| vw_insurance_expiry | Shows insurance policies that are expired or near expiry |

## 5. PL/pgSQL Routines

### rental_ops_create_reservation

Used when creating a reservation from the frontend. It checks that the vehicle exists, checks that the vehicle status is Available, calculates rental days, calculates the total amount, inserts a Confirmed reservation, and returns the new reservation ID.

### rental_ops_close_contract

Used when closing a contract from the frontend. It finds the contract, ensures the contract is Active, calculates rental days, calculates base amount and total amount, updates contract status to Closed, and returns the final total amount.

### fleet_ops_available_vehicles

Returns vehicles available for a date range and optional branch. It checks vehicle status and excludes overlapping reservations.

### fleet_ops_branch_revenue

Returns month-wise branch revenue from closed contracts.

### rental_ops_flag_overdue_contracts

Uses an explicit cursor to fetch active contracts older than 30 days, loops over them, updates them to Disputed, and returns the flagged contracts.

## 6. Triggers

| Trigger | Type | Purpose |
|---|---|---|
| trg_prevent_double_booking | BEFORE INSERT/UPDATE on reservation | Blocks overlapping reservations for the same vehicle |
| trg_contract_vehicle_status | BEFORE INSERT/UPDATE on contract | Sets vehicle to Rented for active contracts and Available when closed |
| trg_sync_reservation_on_close | AFTER UPDATE on contract | Marks linked reservation Completed when contract closes |
| trg_maintenance_vehicle_status | AFTER INSERT/UPDATE on maintenance | Sets vehicle Maintenance/In Progress or Available after completion |
| trg_audit_contract | AFTER INSERT/UPDATE/DELETE on contract | Writes old/new row data to audit_log |
| trg_audit_reservation | AFTER INSERT/UPDATE/DELETE on reservation | Writes old/new row data to audit_log |
| trg_audit_payment | AFTER INSERT/UPDATE/DELETE on payment | Writes old/new row data to audit_log |

## 7. Frontend Demo Script

### Demo 1: Dashboard proof

Open the app. Explain the KPI cards: vehicle count, customer count, active contracts, closed revenue. Explain that branch revenue comes from `vw_branch_revenue`, available fleet comes from `vw_available_vehicles`, and maintenance/insurance attention comes from maintenance and insurance views.

### Demo 2: Create a customer

Go to CRUD, select Customers, click Create, enter a new unique email and driver license, submit, then refresh.

Expected result: customer count increases and the row appears in the read view. Explain that UNIQUE constraints prevent duplicate customer email/license.

### Demo 3: Create a reservation through DB function

Select Reservations, click Create, pick a customer, pick an Available vehicle, pick pickup/return branches, enter future pickup and return datetime, and submit.

Expected result: reservation is inserted by `rental_ops_create_reservation`, not by plain frontend calculation. Total is calculated by the database.

### Demo 4: Double-booking trigger

Try creating another reservation for the same vehicle with overlapping dates.

Expected result: database rejects it because `trg_prevent_double_booking` fires before insert/update. Explain that this is stronger than frontend validation because even direct SQL cannot bypass it.

### Demo 5: Close active contract through RPC

Select Contracts, click Update, select an Active contract, enter actual_return_date and additional_charges, then click Close with RPC.

Expected result: `rental_ops_close_contract` calculates final bill and updates contract to Closed. Vehicle and reservation status sync through triggers.

### Demo 6: Payment and audit log

Select Payments, create a payment for a contract, then go to SQL Views and show audit_log output.

Expected result: payment insert is stored and audit trigger records the change.

### Demo 7: Maintenance status automation

Select Maintenance, create or update a maintenance job to In Progress for a vehicle, refresh, and show that vehicle availability/status is affected by maintenance automation.

Expected result: maintenance trigger updates vehicle status.

## 8. Professor Questions and Good Answers

Q: Why did you use views?
A: Views simplify complex joins for the frontend and reports. Instead of writing joins in the UI, the database exposes `vw_branch_revenue`, `vw_customer_history`, and availability views.

Q: Why are triggers useful here?
A: They enforce rules at database level. For example, double booking prevention and audit logging should work even if data is inserted outside the frontend.

Q: What business problem do your stored routines solve?
A: Reservation creation and contract closing. They validate availability, calculate totals, and update records atomically.

Q: What is the difference between reservation and contract?
A: Reservation is a booking before rental begins. Contract is the signed rental agreement after staff confirms the rental.

Q: What is aggregation in your EERD?
A: Contract aggregates customer, vehicle, reservation, staff, branches, dates, and pricing into one rental transaction.

Q: How do you prove BCNF?
A: Every determinant is a candidate key. Natural determinants such as license plate, VIN, email, driver license number, policy number, and transaction ID are UNIQUE.

Q: PostgreSQL does not have Oracle packages. What did you do?
A: Supabase uses PostgreSQL, so I grouped package-like logic using naming conventions: `rental_ops_*` and `fleet_ops_*`. This gives package organization while staying valid in PostgreSQL.

Q: What is ACID in your project?
A: Stored functions run inside database transactions. If a validation fails, PostgreSQL raises an exception and rolls back the operation, preserving atomicity and consistency.

Q: How is performance handled?
A: Indexes are created on frequent filter/join columns such as vehicle status, branch_id, reservation dates, contract dates, payment contract_id, and audit log table/time.

## 9. Must-Run SQL Before Viva

Run this if you already executed the old migration:

```sql
-- File: imp/supplemental_seed_min_counts.sql
```

Then verify:

```sql
SELECT 'category' AS table_name, COUNT(*) FROM category
UNION ALL SELECT 'branch', COUNT(*) FROM branch
UNION ALL SELECT 'model', COUNT(*) FROM model
UNION ALL SELECT 'staff', COUNT(*) FROM staff
UNION ALL SELECT 'vehicle', COUNT(*) FROM vehicle
UNION ALL SELECT 'customer', COUNT(*) FROM customer
UNION ALL SELECT 'reservation', COUNT(*) FROM reservation
UNION ALL SELECT 'contract', COUNT(*) FROM contract
UNION ALL SELECT 'payment', COUNT(*) FROM payment
UNION ALL SELECT 'damage_report', COUNT(*) FROM damage_report
UNION ALL SELECT 'maintenance', COUNT(*) FROM maintenance
UNION ALL SELECT 'insurance', COUNT(*) FROM insurance;
```
