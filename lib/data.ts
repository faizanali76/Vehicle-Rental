import { createSupabaseAdmin } from "@/lib/supabase/server";
import type { AnyRow, DashboardData } from "@/lib/types";

const tableKeys = [
  "category",
  "model",
  "branch",
  "staff",
  "vehicle",
  "insurance",
  "customer",
  "reservation",
  "contract",
  "payment",
  "damage_report",
  "maintenance",
  "audit_log",
] as const;

async function rows<T = AnyRow>(
  query: PromiseLike<{ data: T[] | null; error: { message: string } | null }>,
) {
  const { data, error } = await query;
  if (error) {
    console.warn(error.message);
    return [];
  }
  return data ?? [];
}

async function countRows(table: string) {
  const supabase = createSupabaseAdmin();
  const { count, error } = await supabase
    .from(table)
    .select("*", { count: "exact", head: true });

  if (error) {
    console.warn(error.message);
    return 0;
  }

  return count ?? 0;
}

export async function getDashboardData(): Promise<DashboardData> {
  let supabase: ReturnType<typeof createSupabaseAdmin>;

  try {
    supabase = createSupabaseAdmin();
  } catch (error) {
    return emptyDashboard(
      error instanceof Error ? error.message : "Unable to create Supabase client.",
    );
  }

  const counts = Object.fromEntries(
    await Promise.all(tableKeys.map(async (key) => [key, await countRows(key)])),
  ) as Record<string, number>;

  const [
    vehicles,
    customers,
    reservations,
    contracts,
    payments,
    maintenance,
    damageReports,
    branches,
    staff,
    insurance,
    categories,
    models,
    auditLog,
    availableVehicles,
    activeContracts,
    branchRevenue,
    customerHistory,
    dueMaintenance,
    insuranceExpiry,
  ] = await Promise.all([
    rows(
      supabase
        .from("vehicle")
        .select(
          "*, model(model_id, make, model_name, year, fuel_type, transmission, category(category_id, name)), branch(branch_id, name, city)",
        )
        .order("created_at", { ascending: false })
        .limit(40),
    ),
    rows(supabase.from("customer").select("*").order("created_at", { ascending: false }).limit(40)),
    rows(
      supabase
        .from("reservation")
        .select(
          "*, customer(customer_id, first_name, last_name), vehicle(vehicle_id, license_plate), pickup_branch:branch!reservation_pickup_branch_id_fkey(name), return_branch:branch!reservation_return_branch_id_fkey(name)",
        )
        .order("created_at", { ascending: false })
        .limit(40),
    ),
    rows(
      supabase
        .from("contract")
        .select(
          "*, customer(customer_id, first_name, last_name), vehicle(vehicle_id, license_plate), staff(staff_id, first_name, last_name)",
        )
        .order("created_at", { ascending: false })
        .limit(40),
    ),
    rows(
      supabase
        .from("payment")
        .select("*, contract(contract_id, customer(first_name, last_name))")
        .order("payment_date", { ascending: false })
        .limit(40),
    ),
    rows(
      supabase
        .from("maintenance")
        .select("*, vehicle(vehicle_id, license_plate), branch(branch_id, name), staff(staff_id, first_name, last_name)")
        .order("created_at", { ascending: false })
        .limit(40),
    ),
    rows(
      supabase
        .from("damage_report")
        .select("*, vehicle(vehicle_id, license_plate), staff:reported_by(first_name, last_name)")
        .order("created_at", { ascending: false })
        .limit(40),
    ),
    rows(supabase.from("branch").select("*").order("created_at", { ascending: false }).limit(40)),
    rows(supabase.from("staff").select("*").order("created_at", { ascending: false }).limit(40)),
    rows(
      supabase
        .from("insurance")
        .select("*, vehicle(vehicle_id, license_plate)")
        .order("end_date", { ascending: true })
        .limit(40),
    ),
    rows(supabase.from("category").select("*").order("name", { ascending: true })),
    rows(
      supabase
        .from("model")
        .select("*, category(category_id, name)")
        .order("make", { ascending: true }),
    ),
    rows(supabase.from("audit_log").select("*").order("changed_at", { ascending: false }).limit(20)),
    rows(supabase.from("vw_available_vehicles").select("*").limit(40)),
    rows(supabase.from("vw_active_contracts").select("*").limit(40)),
    rows(supabase.from("vw_branch_revenue").select("*").limit(40)),
    rows(supabase.from("vw_customer_history").select("*").order("total_spent", { ascending: false }).limit(40)),
    rows(supabase.from("vw_vehicles_due_maintenance").select("*").limit(40)),
    rows(supabase.from("vw_insurance_expiry").select("*").order("days_until_expiry", { ascending: true }).limit(40)),
  ]);

  return {
    counts,
    tables: {
      vehicles,
      customers,
      reservations,
      contracts,
      payments,
      maintenance,
      damageReports,
      branches,
      staff,
      insurance,
      categories,
      models,
      auditLog,
    },
    views: {
      availableVehicles,
      activeContracts,
      branchRevenue,
      customerHistory,
      dueMaintenance,
      insuranceExpiry,
    },
  };
}

function emptyDashboard(warning: string): DashboardData {
  return {
    warning,
    counts: {},
    tables: {
      vehicles: [],
      customers: [],
      reservations: [],
      contracts: [],
      payments: [],
      maintenance: [],
      damageReports: [],
      branches: [],
      staff: [],
      insurance: [],
      categories: [],
      models: [],
      auditLog: [],
    },
    views: {
      availableVehicles: [],
      activeContracts: [],
      branchRevenue: [],
      customerHistory: [],
      dueMaintenance: [],
      insuranceExpiry: [],
    },
  };
}
