-- 1. Enable RLS (no change)
ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goal_contributions ENABLE ROW LEVEL SECURITY;

-- 2. Drop the old, incorrect 'FOR ALL' policy
DROP POLICY IF EXISTS "Enable ALL access for household members on goals" ON public.goals;

-- 3. Create specific, correct policies for 'goals'
CREATE POLICY "Enable READ access for household members"
ON public.goals FOR SELECT
USING (
  (SELECT household_id FROM public.users WHERE id = auth.uid()) = household_id
);

CREATE POLICY "Enable INSERT access for household members"
ON public.goals FOR INSERT
WITH CHECK (
  (SELECT household_id FROM public.users WHERE id = auth.uid()) = household_id
);

CREATE POLICY "Enable UPDATE access for household members"
ON public.goals FOR UPDATE
USING (
  (SELECT household_id FROM public.users WHERE id = auth.uid()) = household_id
)
WITH CHECK (
  (SELECT household_id FROM public.users WHERE id = auth.uid()) = household_id
);

CREATE POLICY "Enable DELETE access for household members"
ON public.goals FOR DELETE
USING (
  (SELECT household_id FROM public.users WHERE id = auth.uid()) = household_id
);


-- 4. Drop old 'goal_contributions' policies (just in case)
DROP POLICY IF EXISTS "Enable INSERT for household members on goal_contributions" ON public.goal_contributions;
DROP POLICY IF EXISTS "Enable READ for household members on goal_contributions" ON public.goal_contributions;
DROP POLICY IF EXISTS "Enable READ for household members on goal_contributions" ON public.goal_contributions;
DROP POLICY IF EXISTS "Enable INSERT access for household members" ON public.goal_contributions;


-- 5. Create specific, correct policies for 'goal_contributions'
CREATE POLICY "Enable READ access for household members"
ON public.goal_contributions FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.goals g
    JOIN public.users u ON g.household_id = u.household_id
    WHERE u.id = auth.uid() AND g.id = goal_contributions.goal_id
  )
);

CREATE POLICY "Enable INSERT access for household members"
ON public.goal_contributions FOR INSERT
WITH CHECK (
  user_id = auth.uid()
  AND
  EXISTS (
    SELECT 1
    FROM public.goals g
    JOIN public.users u ON g.household_id = u.household_id
    WHERE u.id = auth.uid() AND g.id = goal_contributions.goal_id
  )
);