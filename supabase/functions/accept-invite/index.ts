import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createSupabaseClient } from '../_shared/supabaseClient.ts'
import { corsHeaders } from '../_shared/cors.ts'

console.log('Edge Function "accept-invite" is up and running!')

serve(async (req) => {
  // 1. Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 2. Get the invite_id from the request body
    const { invite_id } = await req.json()
    if (!invite_id) {
      throw new Error('Missing invite_id in request body')
    }

    // 3. Create a Supabase client authenticated as the user
    const supabase = createSupabaseClient(req)

    // 4. Call our new database function (RPC)
    // This is the core of our function.
    const { error } = await supabase.rpc('accept_invite', {
      invite_id_to_accept: invite_id,
    })

    if (error) {
      console.error('RPC error:', error.message)
      throw error
    }

    // 5. Success!
    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    // Handle any errors
    console.error('Error in accept-invite:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})