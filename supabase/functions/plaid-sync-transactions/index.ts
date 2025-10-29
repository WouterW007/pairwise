import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { decrypt } from '../_shared/decrypt.ts'; // Import our decrypt function

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Get Item UUID from request
    const { db_item_uuid } = await req.json();
    if (!db_item_uuid) throw new Error('Missing db_item_uuid');

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

    // 4. Find the Plaid Item and its associated accounts in our database
    // We need account_id mappings for saving transactions
    const { data: itemData, error: fetchError } = await supabase
      .from('plaid_items')
      .select(`
        id,
        access_token,
        user_id,
        accounts ( id, plaid_account_id )
      `)
      .eq('id', db_item_uuid)
      .eq('user_id', user.id)
      .single();

    if (fetchError) throw new Error(`Plaid item not found: ${fetchError.message}`);

    // Create a lookup map: Plaid Account ID -> Our DB Account UUID
    const accountIdMap = new Map<string, string>();
    itemData.accounts.forEach((acc: { id: string, plaid_account_id: string }) => {
      accountIdMap.set(acc.plaid_account_id, acc.id);
    });

    // 5. Decrypt the access_token
    const encryptedToken = itemData.access_token;
    const accessToken = await decrypt(encryptedToken, ENCRYPTION_KEY);

    // 6. Call Plaid's /transactions/sync endpoint
    // For simplicity, we'll fetch all available history initially.
    // In production, you'd manage the 'cursor' for incremental updates.
    const plaidRequest = {
      client_id: PLAID_CLIENT_ID,
      secret: PLAID_SECRET,
      access_token: accessToken,
      count: 100, // Fetch up to 100 transactions at a time
      // cursor: itemData.sync_cursor, // Add this later for delta updates
    };

    const plaidRes = await fetch(`https://sandbox.plaid.com/transactions/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(plaidRequest),
    });

    if (!plaidRes.ok) throw new Error(`Plaid API Error: ${await plaidRes.text()}`);
    const { added, modified, removed, next_cursor } = await plaidRes.json();

    // 7. Get the user's household_id
    const { data: profile } = await supabase
      .from('profiles')
      .select('household_id')
      .eq('id', user.id)
      .single();
    if (!profile) throw new Error('User profile not found');
    const householdId = profile.household_id;

    // 8. Format transactions for our database
    const transactionsToUpsert = [...added, ...modified].map((tx: any) => ({
      plaid_transaction_id: tx.transaction_id,
      account_id: accountIdMap.get(tx.account_id), // Map to our DB account ID
      household_id: householdId,
      name: tx.name,
      amount: tx.amount * -1, // Plaid amounts are negative for debits
      date: tx.date,
      category: tx.category?.join(', '), // Flatten category array
      pending: tx.pending,
    })).filter(tx => tx.account_id); // Filter out transactions for accounts not in our map

    // 9. Save transactions (Upsert handles both inserts and updates)
    if (transactionsToUpsert.length > 0) {
      const { error: upsertError } = await supabase
        .from('transactions')
        .upsert(transactionsToUpsert, { onConflict: 'plaid_transaction_id' }); // Use Plaid ID for conflict resolution
      if (upsertError) throw upsertError;
    }

    // 10. Handle removed transactions (optional for now)
    // You would typically mark these as deleted in your DB

    // 11. TODO: Save the next_cursor to plaid_items table for future syncs

    return new Response(JSON.stringify({
      success: true,
      added: added.length,
      modified: modified.length,
      removed: removed.length,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    console.error("Error syncing transactions:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});