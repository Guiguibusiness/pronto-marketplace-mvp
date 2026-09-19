import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

type BookingInput = { quoteId: string; scheduledAt: string; addressText?: string }
const corsHeaders = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' }

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const auth = req.headers.get('Authorization') ?? ''
    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: auth } } })
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401, headers: corsHeaders })
    const input = await req.json() as BookingInput
    if (!input.quoteId || Number.isNaN(Date.parse(input.scheduledAt))) return Response.json({ error: 'Invalid booking data' }, { status: 400, headers: corsHeaders })
    const { data: quote, error: quoteError } = await supabase.from('quotes').select('id, professional_id, service_id, service_requests!inner(client_id)').eq('id', input.quoteId).single()
    if (quoteError || !quote || quote.service_requests.client_id !== user.id) return Response.json({ error: 'Quote not found' }, { status: 404, headers: corsHeaders })
    const { data, error } = await supabase.from('bookings').insert({ quote_id: quote.id, client_id: user.id, professional_id: quote.professional_id, service_id: quote.service_id, scheduled_at: input.scheduledAt, address_text: input.addressText ?? null }).select().single()
    if (error) throw error
    return Response.json({ booking: data }, { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  } catch (error) { return Response.json({ error: error instanceof Error ? error.message : 'Unexpected error' }, { status: 500, headers: corsHeaders }) }
})
