"use client";

import {
  Activity,
  AlertTriangle,
  BadgeDollarSign,
  BarChart3,
  CalendarClock,
  Car,
  ClipboardCheck,
  CreditCard,
  Database,
  FileCheck2,
  Gauge,
  MapPin,
  Plus,
  RefreshCw,
  Save,
  Search,
  ShieldCheck,
  SlidersHorizontal,
  Trash2,
  UserRound,
  UsersRound,
  Wrench,
} from "lucide-react";
import { FormEvent, useMemo, useState } from "react";
import type { AnyRow, DashboardData, ResourceName } from "@/lib/types";

type Column = {
  label: string;
  value: (row: AnyRow) => unknown;
};

type Field = {
  name: string;
  label: string;
  type?: "text" | "number" | "date" | "datetime-local" | "textarea" | "select";
  required?: boolean;
  options?: () => { value: string; label: string }[];
};

type ResourceForm = {
  resource: ResourceName;
  title: string;
  icon: React.ComponentType<{ className?: string }>;
  idKey: string;
  rows: () => AnyRow[];
  createFields: Field[];
  updateFields: Field[];
  deleteLabel: string;
};

const money = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 0,
});

function asText(value: unknown) {
  if (value === null || value === undefined || value === "") return "-";
  if (typeof value === "number") return Number.isFinite(value) ? value.toLocaleString() : "-";
  if (typeof value === "boolean") return value ? "Yes" : "No";
  if (typeof value === "object") {
    const row = value as AnyRow;
    if ("first_name" in row || "last_name" in row) return `${row.first_name ?? ""} ${row.last_name ?? ""}`.trim();
    if ("license_plate" in row) return String(row.license_plate);
    if ("name" in row) return String(row.name);
    if ("model_name" in row) return `${row.make ?? ""} ${row.model_name ?? ""}`.trim();
    return JSON.stringify(value);
  }
  const text = String(value);
  if (/^\d{4}-\d{2}-\d{2}T/.test(text)) return new Date(text).toLocaleDateString();
  return text;
}

function formatMoney(value: unknown) {
  const number = Number(value ?? 0);
  return money.format(Number.isFinite(number) ? number : 0);
}

function rowId(row: AnyRow, key: string) {
  return String(row[key] ?? "");
}

function labelCustomer(row: AnyRow) {
  return `${row.first_name ?? ""} ${row.last_name ?? ""}`.trim() || String(row.email ?? row.customer_id);
}

function labelVehicle(row: AnyRow) {
  const model = row.model as AnyRow | undefined;
  return `${row.license_plate ?? ""} - ${model?.make ?? ""} ${model?.model_name ?? ""}`.trim();
}

function labelStaff(row: AnyRow) {
  return `${row.first_name ?? ""} ${row.last_name ?? ""} (${row.role ?? "Staff"})`.trim();
}

function labelModel(row: AnyRow) {
  return `${row.make ?? ""} ${row.model_name ?? ""} ${row.year ?? ""}`.trim();
}

function labelBranch(row: AnyRow) {
  return `${row.name ?? ""} - ${row.city ?? ""}`.trim();
}

