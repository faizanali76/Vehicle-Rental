export type AnyRow = Record<string, unknown>;

export type DashboardData = {
  warning?: string;
  counts: Record<string, number>;
  tables: {
    vehicles: AnyRow[];
    customers: AnyRow[];
    reservations: AnyRow[];
    contracts: AnyRow[];
    payments: AnyRow[];
    maintenance: AnyRow[];
    damageReports: AnyRow[];
    branches: AnyRow[];
    staff: AnyRow[];
    insurance: AnyRow[];
    categories: AnyRow[];
    models: AnyRow[];
    auditLog: AnyRow[];
  };
  views: {
    availableVehicles: AnyRow[];
    activeContracts: AnyRow[];
    branchRevenue: AnyRow[];
    customerHistory: AnyRow[];
    dueMaintenance: AnyRow[];
    insuranceExpiry: AnyRow[];
  };
};

export type ResourceName =
  | "vehicles"
  | "customers"
  | "reservations"
  | "contracts"
  | "payments"
  | "maintenance"
  | "damage-reports"
  | "insurance"
  | "branches"
  | "staff"
  | "categories"
  | "models";
