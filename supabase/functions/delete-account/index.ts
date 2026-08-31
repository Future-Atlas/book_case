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

  const { error: prepareError } = await admin.rpc(
    'prepare_self_account_deletion',
    { target_profile: userData.user.id },
  )
  if (prepareError) {
    return Response.json(
      { error: prepareError.message },
      { status: 500, headers: corsHeaders },
    )
  }

  const { data: auditId, error: auditError } = await admin.rpc(
    'prepare_deleted_account_record',
    {
      target_profile: userData.user.id,
      deletion_kind: 'self',
      deleting_admin: null,
      deletion_notes: 'User-requested account withdrawal',
    },
  )
  if (auditError || !auditId) {
    await admin.rpc('cancel_self_account_deletion', {
      target_profile: userData.user.id,
    })
    return Response.json(
      { error: auditError?.message ?? 'Unable to record account deletion' },
      { status: 500, headers: corsHeaders },
    )
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(
    userData.user.id,
  )
  if (deleteError) {
    await admin.rpc('cancel_self_account_deletion', {
      target_profile: userData.user.id,
    })
    await admin.rpc('finalize_deleted_account_record', {
      audit_record: auditId,
      succeeded: false,
      failure_message: deleteError.message,
    })
    return Response.json(
      { error: deleteError.message },
      { status: 500, headers: corsHeaders },
    )
  }

  await admin.rpc('finalize_deleted_account_record', {
    audit_record: auditId,
    succeeded: true,
    failure_message: null,
  })

  return Response.json({ deleted: true }, { headers: corsHeaders })
})
