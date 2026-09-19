import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
const headers = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' }
Deno.serve(async (request) => {
 if (request.method === 'OPTIONS') return new Response('ok', { headers })
 try {
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: request.headers.get('Authorization') ?? '' } } })
  const body = await request.json() as { action: 'block' | 'moderate'; userId?: string; blocked?: boolean; reason?: string; resource?: 'services' | 'service_requests'; resourceId?: string; status?: 'approved' | 'rejected' }
  const { data: role } = await supabase.rpc('current_role')
  if (role !== 'admin') return Response.json({ error: 'Forbidden' }, { status: 403, headers })
  if (body.action === 'block' && body.userId) await supabase.rpc('admin_set_user_block', { p_user_id: body.userId, p_blocked: Boolean(body.blocked), p_reason: body.reason ?? null })
  else if (body.action === 'moderate' && body.resource && body.resourceId && body.status) await supabase.rpc('admin_moderate', { p_table: body.resource, p_id: body.resourceId, p_status: body.status })
  else return Response.json({ error: 'Invalid request' }, { status: 400, headers })
  return Response.json({ ok: true }, { headers })
 } catch (error) { return Response.json({ error: error instanceof Error ? error.message : 'Unexpected error' }, { status: 500, headers }) }
})