export default function AppShell({ initialData }: { initialData: DashboardData }) {
  const [data, setData] = useState(initialData);
  const [activeArea, setActiveArea] = useState<"overview" | "operations" | "reports">("overview");
  const [activeResource, setActiveResource] = useState<ResourceName>("vehicles");
  const [targetId, setTargetId] = useState("");
  const [form, setForm] = useState<Record<string, string>>({});
  const [mode, setMode] = useState<"create" | "update">("create");
  const [query, setQuery] = useState("");
  const [message, setMessage] = useState<{ tone: "ok" | "error"; text: string } | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  const optionFrom = (rows: AnyRow[], idKey: string, label: (row: AnyRow) => string) =>
    rows.map((row) => ({ value: rowId(row, idKey), label: label(row) || rowId(row, idKey) }));

  const field = (name: string, label: string, type: Field["type"] = "text", required = true): Field => ({
    name,
    label,
    type,
    required,
  });

  const select = (
    name: string,
    label: string,
    options: () => { value: string; label: string }[],
    required = true,
  ): Field => ({
    name,
    label,
    type: "select",
    required,
    options,
  });

  const resources = useMemo<ResourceForm[]>(
    () => [
      {
        resource: "vehicles",
        title: "Vehicles",
        icon: Car,
        idKey: "vehicle_id",
        rows: () => data.tables.vehicles,
        createFields: [
          select("model_id", "Model", () => optionFrom(data.tables.models, "model_id", labelModel)),
          select("branch_id", "Branch", () => optionFrom(data.tables.branches, "branch_id", labelBranch)),
          field("license_plate", "License plate"),
          field("vin", "VIN"),
          field("color", "Color"),
          field("mileage", "Mileage", "number"),
          select("status", "Status", () => statusOptions(["Available", "Rented", "Maintenance", "Retired"])),
          field("daily_rate", "Daily rate", "number"),
          field("purchase_date", "Purchase date", "date"),
        ],
        updateFields: [
          select("branch_id", "Branch", () => optionFrom(data.tables.branches, "branch_id", labelBranch), false),
          field("color", "Color", "text", false),
          field("mileage", "Mileage", "number", false),
          select("status", "Status", () => statusOptions(["Available", "Rented", "Maintenance", "Retired"]), false),
          field("daily_rate", "Daily rate", "number", false),
        ],
        deleteLabel: "Retire vehicle",
      },
      {
        resource: "customers",
        title: "Customers",
        icon: UsersRound,
        idKey: "customer_id",
        rows: () => data.tables.customers,
        createFields: [
          field("first_name", "First name"),
          field("last_name", "Last name"),
          field("email", "Email"),
          field("phone", "Phone"),
          field("address", "Address", "textarea"),
          field("driver_license_no", "Driver license"),
          field("license_expiry", "License expiry", "date"),
          field("date_of_birth", "Date of birth", "date"),
        ],
        updateFields: [
          field("first_name", "First name", "text", false),
          field("last_name", "Last name", "text", false),
          field("email", "Email", "text", false),
          field("phone", "Phone", "text", false),
          field("address", "Address", "textarea", false),
          field("license_expiry", "License expiry", "date", false),
        ],
        deleteLabel: "Restricted by FK",
      },
      {
        resource: "reservations",
        title: "Reservations",
        icon: CalendarClock,
        idKey: "reservation_id",
        rows: () => data.tables.reservations,
        createFields: [
          select("customer_id", "Customer", () => optionFrom(data.tables.customers, "customer_id", labelCustomer)),
          select("vehicle_id", "Vehicle", () => optionFrom(data.tables.vehicles, "vehicle_id", labelVehicle)),
          select("pickup_branch_id", "Pickup branch", () => optionFrom(data.tables.branches, "branch_id", labelBranch)),
          select("return_branch_id", "Return branch", () => optionFrom(data.tables.branches, "branch_id", labelBranch)),
          field("pickup_date", "Pickup date", "datetime-local"),
          field("return_date", "Return date", "datetime-local"),
        ],
        updateFields: [
          select("status", "Status", () => statusOptions(["Pending", "Confirmed", "Cancelled", "Completed"]), false),
          field("pickup_date", "Pickup date", "datetime-local", false),
          field("return_date", "Return date", "datetime-local", false),
          field("total_amount", "Total amount", "number", false),
        ],
        deleteLabel: "Cancel reservation",
      },
      {
        resource: "contracts",
        title: "Contracts",
        icon: FileCheck2,
        idKey: "contract_id",
        rows: () => data.tables.contracts,
        createFields: [
          select("reservation_id", "Reservation", () => optionFrom(data.tables.reservations, "reservation_id", (row) => String(row.reservation_id))),
          select("customer_id", "Customer", () => optionFrom(data.tables.customers, "customer_id", labelCustomer)),
          select("vehicle_id", "Vehicle", () => optionFrom(data.tables.vehicles, "vehicle_id", labelVehicle)),
          select("staff_id", "Handled by", () => optionFrom(data.tables.staff, "staff_id", labelStaff)),
          select("pickup_branch_id", "Pickup branch", () => optionFrom(data.tables.branches, "branch_id", labelBranch)),
          select("return_branch_id", "Return branch", () => optionFrom(data.tables.branches, "branch_id", labelBranch)),
          field("actual_pickup_date", "Pickup date", "datetime-local"),
          field("agreed_daily_rate", "Daily rate", "number"),
          field("additional_charges", "Extra charges", "number", false),
          field("notes", "Notes", "textarea", false),
        ],
        updateFields: [
          select("status", "Status", () => statusOptions(["Active", "Closed", "Disputed"]), false),
          field("actual_return_date", "Return date", "datetime-local", false),
          field("additional_charges", "Extra charges", "number", false),
          field("notes", "Notes", "textarea", false),
        ],
        deleteLabel: "Mark disputed",
      },
      {
        resource: "payments",
        title: "Payments",
        icon: CreditCard,
        idKey: "payment_id",
        rows: () => data.tables.payments,
        createFields: [
          select("contract_id", "Contract", () => optionFrom(data.tables.contracts, "contract_id", (row) => String(row.contract_id))),
          field("amount", "Amount", "number"),
          select("payment_method", "Method", () => statusOptions(["Cash", "Credit Card", "Debit Card", "Bank Transfer", "Online"])),
          select("status", "Status", () => statusOptions(["Pending", "Completed", "Refunded", "Failed"])),
          field("transaction_id", "Transaction ID", "text", false),
        ],
        updateFields: [
          field("amount", "Amount", "number", false),
          select("payment_method", "Method", () => statusOptions(["Cash", "Credit Card", "Debit Card", "Bank Transfer", "Online"]), false),
          select("status", "Status", () => statusOptions(["Pending", "Completed", "Refunded", "Failed"]), false),
          field("transaction_id", "Transaction ID", "text", false),
        ],
        deleteLabel: "Refund payment",
      },
      {
        resource: "maintenance",
        title: "Maintenance",
        icon: Wrench,
        idKey: "maintenance_id",
        rows: () => data.tables.maintenance,
        createFields: [
          select("vehicle_id", "Vehicle", () => optionFrom(data.tables.vehicles, "vehicle_id", labelVehicle)),
          select("branch_id", "Branch", () => optionFrom(data.tables.branches, "branch_id", labelBranch)),
          select("staff_id", "Mechanic", () => optionFrom(data.tables.staff, "staff_id", labelStaff), false),
          select("maintenance_type", "Type", () =>
            statusOptions(["Oil Change", "Tire Rotation", "Brake Service", "Engine Check", "Full Service", "Damage Repair", "Other"]),
          ),
          field("start_date", "Start date", "date"),
          field("end_date", "End date", "date", false),
          field("cost", "Cost", "number", false),
          field("description", "Description", "textarea", false),
          select("status", "Status", () => statusOptions(["Scheduled", "In Progress", "Completed", "Cancelled"])),
        ],
        updateFields: [
          select("staff_id", "Mechanic", () => optionFrom(data.tables.staff, "staff_id", labelStaff), false),
          field("end_date", "End date", "date", false),
          field("cost", "Cost", "number", false),
          field("description", "Description", "textarea", false),
          select("status", "Status", () => statusOptions(["Scheduled", "In Progress", "Completed", "Cancelled"]), false),
        ],
        deleteLabel: "Cancel job",
      },
      {
        resource: "damage-reports",
        title: "Damage Reports",
        icon: AlertTriangle,
        idKey: "damage_id",
        rows: () => data.tables.damageReports,
        createFields: [
          select("vehicle_id", "Vehicle", () => optionFrom(data.tables.vehicles, "vehicle_id", labelVehicle)),
          select("contract_id", "Contract", () => optionFrom(data.tables.contracts, "contract_id", (row) => String(row.contract_id)), false),
          select("reported_by", "Reported by", () => optionFrom(data.tables.staff, "staff_id", labelStaff)),
          field("report_date", "Report date", "date"),
          field("description", "Description", "textarea"),
          select("severity", "Severity", () => statusOptions(["Minor", "Moderate", "Severe"])),
          field("repair_cost", "Repair cost", "number", false),
          select("status", "Status", () => statusOptions(["Reported", "Under Repair", "Resolved"])),
        ],
        updateFields: [
          field("description", "Description", "textarea", false),
          select("severity", "Severity", () => statusOptions(["Minor", "Moderate", "Severe"]), false),
          field("repair_cost", "Repair cost", "number", false),
          select("status", "Status", () => statusOptions(["Reported", "Under Repair", "Resolved"]), false),
        ],
        deleteLabel: "Resolve report",
      },
      {
        resource: "insurance",
        title: "Insurance",
        icon: ShieldCheck,
        idKey: "insurance_id",
        rows: () => data.tables.insurance,
        createFields: [
          select("vehicle_id", "Vehicle", () => optionFrom(data.tables.vehicles, "vehicle_id", labelVehicle)),
          field("provider", "Provider"),
          field("policy_number", "Policy number"),
          select("coverage_type", "Coverage", () => statusOptions(["Basic", "Comprehensive", "Third-Party"])),
          field("start_date", "Start date", "date"),
          field("end_date", "End date", "date"),
          field("premium_amount", "Premium", "number"),
          select("is_active", "Active", () => statusOptions(["true", "false"])),
        ],
        updateFields: [
          field("provider", "Provider", "text", false),
          select("coverage_type", "Coverage", () => statusOptions(["Basic", "Comprehensive", "Third-Party"]), false),
          field("end_date", "End date", "date", false),
          field("premium_amount", "Premium", "number", false),
          select("is_active", "Active", () => statusOptions(["true", "false"]), false),
        ],
        deleteLabel: "Deactivate policy",
      },
      {
        resource: "branches",
        title: "Branches",
        icon: MapPin,
        idKey: "branch_id",
        rows: () => data.tables.branches,
        createFields: [
          field("name", "Name"),
          field("address", "Address", "textarea"),
          field("city", "City"),
          field("phone", "Phone"),
          field("email", "Email", "text", false),
          select("manager_id", "Manager", () => optionFrom(data.tables.staff, "staff_id", labelStaff), false),
        ],
        updateFields: [
          field("name", "Name", "text", false),
          field("address", "Address", "textarea", false),
          field("city", "City", "text", false),
          field("phone", "Phone", "text", false),
          field("email", "Email", "text", false),
          select("manager_id", "Manager", () => optionFrom(data.tables.staff, "staff_id", labelStaff), false),
        ],
        deleteLabel: "Delete if unused",
      },
      {
        resource: "staff",
        title: "Staff",
        icon: UserRound,
        idKey: "staff_id",
        rows: () => data.tables.staff,
        createFields: [
          select("branch_id", "Branch", () => optionFrom(data.tables.branches, "branch_id", labelBranch)),
          field("first_name", "First name"),
          field("last_name", "Last name"),
          field("email", "Email"),
          field("phone", "Phone"),
          select("role", "Role", () => statusOptions(["Manager", "Agent", "Mechanic", "Cleaner"])),
          field("hire_date", "Hire date", "date"),
          field("salary", "Salary", "number"),
          select("is_active", "Active", () => statusOptions(["true", "false"])),
        ],
        updateFields: [
          select("branch_id", "Branch", () => optionFrom(data.tables.branches, "branch_id", labelBranch), false),
          field("phone", "Phone", "text", false),
          select("role", "Role", () => statusOptions(["Manager", "Agent", "Mechanic", "Cleaner"]), false),
          field("salary", "Salary", "number", false),
          select("is_active", "Active", () => statusOptions(["true", "false"]), false),
        ],
        deleteLabel: "Deactivate staff",
      },
      {
        resource: "categories",
        title: "Categories",
        icon: SlidersHorizontal,
        idKey: "category_id",
        rows: () => data.tables.categories,
        createFields: [field("name", "Name"), field("description", "Description", "textarea", false), field("base_daily_rate", "Base daily rate", "number")],
        updateFields: [field("name", "Name", "text", false), field("description", "Description", "textarea", false), field("base_daily_rate", "Base daily rate", "number", false)],
        deleteLabel: "Delete if unused",
      },
      {
        resource: "models",
        title: "Models",
        icon: Gauge,
        idKey: "model_id",
        rows: () => data.tables.models,
        createFields: [
          select("category_id", "Category", () => optionFrom(data.tables.categories, "category_id", (row) => String(row.name))),
          field("make", "Make"),
          field("model_name", "Model name"),
          field("year", "Year", "number"),
          field("passenger_capacity", "Seats", "number"),
          select("fuel_type", "Fuel", () => statusOptions(["Petrol", "Diesel", "Electric", "Hybrid"])),
          select("transmission", "Transmission", () => statusOptions(["Manual", "Automatic"])),
        ],
        updateFields: [
          select("category_id", "Category", () => optionFrom(data.tables.categories, "category_id", (row) => String(row.name)), false),
          field("make", "Make", "text", false),
          field("model_name", "Model name", "text", false),
          field("year", "Year", "number", false),
          field("passenger_capacity", "Seats", "number", false),
          select("fuel_type", "Fuel", () => statusOptions(["Petrol", "Diesel", "Electric", "Hybrid"]), false),
          select("transmission", "Transmission", () => statusOptions(["Manual", "Automatic"]), false),
        ],
        deleteLabel: "Delete if unused",
      },
    ],
    [data],
  );

  const current = resources.find((item) => item.resource === activeResource) ?? resources[0];
  const visibleRows = current
    .rows()
    .filter((row) => JSON.stringify(row).toLowerCase().includes(query.toLowerCase()));

  async function refresh() {
    const response = await fetch(`/api/dashboard?ts=${Date.now()}`, { cache: "no-store" });
    const next = (await response.json()) as DashboardData;
    setData(next);
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsSaving(true);
    setMessage(null);

    const body = mode === "update" ? { id: targetId, ...form } : form;
    const response = await fetch(`/api/admin/${activeResource}`, {
      method: mode === "create" ? "POST" : "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const result = (await response.json()) as { error?: string };
    setIsSaving(false);

    if (!response.ok) {
      setMessage({ tone: "error", text: result.error ?? "Request failed." });
      return;
    }

    setMessage({ tone: "ok", text: mode === "create" ? "Record created." : "Record updated." });
    setForm({});
    await refresh();
  }

  async function runDelete() {
    if (!targetId) {
      setMessage({ tone: "error", text: "Choose a record first." });
      return;
    }

    setIsSaving(true);
    setMessage(null);
    const response = await fetch(`/api/admin/${activeResource}?id=${encodeURIComponent(targetId)}`, {
      method: "DELETE",
    });
    const result = (await response.json()) as { error?: string };
    setIsSaving(false);

    if (!response.ok) {
      setMessage({ tone: "error", text: result.error ?? "Delete action failed." });
      return;
    }

    setMessage({ tone: "ok", text: current.deleteLabel });
    await refresh();
  }

  async function closeContract() {
    if (activeResource !== "contracts" || !targetId) return;
    setIsSaving(true);
    const response = await fetch("/api/admin/contracts", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        id: targetId,
        action: "close",
        actual_return_date: form.actual_return_date || new Date().toISOString(),
        additional_charges: form.additional_charges || "0",
      }),
    });
    const result = (await response.json()) as { error?: string; total_amount?: number };
    setIsSaving(false);

    if (!response.ok) {
      setMessage({ tone: "error", text: result.error ?? "Unable to close contract." });
      return;
    }

    setMessage({ tone: "ok", text: `Contract closed. Final amount: ${formatMoney(result.total_amount)}` });
    await refresh();
  }

  function selectTargetRecord(id: string) {
    setTargetId(id);

    const selected = current.rows().find((row) => rowId(row, current.idKey) === id);
    if (!selected) {
      setForm({});
      return;
    }

    setForm(
      current.updateFields.reduce<Record<string, string>>((draft, field) => {
        draft[field.name] = fieldValueForInput(selected[field.name], field.type);
        return draft;
      }, {}),
    );
  }

  const areas = [
    { key: "overview", label: "Overview", icon: BarChart3 },
    { key: "operations", label: "CRUD", icon: Database },
    { key: "reports", label: "SQL Views", icon: ClipboardCheck },
  ] as const;

  return (
    <div className="min-h-screen bg-[#f6fbf4] text-[#102116]">
      <aside className="fixed inset-y-0 left-0 z-10 hidden w-72 border-r border-[#d8e9d7] bg-[#113d24] p-5 text-white lg:block">
        <div className="mb-8 flex items-center gap-3">
          <div className="grid size-11 place-items-center rounded-md bg-[#c7f5d3] text-[#113d24]">
            <Car className="size-6" />
          </div>
          <div>
            <p className="text-sm text-[#b9dec3]">Database Systems</p>
            <h1 className="text-xl font-semibold">Vehicle Rental</h1>
          </div>
        </div>
        <nav className="space-y-2">
          {areas.map((area) => (
            <button
              key={area.key}
              onClick={() => setActiveArea(area.key)}
              className={`flex w-full items-center gap-3 rounded-md px-3 py-3 text-left text-sm font-medium transition ${
                activeArea === area.key ? "bg-white text-[#113d24]" : "text-[#dcefe0] hover:bg-white/10"
              }`}
            >
              <area.icon className="size-4" />
              {area.label}
            </button>
          ))}
        </nav>
        <div className="absolute bottom-5 left-5 right-5 rounded-md border border-white/15 bg-white/10 p-4 text-sm text-[#dcefe0]">
          <p className="font-medium text-white">Phase coverage</p>
          <p className="mt-2">DDL, DCL, indexes, views, triggers, PL/pgSQL routines, object types, and CRUD UI are wired into the project.</p>
        </div>
      </aside>

      <main className="lg:pl-72">
        <header className="sticky top-0 z-10 border-b border-[#d8e9d7] bg-[#f6fbf4]/90 px-5 py-4 backdrop-blur">
          <div className="mx-auto flex max-w-7xl items-center justify-between gap-4">
            <div>
              <p className="text-sm font-medium text-[#2e6a43]">Supabase PostgreSQL project</p>
              <h2 className="text-2xl font-semibold tracking-normal">Rental operations console</h2>
            </div>
            <button
              onClick={refresh}
              className="inline-flex items-center gap-2 rounded-md bg-[#113d24] px-4 py-2 text-sm font-semibold text-white hover:bg-[#19542f]"
            >
              <RefreshCw className="size-4" />
              Refresh
            </button>
          </div>
        </header>

        <div className="mx-auto max-w-7xl px-5 py-6">
          {data.warning ? (
            <div className="mb-5 rounded-md border border-amber-300 bg-amber-50 p-4 text-sm text-amber-900">{data.warning}</div>
          ) : null}

          {activeArea === "overview" ? <Overview data={data} /> : null}
          {activeArea === "operations" ? (
            <section className="grid gap-5 xl:grid-cols-[320px_minmax(0,1fr)]">
              <div className="space-y-3">
                {resources.map((item) => (
                  <button
                    key={item.resource}
                    onClick={() => {
                      setActiveResource(item.resource);
                      setForm({});
                      setTargetId("");
                      setMessage(null);
                    }}
                    className={`flex w-full items-center justify-between rounded-md border p-3 text-left transition ${
                      activeResource === item.resource
                        ? "border-[#113d24] bg-white shadow-sm"
                        : "border-[#d8e9d7] bg-white/70 hover:bg-white"
                    }`}
                  >
                    <span className="flex items-center gap-3">
                      <item.icon className="size-4 text-[#2e6a43]" />
                      <span className="font-medium">{item.title}</span>
                    </span>
                    <span className="rounded bg-[#e6f6e9] px-2 py-1 text-xs font-semibold text-[#2e6a43]">{item.rows().length}</span>
                  </button>
                ))}
              </div>

              <div className="space-y-5">
                <div className="rounded-md border border-[#d8e9d7] bg-white p-4 shadow-sm">
                  <div className="mb-4 flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                    <div>
                      <h3 className="flex items-center gap-2 text-xl font-semibold">
                        <current.icon className="size-5 text-[#2e6a43]" />
                        {current.title} operations
                      </h3>
                      <p className="text-sm text-[#5c705f]">Create, read, update, and business-delete records through Supabase API routes.</p>
                    </div>
                    <div className="flex rounded-md border border-[#d8e9d7] bg-[#f6fbf4] p-1">
                      {(["create", "update"] as const).map((item) => (
                        <button
                          key={item}
                          onClick={() => {
                            setMode(item);
                            setForm({});
                            setTargetId("");
                          }}
                          className={`rounded px-3 py-2 text-sm font-semibold ${mode === item ? "bg-[#113d24] text-white" : "text-[#2e6a43]"}`}
                        >
                          {item === "create" ? "Create" : "Update"}
                        </button>
                      ))}
                    </div>
                  </div>

                  <form onSubmit={submit} className="grid gap-4 md:grid-cols-2">
                    {mode === "update" ? (
                      <label className="md:col-span-2">
                        <span className="mb-1 block text-sm font-semibold">Record</span>
                        <select
                          value={targetId}
                          onChange={(event) => selectTargetRecord(event.target.value)}
                          required
                          className="h-11 w-full rounded-md border border-[#cbdcca] bg-white px-3 text-sm"
                        >
                          <option value="">Select record</option>
                          {current.rows().map((row) => (
                            <option key={rowId(row, current.idKey)} value={rowId(row, current.idKey)}>
                              {recordLabel(activeResource, row)}
                            </option>
                          ))}
                        </select>
                      </label>
                    ) : null}
                    {(mode === "create" ? current.createFields : current.updateFields).map((item) => (
                      <FieldControl
                        key={item.name}
                        field={item}
                        value={form[item.name] ?? ""}
                        onChange={(value) => setForm((draft) => ({ ...draft, [item.name]: value }))}
                      />
                    ))}
                    <div className="flex flex-wrap gap-3 md:col-span-2">
                      <button
                        disabled={isSaving}
                        className="inline-flex h-11 items-center gap-2 rounded-md bg-[#113d24] px-4 text-sm font-semibold text-white hover:bg-[#19542f] disabled:opacity-60"
                      >
                        {mode === "create" ? <Plus className="size-4" /> : <Save className="size-4" />}
                        {isSaving ? "Saving..." : mode === "create" ? "Create record" : "Save changes"}
                      </button>
                      {mode === "update" ? (
                        <button
                          type="button"
                          onClick={runDelete}
                          disabled={isSaving}
                          className="inline-flex h-11 items-center gap-2 rounded-md border border-[#d8e9d7] px-4 text-sm font-semibold text-[#913325] hover:bg-[#fff2ef] disabled:opacity-60"
                        >
                          <Trash2 className="size-4" />
                          {current.deleteLabel}
                        </button>
                      ) : null}
                      {activeResource === "contracts" && mode === "update" ? (
                        <button
                          type="button"
                          onClick={closeContract}
                          disabled={isSaving}
                          className="inline-flex h-11 items-center gap-2 rounded-md border border-[#b4d9bd] px-4 text-sm font-semibold text-[#2e6a43] hover:bg-[#edf8ef] disabled:opacity-60"
                        >
                          <BadgeDollarSign className="size-4" />
                          Close with RPC
                        </button>
                      ) : null}
                    </div>
                  </form>
                  {message ? (
                    <p className={`mt-4 rounded-md p-3 text-sm ${message.tone === "ok" ? "bg-[#e6f6e9] text-[#14522b]" : "bg-[#fff2ef] text-[#913325]"}`}>
                      {message.text}
                    </p>
                  ) : null}
                </div>

                <div className="rounded-md border border-[#d8e9d7] bg-white p-4 shadow-sm">
                  <div className="mb-4 flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                    <h3 className="text-lg font-semibold">Read view</h3>
                    <label className="relative w-full md:w-80">
                      <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-[#6d806f]" />
                      <input
                        value={query}
                        onChange={(event) => setQuery(event.target.value)}
                        placeholder="Search current records"
                        className="h-10 w-full rounded-md border border-[#d8e9d7] pl-9 pr-3 text-sm"
                      />
                    </label>
                  </div>
                  <DataTable rows={visibleRows} columns={tableColumns(activeResource)} />
                </div>
              </div>
            </section>
          ) : null}

          {activeArea === "reports" ? <Reports data={data} /> : null}
        </div>
      </main>
    </div>
  );
}

