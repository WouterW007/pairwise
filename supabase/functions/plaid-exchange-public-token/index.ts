import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { encode } from 'https://deno.land/std@0.208.0/encoding/base64.ts'

// --- Crypto Helper Functions ---

// Imports the raw key string into a format SubtleCrypto can use
async function importKey(keyString: string) {
  const keyData = atob(keyString)
  const keyBuffer = new Uint8Array(keyData.length)
  for (let i = 0; i < keyData.length; i++) {
    keyBuffer[i] = keyData.charCodeAt(i)
  }
  return await crypto.subtle.importKey(
    'raw',
    keyBuffer,
    { name: 'AES-GCM' },
    false,
    ['encrypt']
  )
}

// Encrypts plaintext with the imported key
async function encrypt(plaintext: string, key: CryptoKey) {
  const iv = crypto.getRandomValues(new Uint8Array(12)) // 96-bit IV
  const encodedText = new TextEncoder().encode(plaintext)

  const ciphertext = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv: iv },
    key,
    encodedText
  )

  // We store the IV and the ciphertext together as one string
  const ivString = encode(iv)
  const cipherString = encode(new Uint8Array(ciphertext))

  return `${ivString}:${cipherString}`
}

// --- MOCK DATA (MOVED HERE) ---
const mockAccounts = [
  {
    account_id: 'fake_account_id_1',
    name: 'Plaid Checking',
    mask: '0000',
    type: 'depository',
    subtype: 'checking',
    balances: { current: 110.0 },
  },
  {
    account_id: 'fake_account_id_2',
    name: 'Plaid Credit Card',
    mask: '3333',
    type: 'credit',
    subtype: 'credit card',
    balances: { current: 410.0 },
  },
  {
    account_id: 'fake_account_id_3',
    name: 'Plaid Saving',
    mask: '1111',
    type: 'depository',
    subtype: 'savings',
    balances: { current: 210.0 },
  },
]

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
    amount: 500.0,
    date: '2025-10-28',
    category: 'Services',
    merchant_name: 'Tectra Inc',
    pending: false,
    iso_currency_code: 'USD',
  },
]

// --- MAIN FUNCTION (HEAVILY UPDATED) ---
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('--- plaid-exchange-public-token (v_COMBINED_UNIQUE) invoked ---') // Version updated
    const { public_token } = await req.json()
    if (!public_token) throw new Error('Missing public_token')

    // 1. Get secrets
    const PLAID_CLIENT_ID = Deno.env.get('PLAID_CLIENT_ID')
    const PLAID_SECRET = Deno.env.get('PLAID_SECRET')
    const ENCRYPTION_KEY_STRING = Deno.env.get('ENCRYPTION_KEY')
    if (!ENCRYPTION_KEY_STRING) throw new Error('Missing ENCRYPTION_KEY')

    const cryptoKey = await importKey(ENCRYPTION_KEY_STRING)

    // 2. Create Supabase admin client (we need it for all steps)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 3. Get user (from user's auth header)
    const authHeader = req.headers.get('Authorization')!
    const supabaseUserClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: { user }, error: userError } =
      await supabaseUserClient.auth.getUser()
    if (userError) throw userError
    const userId = user!.id
    console.log(`Step 1/5: Authenticated user: ${userId}`)

    // 4. Exchange Plaid token
    const plaidRequest = {
      client_id: PLAID_CLIENT_ID,
      secret: PLAID_SECRET,
      public_token: public_token,
    }
    const plaidRes = await fetch(
      `https://sandbox.plaid.com/item/public_token/exchange`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(plaidRequest),
      }
    )
    if (!plaidRes.ok) throw new Error(await plaidRes.text())
    const { access_token, item_id } = await plaidRes.json()
    console.log(`Step 2/5: Plaid token exchanged for item_id: ${item_id}`)

    // 5. Encrypt and Store Plaid Item
    const encryptedAccessToken = await encrypt(access_token, cryptoKey)
    const { data: newPlaidItem, error: insertItemError } =
      await supabaseUserClient
        .from('plaid_items')
        .insert({
          user_id: userId,
          plaid_item_id: item_id,
          access_token: encryptedAccessToken,
        })
        .select('id')
        .single()

    if (insertItemError) throw insertItemError
    const dbItemUuid = newPlaidItem.id
    console.log(`Step 3/5: Plaid item saved to DB with UUID: ${dbItemUuid}`)

    // 6. Get User's Household ID
    const { data: userProfile, error: profileError } = await supabaseUserClient
      .from('users')
      .select('household_id')
      .eq('id', userId)
      .single()
    if (profileError) throw profileError
    const householdId = userProfile.household_id

    // --- START INLINED LOGIC FROM plaid-fetch-accounts ---

    // --- THIS IS THE FIX ---
    // We make the plaid_account_id unique by appending the db_item_uuid
    const accountsToInsert = mockAccounts.map((account) => ({
      plaid_account_id: `${account.account_id}_${dbItemUuid}`, // <-- THIS MAKES IT UNIQUE
      plaid_item_id: dbItemUuid,
      user_id: userId,
      household_id: householdId,
      name: account.name,
      mask: account.mask,
      type: account.type,
      subtype: account.subtype,
      current_balance: account.balances.current,
      visibility: 'private',
    }))
    // --- END FIX ---

    // Insert accounts using ADMIN client to bypass RLS check
    const { data: insertedAccounts, error: insertAcctError } =
      await supabaseAdmin
        .from('accounts')
        .insert(accountsToInsert)
        .select('id, plaid_account_id') // Return the new IDs

    if (insertAcctError) {
      console.error('Error inserting accounts:', insertAcctError.message) // Better logging
      throw insertAcctError
    }
    console.log(`Step 4/5: Inserted ${insertedAccounts.length} accounts.`)
    // --- END INLINED LOGIC ---

    // --- START INLINED LOGIC FROM plaid-sync-transactions ---
    // This logic is now correct because `insertedAccounts` has the new unique IDs
    const accountIdMap = new Map(
      insertedAccounts.map((a: any) => [a.plaid_account_id, a.id])
    )

    const transactionsToInsert = mockTransactions
      .map((tx) => {
        // --- THIS IS THE SECOND PART OF THE FIX ---
        // We look up the *new unique ID* for the transaction
        const uniqueMockAccountId = `${tx.account_id}_${dbItemUuid}`
        const internalAccountId = accountIdMap.get(uniqueMockAccountId) // <-- Use the unique ID
        // --- END FIX ---

        if (!internalAccountId) {
          console.warn(
            `Skipping tx: ${tx.name}, no matching account found for ${uniqueMockAccountId}.`
          )
          return null
        }
        return {
          plaid_transaction_id: `${tx.transaction_id}_${dbItemUuid}`, // <-- Also make tx ID unique
          account_id: internalAccountId,
          household_id: householdId,
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

    if (transactionsToInsert.length > 0) {
      // Insert transactions using ADMIN client
      const { error: insertTxError } = await supabaseAdmin
        .from('transactions')
        .insert(transactionsToInsert)

      if (insertTxError) {
        console.error('Error inserting transactions:', insertTxError.message) // Better logging
        throw insertTxError
      }
      console.log(
        `Step 5/5: Inserted ${transactionsToInsert.length} transactions.`
      )
    } else {
      console.log(`Step 5/5: No transactions to insert.`)
    }
    // --- END INLINED LOGIC ---

    // 7. Return one final success message
    return new Response(JSON.stringify({ success: true, all_synced: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error in plaid-exchange-public-token:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})