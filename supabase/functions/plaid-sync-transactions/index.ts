import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createSupabaseClient } from '../_shared/supabaseClient.ts'
import { corsHeaders } from '../_shared/cors.ts'

console.log('Edge Function "plaid-sync-transactions" (v_FIXED_2) is up!')

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { plaid_item_id, db_item_uuid } = await req.json()
    if (!plaid_item_id || !db_item_uuid) {
      throw new Error('Missing plaid_item_id or db_item_uuid')
    }

    // Create BOTH clients
    const supabase = createSupabaseClient(req)
    const supabaseAdmin = createSupabaseClient(req, true) // <-- Admin client

    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error('User not found')

    const { data: userProfile, error: profileError } = await supabase
      .from('users')
      .select('household_id')
      .eq('id', user.id)
      .single()

    if (profileError) throw profileError
    if (!userProfile) throw new Error('User profile not found')

    const mockTransactions = [
      {
        transaction_id: 'tx_1',
        account_id: 'fake_account_id_1',
        name: 'Uber 072515 SF**POOL**',
        amount: 6.33,
        date: '2025-10-29',
        category: 'Travel',
        merchant_name: 'Uber',
        pending: false,
        iso_currency_code: 'USD',
      },
      {
        transaction_id: 'tx_2',
        account_id: 'fake_account_id_2',
        name: 'Tectra Inc',
        amount: 500.00,
        date: '2025-10-28',
        category: 'Services',
        merchant_name: 'Tectra Inc',
        pending: false,
        iso_currency_code: 'USD',
      },
    ]

    // --- THIS IS THE FIX ---
    // Use the supabaseAdmin client to bypass RLS for this internal read.
    const { data: accounts, error: accountError } = await supabaseAdmin
      .from('accounts')
      .select('id, plaid_account_id')
      .eq('plaid_item_id', db_item_uuid)
    // --- END FIX ---

    if (accountError) throw accountError
    if (!accounts || accounts.length === 0) {
      console.warn(`No accounts found for plaid_item_id: ${db_item_uuid}`)
      throw new Error('No accounts found for this item')
    }

    const accountIdMap = new Map(accounts.map((a) => [a.plaid_account_id, a.id]))

    const transactionsToInsert = mockTransactions
      .map((tx) => {
        const internalAccountId = accountIdMap.get(tx.account_id)
        if (!internalAccountId) {
          console.warn(
            `Skipping tx: ${tx.name}, no matching account found for plaid_account_id ${tx.account_id}`
          )
          return null
        }
        return {
          plaid_transaction_id: tx.transaction_id,
          account_id: internalAccountId,
          household_id: userProfile.household_id,
          name: tx.name,
          amount: tx.amount,
          date: tx.date,
          category: tx.category,
          merchant_name: tx.merchant_name,
          pending: tx.pending,
          iso_currency_code: tx.iso_currency_code,
        }
      })
      .filter(Boolean)

    if (transactionsToInsert.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No new transactions to insert.',
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      )
    }

    const { error: insertError } = await supabase
      .from('transactions')
      .insert(transactionsToInsert)

    if (insertError) throw insertError

    return new Response(
      JSON.stringify({ success: true, inserted: transactionsToInsert.length }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})