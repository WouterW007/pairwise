import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.44.4';
import { type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.44.4';

// Utility function to create a Supabase client
export function createSupabaseClient(
  req: Request,
  isServiceRole: boolean = false
): SupabaseClient {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    throw new Error('Missing Authorization header.');
  }

  // Options for the client
  const options = {
    global: {
      headers: {
        Authorization: authHeader,
      },
    },
    // If service role is requested, use the service role key
    ...(isServiceRole && {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false,
        // Use the service role key from environment variables
        // This bypasses RLS
        apiKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      },
    }),
  };

  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    // If not service role, use the anon key (RLS will be enforced)
    isServiceRole
      ? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      : Deno.env.get('SUPABASE_ANON_KEY')!,
    options
  );
}

// Utility function to get the user ID from the auth header
export async function getUserId(supabase: SupabaseClient): Promise<string> {
  const { data, error } = await supabase.auth.getUser();
  if (error) throw error;
  if (!data.user) throw new Error('User not found.');
  return data.user.id;
}

// --- NEW FUNCTION TO ADD ---
// Utility function to get the user's household ID
export async function getHouseholdId(
  supabase: SupabaseClient
): Promise<string | null> {
  const userId = await getUserId(supabase);

  // Query the profiles table for the household ID
  const { data: profile, error } = await supabase
          .from('users') // <-- MAKE SURE THIS SAYS 'users'
          .select('household_id')
          .eq('id', userId)
          .single();

  if (error) {
    console.error('Error fetching profile:', error.message);
    throw new Error(error.message);
  }

  return profile?.household_id || null;
}
