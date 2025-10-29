--
-- Policy: Allow users to insert transactions for their OWN accounts
--
-- This policy allows an 'INSERT' operation on the 'transactions' table
-- only if the user owns the account being linked.
--
CREATE POLICY "Enable insert for account owners"
ON public.transactions
FOR INSERT
WITH CHECK (
  -- We check that the 'account_id' on the new transaction
  -- exists in the 'accounts' table, AND that the 'user_id'
  -- on that account matches the currently authenticated user.
  EXISTS (
    SELECT 1
    FROM public.accounts
    WHERE
      public.accounts.id = public.transactions.account_id
      AND public.accounts.user_id = auth.uid()
  )
);