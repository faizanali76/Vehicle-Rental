import type { ResourceName } from "@/lib/types";

export type ResourceConfig = {
  table: string;
  id: string;
  createFields: string[];
  updateFields: string[];
  softDelete?: Record<string, unknown>;
};

export const resources: Record<ResourceName, ResourceConfig> = {
  vehicles: {
    table: "vehicle",
    id: "vehicle_id",
    createFields: [
      "model_id",
      "branch_id",
      "license_plate",
      "vin",
      "color",
      "mileage",
      "status",
      "daily_rate",
      "purchase_date",
    ],
    updateFields: ["branch_id", "color", "mileage", "status", "daily_rate"],
    softDelete: { status: "Retired" },
  },
  customers: {
    table: "customer",
    id: "customer_id",
    createFields: [
      "first_name",
      "last_name",
      "email",
      "phone",
      "address",
      "driver_license_no",
      "license_expiry",
      "date_of_birth",
    ],
    updateFields: ["first_name", "last_name", "email", "phone", "address", "license_expiry"],
  },
  reservations: {
    table: "reservation",
    id: "reservation_id",
    createFields: [
      "customer_id",
      "vehicle_id",
      "pickup_branch_id",
      "return_branch_id",
      "pickup_date",
      "return_date",
    ],
    updateFields: ["status", "pickup_date", "return_date", "total_amount"],
    softDelete: { status: "Cancelled" },
  },
  contracts: {
    table: "contract",
    id: "contract_id",
    createFields: [
      "reservation_id",
      "customer_id",
      "vehicle_id",
      "staff_id",
      "pickup_branch_id",
      "return_branch_id",
      "actual_pickup_date",
      "agreed_daily_rate",
      "additional_charges",
      "notes",
    ],
    updateFields: ["status", "actual_return_date", "additional_charges", "notes"],
    softDelete: { status: "Disputed" },
  },
  payments: {
    table: "payment",
    id: "payment_id",
    createFields: ["contract_id", "amount", "payment_method", "status", "transaction_id"],
    updateFields: ["amount", "payment_method", "status", "transaction_id"],
    softDelete: { status: "Refunded" },
  },
  maintenance: {
    table: "maintenance",
    id: "maintenance_id",
    createFields: [
      "vehicle_id",
      "branch_id",
      "staff_id",
      "maintenance_type",
      "start_date",
      "end_date",
      "cost",
      "description",
      "status",
    ],
    updateFields: ["staff_id", "end_date", "cost", "description", "status"],
    softDelete: { status: "Cancelled" },
  },
  "damage-reports": {
    table: "damage_report",
    id: "damage_id",
    createFields: [
      "vehicle_id",
      "contract_id",
      "reported_by",
      "report_date",
      "description",
      "severity",
      "repair_cost",
      "status",
    ],
    updateFields: ["description", "severity", "repair_cost", "status"],
    softDelete: { status: "Resolved" },
  },
  insurance: {
    table: "insurance",
    id: "insurance_id",
    createFields: [
      "vehicle_id",
      "provider",
      "policy_number",
      "coverage_type",
      "start_date",
      "end_date",
      "premium_amount",
      "is_active",
    ],
    updateFields: ["provider", "coverage_type", "end_date", "premium_amount", "is_active"],
    softDelete: { is_active: false },
  },
  branches: {
    table: "branch",
    id: "branch_id",
    createFields: ["name", "address", "city", "phone", "email", "manager_id"],
    updateFields: ["name", "address", "city", "phone", "email", "manager_id"],
  },
  staff: {
    table: "staff",
    id: "staff_id",
    createFields: [
      "branch_id",
      "first_name",
      "last_name",
      "email",
      "phone",
      "role",
      "hire_date",
      "salary",
      "is_active",
    ],
    updateFields: ["branch_id", "phone", "role", "salary", "is_active"],
    softDelete: { is_active: false },
  },
  categories: {
    table: "category",
    id: "category_id",
    createFields: ["name", "description", "base_daily_rate"],
    updateFields: ["name", "description", "base_daily_rate"],
  },
  models: {
    table: "model",
    id: "model_id",
    createFields: [
      "category_id",
      "make",
      "model_name",
      "year",
      "passenger_capacity",
      "fuel_type",
      "transmission",
    ],
    updateFields: ["category_id", "make", "model_name", "year", "passenger_capacity", "fuel_type", "transmission"],
  },
};

export function cleanPayload(payload: Record<string, unknown>, fields: string[]) {
  return fields.reduce<Record<string, unknown>>((next, field) => {
    const value = payload[field];
    if (value === "" || value === undefined) return next;

    if (value === "true") next[field] = true;
    else if (value === "false") next[field] = false;
    else if (["mileage", "year", "passenger_capacity"].includes(field)) next[field] = Number(value);
    else if (
      [
        "daily_rate",
        "base_daily_rate",
        "premium_amount",
        "salary",
        "cost",
        "repair_cost",
        "amount",
        "agreed_daily_rate",
        "additional_charges",
        "total_amount",
      ].includes(field)
    ) {
      next[field] = Number(value);
    } else {
      next[field] = value;
    }

    return next;
  }, {});
}