function Overview({ data }: { data: DashboardData }) {
  const cards = [
    { label: "Vehicles", value: data.counts.vehicle ?? 0, icon: Car },
    { label: "Customers", value: data.counts.customer ?? 0, icon: UsersRound },
    { label: "Active contracts", value: data.views.activeContracts.length, icon: Activity },
    {
      label: "Closed revenue",
      value: formatMoney(data.views.branchRevenue.reduce((sum, row) => sum + Number(row.total_revenue ?? 0), 0)),
      icon: BadgeDollarSign,
    },
  ];

  return (
    <section className="space-y-5">
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {cards.map((card) => (
          <div key={card.label} className="rounded-md border border-[#d8e9d7] bg-white p-5 shadow-sm">
            <div className="flex items-center justify-between">
              <p className="text-sm font-medium text-[#5c705f]">{card.label}</p>
              <card.icon className="size-5 text-[#2e6a43]" />
            </div>
            <p className="mt-4 text-3xl font-semibold">{card.value}</p>
          </div>
        ))}
      </div>
      <div className="grid gap-5 xl:grid-cols-[1.2fr_0.8fr]">
        <Panel title="Branch revenue" icon={BarChart3}>
          <div className="space-y-3">
            {data.views.branchRevenue.map((row) => {
              const total = Number(row.total_revenue ?? 0);
              const max = Math.max(...data.views.branchRevenue.map((item) => Number(item.total_revenue ?? 0)), 1);
              return (
                <div key={String(row.branch_id)} className="grid gap-2">
                  <div className="flex items-center justify-between text-sm">
                    <span className="font-medium">{asText(row.branch_name)}</span>
                    <span>{formatMoney(total)}</span>
                  </div>
                  <div className="h-2 rounded bg-[#e6f6e9]">
                    <div className="h-full rounded bg-[#2e6a43]" style={{ width: `${Math.max(6, (total / max) * 100)}%` }} />
                  </div>
                </div>
              );
            })}
          </div>
        </Panel>
        <Panel title="Database checklist" icon={Database}>
          <div className="grid gap-2 text-sm">
            {[
              "13 tables with primary and foreign keys",
              "CHECK, UNIQUE, NOT NULL, and date constraints",
              "21 indexes for search and joins",
              "6 complex views for frontend reporting",
              "Triggers for audit, validation, and status automation",
              "PL/pgSQL RPC routines, cursor logic, and object types",
            ].map((item) => (
              <div key={item} className="flex items-center gap-2 rounded bg-[#f6fbf4] p-2">
                <ClipboardCheck className="size-4 text-[#2e6a43]" />
                <span>{item}</span>
              </div>
            ))}
          </div>
        </Panel>
      </div>
      <div className="grid gap-5 xl:grid-cols-2">
        <Panel title="Available fleet" icon={Car}>
          <DataTable rows={data.views.availableVehicles.slice(0, 8)} columns={availableColumns} />
        </Panel>
        <Panel title="Maintenance and insurance attention" icon={AlertTriangle}>
          <DataTable rows={[...data.views.dueMaintenance, ...data.views.insuranceExpiry].slice(0, 8)} columns={attentionColumns} />
        </Panel>
      </div>
    </section>
  );
}

