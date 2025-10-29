-- 1. Households Table
-- This table stores the shared "couple" entity and their subscription status.
CREATE TABLE public.households (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now() NOT NULL,
    apple_original_transaction_id text UNIQUE,
    apple_product_id text,
    subscription_status text,
    subscription_expires_at timestamptz
);

-- 2. Profiles Table
-- This links Supabase's auth.users to our household data.
CREATE TABLE public.profiles (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    updated_at timestamptz DEFAULT now(),
    full_name text,
    avatar_url text,
    household_id uuid REFERENCES public.households(id) ON DELETE SET NULL
);

-- 3. Household Invites Table
-- This manages the invitation flow for partners to join a household.
CREATE TABLE public.household_invites (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
    inviter_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    invitee_email text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL
);