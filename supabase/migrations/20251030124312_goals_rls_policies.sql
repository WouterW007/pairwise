-- 1. Enable RLS for goals and contributions
ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goal_contributions ENABLE ROW LEVEL SECURITY;

-- 2. Policy for 'goals' table
-- Allow household members to see and manage goals for their household.
CREATE POLICY "Enable ALL access for household members on goals"
ON public.goals
FOR ALL
USING (
  (SELECT household_id FROM public.users WHERE id = auth.uid()) = household_id
)
WITH CHECK (
  (SELECT household_id FROM public.users WHERE id = auth.uid()) = household_id
);

-- 3. Policy for 'goal_contributions' table
-- Allow users to insert contributions for their own household's goals.
CREATE POLICY "Enable INSERT for household members on goal_contributions"
ON public.goal_contributions
FOR INSERT
WITH CHECK (
  -- User must be the one making the contribution
  user_id = auth.uid()
  AND
  -- The goal must belong to the user's household
  EXISTS (
    SELECT 1
    FROM public.goals g
    JOIN public.users u ON g.household_id = u.household_id
    WHERE u.id = auth.uid() AND g.id = goal_contributions.goal_id
  )
);

-- Allow users to READ contributions for their own household's goals.
CREATE POLICY "Enable READ for household members on goal_contributions"
ON public.goal_contributions
FOR SELECT
USING (
  -- The goal must belong to the user's household
  EXISTS (
    SELECT 1
    FROM public.goals g
    JOIN public.users u ON g.household_id = u.household_id
    WHERE u.id = auth.uid() AND g.id = goal_contributions.goal_id
  )
);