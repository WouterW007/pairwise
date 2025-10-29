-- 1. Create the public.users table to store profile data
-- THIS MUST BE CREATED BEFORE accounts, plaid_items, etc.
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  household_id UUID REFERENCES public.households(id) ON DELETE SET NULL
);

-- 2. Enable RLS on the new users table
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 3. Add policies for users to manage their own data
-- FIX: Added DROP POLICY for idempotency
DROP POLICY IF EXISTS "Allow users to see their own data" ON public.users;
CREATE POLICY "Allow users to see their own data"
ON public.users FOR SELECT
USING (auth.role() = 'authenticated'); -- REVERTED: Allow any logged-in user to read

-- FIX: Added DROP POLICY for idempotency
DROP POLICY IF EXISTS "Allow users to update their own data" ON public.users;
CREATE POLICY "Allow users to update their own data"
ON public.users FOR UPDATE USING (id = auth.uid());


--
-- NOW CREATE THE FINANCIAL TABLES
--

-- 4. Plaid Items Table
CREATE TABLE public.plaid_items (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    plaid_item_id text NOT NULL UNIQUE,
    access_token text NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL
);

-- 5. Accounts Table
CREATE TABLE public.accounts (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    plaid_account_id text NOT NULL UNIQUE,
    plaid_item_id uuid NOT NULL REFERENCES public.plaid_items(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
    name text NOT NULL,
    mask text,
    type text,
    subtype text,
    current_balance numeric(18, 4),
    visibility text DEFAULT 'private'::text NOT NULL
);

-- 6. Transactions Table
CREATE TABLE public.transactions (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    plaid_transaction_id text NOT NULL UNIQUE,
    account_id uuid NOT NULL REFERENCES public.accounts(id) ON DELETE CASCADE,
    household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
    name text NOT NULL,
    amount numeric(18, 4) NOT NULL,
    date date NOT NULL,
    category text,
    pending boolean DEFAULT false,
    iso_currency_code text,
    merchant_name text,
    created_at timestamptz DEFAULT now() NOT NULL
);

-- 7. Goals Table
CREATE TABLE public.goals (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
    name text NOT NULL,
    target_amount numeric(18, 4) NOT NULL,
    current_amount numeric(18, 4) DEFAULT 0 NOT NULL,
    due_date date,
    created_at timestamptz DEFAULT now()
);

-- 8. Goal Contributions Table
CREATE TABLE public.goal_contributions (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    goal_id uuid NOT NULL REFERENCES public.goals(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    amount numeric(18, 4) NOT NULL,
    contribution_date timestamptz DEFAULT now()
);