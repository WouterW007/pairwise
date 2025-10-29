import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

// Plaid API configuration
const PLAID_CLIENT_ID = Deno.env.get('PLAID_CLIENT_ID');
const PLAID_SECRET = Deno.env.get('PLAID_SECRET');
// Use 'sandbox' for testing, 'development' or 'production' later
const PLAID_ENV = 'sandbox';
const PLAID_URL = `https://${PLAID_ENV}.plaid.com`;

serve(async (req) => {
  // Handle preflight OPTIONS request for CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Create a Supabase admin client to get the user
    const authHeader = req.headers.get('Authorization')!;
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );

    // 2. Get the authenticated user's ID
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError) throw userError;
    const userId = user!.id; // This is the unique ID for the Plaid user

    // 3. Prepare the request for Plaid
        const plaidRequest = {
          client_id: PLAID_CLIENT_ID,
          secret: PLAID_SECRET,
          user: {
            client_user_id: userId, // Link Plaid user to Supabase user
          },
          client_name: 'Pairwise',
          products: ['transactions'], // Per the game plan
          country_codes: ['US'], // Example, adjust as needed
          language: 'en',
          redirect_uri: 'http://localhost/',
        };

    // 4. Call Plaid's API to create a link_token
    const response = await fetch(`${PLAID_URL}/link/token/create`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(plaidRequest),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(`Plaid API error: ${JSON.stringify(error)}`);
    }

    const { link_token } = await response.json();

    // 5. Return the link_token to the Flutter app
    return new Response(JSON.stringify({ link_token }), {
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