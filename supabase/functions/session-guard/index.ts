import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function response(body: Record<string, unknown>, status = 200) {
  return Response.json(body, { status, headers: corsHeaders });
}

function readClientIp(request: Request): string | null {
  const forwardedFor = request.headers.get("x-forwarded-for");
  if (forwardedFor && forwardedFor.trim().length > 0) {
    const first = forwardedFor.split(",")[0]?.trim() ?? "";
    if (first) return first;
  }

  const realIp = request.headers.get("x-real-ip")?.trim();
  if (realIp) return realIp;

  return null;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS")
    return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST")
    return response({ error: "Method not allowed" }, 405);

  const token = request.headers
    .get("Authorization")
    ?.replace(/^Bearer\s+/i, "");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!token || !supabaseUrl || !serviceRoleKey || !anonKey) {
    return response({ error: "Unauthorized or incomplete configuration" }, 401);
  }

  const clientIp = readClientIp(request);
  if (!clientIp) {
    return response({ error: "Client IP unavailable" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user)
    return response({ error: "Unauthorized" }, 401);

  // Execute RPC with authenticated user context so auth.uid() resolves correctly.
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const userAgent = (request.headers.get("user-agent") ?? "").slice(0, 500);
  const { data, error } = await userClient.rpc("check_session_ip_change", {
    p_ip: clientIp,
    p_user_agent: userAgent,
  });

  if (error) {
    return response({ error: error.message }, 500);
  }

  const row = Array.isArray(data) ? data[0] : null;
  const ipChanged = row?.ip_changed === true;
  return response({
    ok: true,
    profileId: userData.user.id,
    ipChanged,
    previousIp: row?.previous_ip ?? null,
    currentIp: row?.current_ip ?? clientIp,
    changedAt: row?.changed_at ?? null,
  });
});
