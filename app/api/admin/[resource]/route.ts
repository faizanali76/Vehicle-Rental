import { createSupabaseAdmin } from "@/lib/supabase/server";
import { cleanPayload, resources } from "@/lib/resources";
import type { ResourceName } from "@/lib/types";

type Context = {
  params: Promise<{ resource: string }>;
};

function getConfig(resource: string) {
  const config = resources[resource as ResourceName];
  return config ? { resource: resource as ResourceName, config } : null;
}

export async function GET(_request: Request, context: Context) {
  const { resource } = await context.params;
  const resolved = getConfig(resource);
  if (!resolved) return Response.json({ error: "Unknown resource." }, { status: 404 });
  const { config } = resolved;

  const supabase = createSupabaseAdmin();
  const { data, error } = await supabase.from(config.table).select("*").limit(100);

  if (error) return Response.json({ error: error.message }, { status: 400 });
  return Response.json(data);
}

export async function POST(request: Request, context: Context) {
  const { resource } = await context.params;
  const resolved = getConfig(resource);
  if (!resolved) return Response.json({ error: "Unknown resource." }, { status: 404 });
  const { config } = resolved;

  const supabase = createSupabaseAdmin();
  const body = (await request.json()) as Record<string, unknown>;

  if (resource === "reservations") {
    const { data, error } = await supabase.rpc("rental_ops_create_reservation", {
      p_customer_id: body.customer_id,
      p_vehicle_id: body.vehicle_id,
      p_pickup_branch: body.pickup_branch_id,
      p_return_branch: body.return_branch_id,
      p_pickup_date: body.pickup_date,
      p_return_date: body.return_date,
    });

    if (error) return Response.json({ error: error.message }, { status: 400 });
    return Response.json({ reservation_id: data }, { status: 201 });
  }

  const payload = cleanPayload(body, config.createFields);
  const { data, error } = await supabase.from(config.table).insert(payload).select().single();

  if (error) return Response.json({ error: error.message }, { status: 400 });
  return Response.json(data, { status: 201 });
}

export async function PATCH(request: Request, context: Context) {
  const { resource } = await context.params;
  const resolved = getConfig(resource);
  if (!resolved) return Response.json({ error: "Unknown resource." }, { status: 404 });
  const { config } = resolved;

  const supabase = createSupabaseAdmin();
  const body = (await request.json()) as Record<string, unknown>;
  const id = body.id;
  if (!id) return Response.json({ error: "Record id is required." }, { status: 400 });

  if (resource === "contracts" && body.action === "close") {
    const { data, error } = await supabase.rpc("rental_ops_close_contract", {
      p_contract_id: id,
      p_actual_return_date: body.actual_return_date,
      p_additional_charges: Number(body.additional_charges || 0),
    });

    if (error) return Response.json({ error: error.message }, { status: 400 });
    return Response.json({ total_amount: data });
  }

  const payload = cleanPayload(body, config.updateFields);
  const { data, error } = await supabase
    .from(config.table)
    .update(payload)
    .eq(config.id, id)
    .select()
    .single();

  if (error) return Response.json({ error: error.message }, { status: 400 });
  return Response.json(data);
}

export async function DELETE(request: Request, context: Context) {
  const { resource } = await context.params;
  const resolved = getConfig(resource);
  if (!resolved) return Response.json({ error: "Unknown resource." }, { status: 404 });
  const { config } = resolved;

  const supabase = createSupabaseAdmin();
  const { searchParams } = new URL(request.url);
  const id = searchParams.get("id");
  if (!id) return Response.json({ error: "Record id is required." }, { status: 400 });

  if (config.softDelete) {
    const { data, error } = await supabase
      .from(config.table)
      .update(config.softDelete)
      .eq(config.id, id)
      .select()
      .single();

    if (error) return Response.json({ error: error.message }, { status: 400 });
    return Response.json(data);
  }

  const { error } = await supabase.from(config.table).delete().eq(config.id, id);
  if (error) return Response.json({ error: error.message }, { status: 400 });
  return Response.json({ ok: true });
}
