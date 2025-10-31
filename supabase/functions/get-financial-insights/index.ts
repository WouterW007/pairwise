
import { serve } from 'std/http/server.ts';
import {
  createSupabaseClient,
  getHouseholdId,
} from '../_shared/supabaseClient.ts';
import { corsHeaders } from '../_shared/cors.ts';

// Get the Gemini API Key from Supabase secrets
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');
const GEMINI_API_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=${GEMINI_API_KEY}`;

serve(async (req) => {
  // Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Create a Supabase client with the user's auth token
    const supabase = createSupabaseClient(req);

    // 2. Get the user's household ID
    const householdId = await getHouseholdId(supabase);
    if (!householdId) {
      throw new Error('User is not associated with a household.');
    }

    // 3. Create a Supabase service-role client to query data securely
    // We use this to query all household data *after* verifying the user
    const serviceRoleClient = createSupabaseClient(req, true);

    // 4. Fetch the last 30 days of transactions for the household
    const thirtyDaysAgo = new Date(
      new Date().setDate(new Date().getDate() - 30)
    ).toUTCString();

    const { data: transactions, error: txError } = await serviceRoleClient
      .from('transactions')
      .select('name, amount, category, date')
      .eq('household_id', householdId)
      .gt('date', thirtyDaysAgo); // Get last 30 days

    if (txError) throw txError;
    if (!transactions || transactions.length === 0) {
      return new Response(
        JSON.stringify({
          insight: "We couldn't find any recent transactions to analyze. Link an account to get started!",
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      );
    }

    // 5. Format the data for the LLM prompt
    // We only send the necessary data, not the full objects
    const formattedData = transactions
      .map((tx) => `${tx.date}: ${tx.name} ($${tx.amount.toFixed(2)})`)
      .join('\n');

    const systemPrompt = `
      You are a friendly and neutral financial assistant for couples.
      Your goal is to provide a brief, helpful insight (2-3 sentences max) based on their spending.
      Do not give strict financial advice. Instead, gently point out patterns or large spending areas to foster discussion.
      The couple's names are not known, so use "you" or "your household".
      The data is a list of recent transactions.
    `;

    const userQuery = `
      Here is our recent spending data:
      ${formattedData}

      What is one helpful insight you see from this?
    `;

    // 6. Call the Gemini API
    const geminiPayload = {
      contents: [{ parts: [{ text: userQuery }] }],
      systemInstruction: {
        parts: [{ text: systemPrompt }],
      },
    };

    const geminiResponse = await fetch(GEMINI_API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(geminiPayload),
    });

    if (!geminiResponse.ok) {
      const errorBody = await geminiResponse.text();
      throw new Error(`Gemini API error: ${errorBody}`);
    }

    const geminiResult = await geminiResponse.json();
    const insightText = geminiResult.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!insightText) {
      throw new Error('Could not parse insight from Gemini response.');
    }

    // 7. Return the insight to the Flutter app
    return new Response(JSON.stringify({ insight: insightText }), {
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

