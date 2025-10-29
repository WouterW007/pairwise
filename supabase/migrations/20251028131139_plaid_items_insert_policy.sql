-- Policy: Allow users to insert their own Plaid items
CREATE POLICY "Enable insert for own plaid_items"
ON public.plaid_items
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Allow users to read their own Plaid items
CREATE POLICY "Enable read access for own plaid_items"
ON public.plaid_items
FOR SELECT
USING (auth.uid() = user_id);