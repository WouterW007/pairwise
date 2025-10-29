-- This file just enables RLS for the financial tables.
-- The users table RLS is handled in the '...financial_tables.sql' file.

ALTER TABLE public.plaid_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;