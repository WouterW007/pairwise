import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { decrypt } from '../_shared/decrypt.ts';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Get Plaid Item ID from request
    // We pass this from Flutter so we know WHICH item to fetch
    const { plaid_item_id } = await req.json();
    if (!plaid_item_id) throw new Error('Missing plaid_item_id');

    // 2. Get Secrets
    const PLAID_CLIENT_ID = Deno.env.get('PLAID_CLIENT_ID');
    const PLAID_SECRET = Deno.env.get('PLAID_SECRET');
    const ENCRYPTION_KEY = Deno.env.get('ENCRYPTION_KEY');
    if (!ENCRYPTION_KEY) throw new Error('Missing ENCRYPTION_KEY');

    // 3. Get user and Supabase client
    const authHeader = req.headers.get('Authorization')!;
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError) throw userError;

    // 4. Find the Plaid Item in our database
    const { data: item, error: fetchError } = await supabase
      .from('plaid_items')
      .select('access_token, user_id, id')
      .eq('plaid_item_id', plaid_item_id)
      .eq('user_id', user.id)
      .single();

    if (fetchError) throw new Error(`Plaid item not found: ${fetchError.message}`);

    // 5. Decrypt the access_token
    const encryptedToken = item.access_token;
    const accessToken = await decrypt(encryptedToken, ENCRYPTION_KEY);

    // 6. Call Plaid's /accounts/get endpoint
    const plaidRequest = {
      client_id: PLAID_CLIENT_ID,
      secret: PLAID_SECRET,
      access_token: accessToken,
    };

    const plaidRes = await fetch(`https://sandbox.plaid.com/accounts/get`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(plaidRequest),
    });

    if (!plaidRes.ok) throw new Error(await plaidRes.text());
    const { accounts, item: plaidItem } = await plaidRes.json();

    // 7. Get the user's household_id
    const { data: profile } = await supabase
      .from('profiles')
      .select('household_id')
      .eq('id', user.id)
      .single();

    if (!profile) throw new Error('User profile not found');

    // 8. Format accounts for our database
    const accountsToInsert = accounts.map((acc: any) => ({
      plaid_account_id: acc.account_id,
      plaid_item_id: item.id, // Our DB's UUID, not Plaid's
      user_id: user.id,
      household_id: profile.household_id,
      name: acc.name,
      mask: acc.mask,
      type: acc.type,
      subtype: acc.subtype,
      current_balance: acc.balances.current,
      // 'visibility' defaults to 'private'
    }));

    // 9. Save accounts to our 'accounts' table
    const { error: insertError } = await supabase
      .from('accounts')
      .insert(accountsToInsert);

    if (insertError) throw insertError;

    return new Response(JSON.stringify({ success: true, accounts_fetched: accounts.length }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});