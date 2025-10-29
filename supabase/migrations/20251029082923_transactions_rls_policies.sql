-- Policy: Allow users to see transactions linked to their OWN accounts
CREATE POLICY "Enable read access for own transactions"
ON public.transactions
FOR SELECT
USING (
  auth.uid() = (
    SELECT user_id FROM public.accounts WHERE id = transactions.account_id
  )
);

-- Policy: Allow users to see transactions linked to SHARED accounts in their household
CREATE POLICY "Enable read access for shared household transactions"
ON public.transactions
FOR SELECT
USING (
  -- FIX: Changed 'public.profiles' to 'public.users'
  (SELECT household_id FROM public.users WHERE id = auth.uid()) = household_id
  AND (
    SELECT visibility FROM public.accounts WHERE id = transactions.account_id
  ) = 'shared'
);