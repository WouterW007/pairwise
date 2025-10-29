import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { encode } from 'https://deno.land/std@0.208.0/encoding/base64.ts';

// --- Crypto Helper Functions ---

// Imports the raw key string into a format SubtleCrypto can use
async function importKey(keyString: string) {
  const keyData = atob(keyString);
  const keyBuffer = new Uint8Array(keyData.length);
  for (let i = 0; i < keyData.length; i++) {
    keyBuffer[i] = keyData.charCodeAt(i);
  }
  return await crypto.subtle.importKey(
    'raw',
    keyBuffer,
    { name: 'AES-GCM' },
    false,
    ['encrypt']
  );
}

// Encrypts plaintext with the imported key
async function encrypt(plaintext: string, key: CryptoKey) {
  const iv = crypto.getRandomValues(new Uint8Array(12)); // 96-bit IV
  const encodedText = new TextEncoder().encode(plaintext);

  const ciphertext = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv: iv },
    key,
    encodedText
  );

  // We store the IV and the ciphertext together as one string
  const ivString = encode(iv);
  const cipherString = encode(new Uint8Array(ciphertext));

  return `${ivString}:${cipherString}`;
}

// --- Edge Function ---

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { public_token } = await req.json();
    if (!public_token) throw new Error('Missing public_token');

    // 1. Get secrets
    const PLAID_CLIENT_ID = Deno.env.get('PLAID_CLIENT_ID');
    const PLAID_SECRET = Deno.env.get('PLAID_SECRET');
    const ENCRYPTION_KEY_STRING = Deno.env.get('ENCRYPTION_KEY');
    if (!ENCRYPTION_KEY_STRING) throw new Error('Missing ENCRYPTION_KEY');

    // 2. Import the encryption key
    const cryptoKey = await importKey(ENCRYPTION_KEY_STRING);

    // 3. Get user
    const authHeader = req.headers.get('Authorization')!;
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError) throw userError;
    const userId = user!.id;

    // 4. Exchange Plaid token
    const plaidRequest = {
      client_id: PLAID_CLIENT_ID,
      secret: PLAID_SECRET,
      public_token: public_token,
    };
    const plaidRes = await fetch(`https://sandbox.plaid.com/item/public_token/exchange`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(plaidRequest),
    });
    if (!plaidRes.ok) throw new Error(await plaidRes.text());
    const { access_token, item_id } = await plaidRes.json();

    // 5. Encrypt the access_token
    const encryptedAccessToken = await encrypt(access_token, cryptoKey);

    // 6. Store in database and return the new row's ID
    const { data: newRow, error: insertError } = await supabaseClient
      .from('plaid_items')
      .insert({
        user_id: userId,
        plaid_item_id: item_id,
        access_token: encryptedAccessToken, // Save the new encrypted string
      })
      .select('id') // Ask Supabase to return the 'id' of the new row
      .single(); // We only expect one row back

    if (insertError) throw insertError;
    if (!newRow) throw new Error('Failed to retrieve new row from database.');

    // 7. Return the IDs to the client (THIS BLOCK IS NOW CORRECT)
    return new Response(JSON.stringify({
      success: true,
      plaid_item_id: item_id, // Plaid's item ID
      db_item_uuid: newRow.id // Our database's UUID for this item
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) { // The error was a missing '});' before this line
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});