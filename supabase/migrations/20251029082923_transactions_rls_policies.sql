-- Policy: Allow users to see transactions linked to their OWN accounts
-- (This implicitly covers private accounts based on the accounts RLS)
CREATE POLICY "Enable read access for own transactions"
ON public.transactions
FOR SELECT
USING (
  -- Check if the user owns the account linked to the transaction
  auth.uid() = (
    SELECT user_id FROM public.accounts WHERE id = transactions.account_id
  )
);

-- Policy: Allow users to see transactions linked to SHARED accounts in their household
CREATE POLICY "Enable read access for shared household transactions"
ON public.transactions
FOR SELECT
USING (
  -- Check if the transaction's household_id matches the user's household_id
  (SELECT household_id FROM public.profiles WHERE id = auth.uid()) = household_id
  -- AND ensure the linked account is actually marked as shared
  AND (
    SELECT visibility FROM public.accounts WHERE id = transactions.account_id
  ) = 'shared'
);

-- Note: We don't need an INSERT policy for authenticated users yet,
-- as the Edge Function uses the service_role which bypasses RLS.