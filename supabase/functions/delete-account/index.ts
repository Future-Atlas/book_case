import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (request.method !== 'POST') {
    return Response.json(
      { error: 'Method not allowed' },
      { status: 405, headers: corsHeaders },
    )
  }

  const body = await request.json().catch(() => null)
  if (body?.confirmation !== true) {
    return Response.json(
      { error: 'Explicit confirmation is required' },
      { status: 400, headers: corsHeaders },
    )
  }

  const authorization = request.headers.get('Authorization')
  const token = authorization?.replace(/^Bearer\s+/i, '')
  if (!token) {
    return Response.json(
      { error: 'Unauthorized' },
      { status: 401, headers: corsHeaders },
    )
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !serviceRoleKey) {
    return Response.json(
      { error: 'Server configuration is incomplete' },
      { status: 500, headers: corsHeaders },
    )
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  const { data: userData, error: userError } = await admin.auth.getUser(token)
  if (userError || !userData.user) {
    return Response.json(
      { error: 'Unauthorized' },
      { status: 401, headers: corsHeaders },
    )
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(
    userData.user.id,
  )
  if (deleteError) {
    return Response.json(
      { error: deleteError.message },
      { status: 500, headers: corsHeaders },
    )
  }

  return Response.json({ deleted: true }, { headers: corsHeaders })
})
