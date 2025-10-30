import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createSupabaseClient } from '../_shared/supabaseClient.ts'
import { corsHeaders } from '../_shared/cors.ts'

console.log('Edge Function "plaid-fetch-accounts" (v_DEBUG_UNIQUE) is up!') // v_DEBUG_UNIQUE

serve(async (req) => {
  console.log('--- plaid-fetch-accounts invoked ---');
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { plaid_item_id, db_item_uuid } = await req.json()
    console.log(`Received plaid_item_id: ${plaid_item_id}, db_item_uuid: ${db_item_uuid}`);
    if (!plaid_item_id || !db_item_uuid) {
      throw new Error('Missing plaid_item_id or db_item_uuid')
    }

    const supabase = createSupabaseClient(req)
    console.log('Supabase client created for user.');

    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error('User not found')
    console.log(`Authenticated user ID: ${user.id}`);

    console.log(`Querying public.users for id = ${user.id}...`);
    const { data: userProfileData, error: profileQueryError } = await supabase
      .from('users')
      .select('household_id')
      .eq('id', user.id);

    console.log('Raw user profile query result:', JSON.stringify(userProfileData));
    console.log('User profile query error (if any):', profileQueryError);

    if (profileQueryError) throw profileQueryError;
    if (!userProfileData || userProfileData.length === 0) {
      throw new Error(`User profile not found in public.users for id ${user.id}`);
    }

    const userProfile = userProfileData[0];
    console.log(`User profile found: household_id=${userProfile.household_id}`);

    const supabaseAdmin = createSupabaseClient(req, true)

    const mockAccounts = [
      { account_id: 'fake_account_id_1', name: 'Plaid Checking', mask: '0000', type: 'depository', subtype: 'checking', balances: { current: 110.00 }, },
      { account_id: 'fake_account_id_2', name: 'Plaid Credit Card', mask: '3333', type: 'credit', subtype: 'credit card', balances: { current: 410.00 }, },
      { account_id: 'fake_account_id_3', name: 'Plaid Saving', mask: '1111', type: 'depository', subtype: 'savings', balances: { current: 210.00 }, },
    ];

    // --- THIS IS THE FIX ---
    // We make the plaid_account_id unique by appending the db_item_uuid
    const accountsToInsert = mockAccounts.map((account) => ({
      plaid_account_id: `${account.account_id}_${db_item_uuid}`, // <-- THIS MAKES IT UNIQUE
      plaid_item_id: db_item_uuid,
      user_id: user.id,
      household_id: userProfile.household_id,
      name: account.name,
      mask: account.mask,
      type: account.type,
      subtype: account.subtype,
      current_balance: account.balances.current,
      visibility: 'private',
    }));
    // --- END FIX ---

    console.log(`Attempting to insert ${accountsToInsert.length} accounts...`);

    const { error: insertError } = await supabase
      .from('accounts')
      .insert(accountsToInsert)

    if (insertError) {
      console.error('Account insert error:', insertError);
      throw insertError;
    }
    console.log('Accounts inserted successfully.');

    return new Response(JSON.stringify({ success: true, accounts: accountsToInsert }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error in plaid-fetch-accounts:', error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})