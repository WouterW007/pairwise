import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from './cors.ts'

// This helper creates a Supabase admin client for server-side tasks
// OR a user-specific client if an auth header is provided.
export function createSupabaseClient(req: Request, useServiceRole = false) {
  const authHeader = req.headers.get('Authorization')

  // If we want to use the service role (admin) key
  if (useServiceRole) {
    return createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )
  }

  // Default: Create a client scoped to the user
  if (!authHeader) {
    throw new Error('Missing Authorization header')
  }

  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    {
      global: { headers: { Authorization: authHeader } },
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    }
  )
}