function Reports({ data }: { data: DashboardData }) {
  return (
    <section className="grid gap-5">
      <Panel title="Advanced SQL views exposed to the frontend" icon={ClipboardCheck}>
        <div className="grid gap-5">
          <ReportBlock title="vw_customer_history" rows={data.views.customerHistory} columns={customerHistoryColumns} />
          <ReportBlock title="vw_active_contracts" rows={data.views.activeContracts} columns={activeContractColumns} />
          <ReportBlock title="vw_insurance_expiry" rows={data.views.insuranceExpiry} columns={insuranceColumns} />
          <ReportBlock title="audit_log trigger output" rows={data.tables.auditLog} columns={auditColumns} />
        </div>
      </Panel>
    </section>
  );
}

function ReportBlock({ title, rows, columns }: { title: string; rows: AnyRow[]; columns: Column[] }) {
  return (
    <div>
      <h4 className="mb-2 font-semibold">{title}</h4>
      <DataTable rows={rows.slice(0, 8)} columns={columns} />
    </div>
  );
}

function Panel({
  title,
  icon: Icon,
  children,
}: {
  title: string;
  icon: React.ComponentType<{ className?: string }>;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-md border border-[#d8e9d7] bg-white p-5 shadow-sm">
      <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold">
        <Icon className="size-5 text-[#2e6a43]" />
        {title}
      </h3>
      {children}
    </section>
  );
}

function FieldControl({
  field,
  value,
  onChange,
}: {
  field: Field;
  value: string;
  onChange: (value: string) => void;
}) {
  const base = "w-full rounded-md border border-[#cbdcca] bg-white px-3 text-sm outline-none focus:border-[#2e6a43]";

  return (
    <label className={field.type === "textarea" ? "md:col-span-2" : undefined}>
      <span className="mb-1 block text-sm font-semibold">
        {field.label}
        {field.required ? <span className="text-[#913325]"> *</span> : null}
      </span>
      {field.type === "select" ? (
        <select value={value} onChange={(event) => onChange(event.target.value)} required={field.required} className={`${base} h-11`}>
          <option value="">Select</option>
          {(field.options?.() ?? []).map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      ) : field.type === "textarea" ? (
        <textarea
          value={value}
          onChange={(event) => onChange(event.target.value)}
          required={field.required}
          placeholder={fieldPlaceholder(field)}
          className={`${base} min-h-24 py-3`}
        />
      ) : (
        <input
          type={field.type ?? "text"}
          value={value}
          onChange={(event) => onChange(event.target.value)}
          required={field.required}
          placeholder={fieldPlaceholder(field)}
          className={`${base} h-11`}
        />
      )}
    </label>
  );
}

function fieldValueForInput(value: unknown, type: Field["type"]) {
  if (value === null || value === undefined) return "";
  if (type === "datetime-local") {
    const date = new Date(String(value));
    if (Number.isNaN(date.getTime())) return "";
    return date.toISOString().slice(0, 16);
  }
  if (type === "date") return String(value).slice(0, 10);
  return String(value);
}

function fieldPlaceholder(field: Field) {
  const examples: Record<string, string> = {
    color: "Example: White",
    mileage: "Example: 12500",
    daily_rate: "Example: 45",
    first_name: "Example: Ali",
    last_name: "Example: Khan",
    email: "Example: ali.khan@example.com",
    phone: "Example: +923001234567",
    driver_license_no: "Example: DL-LHR-20001",
    license_plate: "Example: LHR-500",
    vin: "17 characters, unique",
    amount: "Example: 120",
    additional_charges: "Example: 50",
    salary: "Example: 85000",
    cost: "Example: 300",
    repair_cost: "Example: 500",
    description: "Write short details",
    notes: "Optional notes",
  };

  return examples[field.name] ?? field.label;
}

function DataTable({ rows, columns }: { rows: AnyRow[]; columns: Column[] }) {
  if (!rows.length) {
    return <div className="rounded-md border border-dashed border-[#cbdcca] p-6 text-center text-sm text-[#5c705f]">No rows to display.</div>;
  }

  return (
    <div className="overflow-x-auto rounded-md border border-[#d8e9d7]">
      <table className="min-w-full divide-y divide-[#d8e9d7] text-left text-sm">
        <thead className="bg-[#f6fbf4] text-xs uppercase tracking-normal text-[#5c705f]">
          <tr>
            {columns.map((column) => (
              <th key={column.label} className="px-3 py-3 font-semibold">
                {column.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-[#edf4eb] bg-white">
          {rows.map((row, index) => (
            <tr key={`${JSON.stringify(row).slice(0, 40)}-${index}`} className="hover:bg-[#f6fbf4]">
              {columns.map((column) => (
                <td key={column.label} className="max-w-[260px] px-3 py-3 align-top">
                  <span className="line-clamp-2">{asText(column.value(row))}</span>
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function statusOptions(values: string[]) {
  return values.map((value) => ({ value, label: value }));
}

function recordLabel(resource: ResourceName, row: AnyRow) {
  if (resource === "vehicles") return labelVehicle(row);
  if (resource === "customers") return labelCustomer(row);
  if (resource === "staff") return labelStaff(row);
  if (resource === "branches") return labelBranch(row);
  if (resource === "models") return labelModel(row);
  if (resource === "categories") return String(row.name ?? row.category_id);
  if (resource === "insurance") return `${row.policy_number ?? ""} - ${asText(row.vehicle)}`;
  if (resource === "payments") return `${formatMoney(row.amount)} - ${row.payment_method ?? ""}`;
  if (resource === "maintenance") return `${row.maintenance_type ?? ""} - ${asText(row.vehicle)}`;
  if (resource === "damage-reports") return `${row.severity ?? ""} - ${asText(row.vehicle)}`;
  return String(row[`${resource.slice(0, -1)}_id`] ?? row.contract_id ?? row.reservation_id ?? "Record");
}

function tableColumns(resource: ResourceName): Column[] {
  const common = {
    vehicles: [
      { label: "Plate", value: (row: AnyRow) => row.license_plate },
      { label: "Model", value: (row: AnyRow) => row.model },
      { label: "Branch", value: (row: AnyRow) => row.branch },
      { label: "Status", value: (row: AnyRow) => row.status },
      { label: "Rate", value: (row: AnyRow) => formatMoney(row.daily_rate) },
    ],
    customers: [
      { label: "Customer", value: labelCustomer },
      { label: "Email", value: (row: AnyRow) => row.email },
      { label: "Phone", value: (row: AnyRow) => row.phone },
      { label: "License", value: (row: AnyRow) => row.driver_license_no },
      { label: "Expiry", value: (row: AnyRow) => row.license_expiry },
    ],
    reservations: [
      { label: "Customer", value: (row: AnyRow) => row.customer },
      { label: "Vehicle", value: (row: AnyRow) => row.vehicle },
      { label: "Pickup", value: (row: AnyRow) => row.pickup_date },
      { label: "Return", value: (row: AnyRow) => row.return_date },
      { label: "Status", value: (row: AnyRow) => row.status },
    ],
    contracts: [
      { label: "Customer", value: (row: AnyRow) => row.customer },
      { label: "Vehicle", value: (row: AnyRow) => row.vehicle },
      { label: "Staff", value: (row: AnyRow) => row.staff },
      { label: "Status", value: (row: AnyRow) => row.status },
      { label: "Total", value: (row: AnyRow) => formatMoney(row.total_amount) },
    ],
    payments: [
      { label: "Amount", value: (row: AnyRow) => formatMoney(row.amount) },
      { label: "Method", value: (row: AnyRow) => row.payment_method },
      { label: "Status", value: (row: AnyRow) => row.status },
      { label: "Date", value: (row: AnyRow) => row.payment_date },
      { label: "Transaction", value: (row: AnyRow) => row.transaction_id },
    ],
    maintenance: [
      { label: "Vehicle", value: (row: AnyRow) => row.vehicle },
      { label: "Type", value: (row: AnyRow) => row.maintenance_type },
      { label: "Status", value: (row: AnyRow) => row.status },
      { label: "Start", value: (row: AnyRow) => row.start_date },
      { label: "Cost", value: (row: AnyRow) => formatMoney(row.cost) },
    ],
    "damage-reports": [
      { label: "Vehicle", value: (row: AnyRow) => row.vehicle },
      { label: "Severity", value: (row: AnyRow) => row.severity },
      { label: "Status", value: (row: AnyRow) => row.status },
      { label: "Cost", value: (row: AnyRow) => formatMoney(row.repair_cost) },
      { label: "Description", value: (row: AnyRow) => row.description },
    ],
    insurance: [
      { label: "Vehicle", value: (row: AnyRow) => row.vehicle },
      { label: "Policy", value: (row: AnyRow) => row.policy_number },
      { label: "Provider", value: (row: AnyRow) => row.provider },
      { label: "Ends", value: (row: AnyRow) => row.end_date },
      { label: "Active", value: (row: AnyRow) => row.is_active },
    ],
    branches: [
      { label: "Branch", value: (row: AnyRow) => row.name },
      { label: "City", value: (row: AnyRow) => row.city },
      { label: "Phone", value: (row: AnyRow) => row.phone },
      { label: "Email", value: (row: AnyRow) => row.email },
      { label: "Manager", value: (row: AnyRow) => row.manager_id },
    ],
    staff: [
      { label: "Name", value: labelStaff },
      { label: "Email", value: (row: AnyRow) => row.email },
      { label: "Phone", value: (row: AnyRow) => row.phone },
      { label: "Salary", value: (row: AnyRow) => formatMoney(row.salary) },
      { label: "Active", value: (row: AnyRow) => row.is_active },
    ],
    categories: [
      { label: "Name", value: (row: AnyRow) => row.name },
      { label: "Description", value: (row: AnyRow) => row.description },
      { label: "Base rate", value: (row: AnyRow) => formatMoney(row.base_daily_rate) },
      { label: "Created", value: (row: AnyRow) => row.created_at },
    ],
    models: [
      { label: "Model", value: labelModel },
      { label: "Category", value: (row: AnyRow) => row.category },
      { label: "Fuel", value: (row: AnyRow) => row.fuel_type },
      { label: "Transmission", value: (row: AnyRow) => row.transmission },
      { label: "Seats", value: (row: AnyRow) => row.passenger_capacity },
    ],
  };

  return common[resource] ?? [];
}

const availableColumns: Column[] = [
  { label: "Plate", value: (row) => row.license_plate },
  { label: "Vehicle", value: (row) => `${row.make ?? ""} ${row.model_name ?? ""}` },
  { label: "Category", value: (row) => row.category },
  { label: "Branch", value: (row) => row.branch_name },
  { label: "Rate", value: (row) => formatMoney(row.daily_rate) },
];

const attentionColumns: Column[] = [
  { label: "Vehicle", value: (row) => row.vehicle_name ?? row.license_plate },
  { label: "Branch", value: (row) => row.branch_name },
  { label: "Status", value: (row) => row.expiry_status ?? row.status ?? "Maintenance due" },
  { label: "Date", value: (row) => row.last_service_date ?? row.end_date },
];

const customerHistoryColumns: Column[] = [
  { label: "Customer", value: (row) => row.customer_name },
  { label: "Email", value: (row) => row.email },
  { label: "Rentals", value: (row) => row.total_rentals },
  { label: "Spent", value: (row) => formatMoney(row.total_spent) },
  { label: "Last rental", value: (row) => row.last_rental_date },
];

const activeContractColumns: Column[] = [
  { label: "Customer", value: (row) => row.customer_name },
  { label: "Vehicle", value: (row) => row.vehicle_name },
  { label: "Pickup", value: (row) => row.actual_pickup_date },
  { label: "Handled by", value: (row) => row.handled_by },
  { label: "Rate", value: (row) => formatMoney(row.agreed_daily_rate) },
];

const insuranceColumns: Column[] = [
  { label: "Vehicle", value: (row) => row.vehicle_name },
  { label: "Provider", value: (row) => row.provider },
  { label: "Policy", value: (row) => row.policy_number },
  { label: "Days", value: (row) => row.days_until_expiry },
  { label: "Status", value: (row) => row.expiry_status },
];

const auditColumns: Column[] = [
  { label: "Table", value: (row) => row.table_name },
  { label: "Operation", value: (row) => row.operation },
  { label: "Record", value: (row) => row.record_id },
  { label: "Changed", value: (row) => row.changed_at },
  { label: "User", value: (row) => row.changed_by },
];
