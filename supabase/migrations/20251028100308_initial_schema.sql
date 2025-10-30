-- 1. Households Table
CREATE TABLE public.households (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT, -- FIX: Added the 'name' column
    created_at timestamptz DEFAULT now() NOT NULL,
    apple_original_transaction_id text UNIQUE,
    apple_product_id text,
    subscription_status text,
    subscription_expires_at timestamptz
);

-- 2. Users Table (Renamed from 'profiles')
CREATE TABLE public.users (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    updated_at timestamptz DEFAULT now(),
    full_name text,
    avatar_url text,
    household_id uuid REFERENCES public.households(id) ON DELETE SET NULL,


    email TEXT UNIQUE -- We need this to check invites

);