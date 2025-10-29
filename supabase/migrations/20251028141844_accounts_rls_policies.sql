-- Policy: Allow users to insert accounts for themselves
CREATE POLICY "Enable insert for own accounts"
ON public.accounts
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Allow users to see their own private accounts
CREATE POLICY "Enable read access for user's private accounts"
ON public.accounts
FOR SELECT
USING (auth.uid() = user_id AND visibility = 'private');

-- Policy: Allow users to see shared accounts within their household
CREATE POLICY "Enable read access for shared household accounts"
ON public.accounts
FOR SELECT
USING (
  -- FIX: Changed 'public.profiles' to 'public.users'
  (SELECT household_id FROM public.users WHERE id = auth.uid()) = household_id
  AND visibility = 'shared'
);

-- Policy: Allow users to update the visibility of their own accounts
CREATE POLICY "Enable update for own accounts"
ON public.accounts
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);