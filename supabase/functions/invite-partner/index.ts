import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createSupabaseClient } from '../_shared/supabaseClient.ts'
import { corsHeaders } from '../_shared/cors.ts'

console.log('Edge Function "invite-partner" (v2) is up and running!')

serve(async (req) => {
  // 1. Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 2. Get the invitee_email from the request body
    const { invitee_email } = await req.json()
    if (!invitee_email) {
      throw new Error('Missing invitee_email in request body')
    }

    // 3. Create a Supabase client authenticated as the user
    const supabase = createSupabaseClient(req)

    // 4. Get the user's ID and household ID
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) {
      throw new Error('User not found')
    }

    const { data: userProfile, error: profileError } = await supabase
      .from('users')
      .select('household_id')
      .eq('id', user.id)
      .single()

    if (profileError) throw profileError
    if (!userProfile || !userProfile.household_id) {
      throw new Error('User profile or household not found.')
    }

    // 5. Create the invite
    const inviteData = {
      household_id: userProfile.household_id,
      inviter_id: user.id,
      invitee_email: invitee_email,
      status: 'pending',
    }

    // --- THIS IS THE VERIFIED FIX ---
    // We just insert the data and don't ask for it back.
    const { error: insertError } = await supabase
      .from('household_invites')
      .insert(inviteData)
    // --- END FIX ---

    if (insertError) {
      // This could fail from RLS or the UNIQUE constraint
      console.error('Insert error:', insertError.message)
      throw insertError
    }

    // 6. Success! Return a simple success message
    return new Response(JSON.stringify({ success: true, sent_to: invitee_email }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    // Handle any errors
    console.error('Error in invite-partner:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})