-- This function transactionally adds a contribution and updates the goal's total.
CREATE OR REPLACE FUNCTION public.add_goal_contribution(
  goal_id_to_add_to UUID,
  contribution_amount NUMERIC
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER -- Use DEFINER to bypass RLS, as our logic is secure
SET search_path = public
AS $$
DECLARE
  user_household_id UUID;
  goal_household_id UUID;
BEGIN
  -- 1. Get the user's household ID
  SELECT household_id INTO user_household_id
  FROM public.users
  WHERE id = auth.uid();

  IF user_household_id IS NULL THEN
    RAISE EXCEPTION 'User household not found.';
  END IF;

  -- 2. Get the goal's household ID to ensure it matches
  SELECT household_id INTO goal_household_id
  FROM public.goals
  WHERE id = goal_id_to_add_to;

  IF goal_household_id IS NULL THEN
    RAISE EXCEPTION 'Goal not found.';
  END IF;

  -- 3. Security Check: Ensure the user belongs to the same household as the goal
  IF user_household_id <> goal_household_id THEN
    RAISE EXCEPTION 'User is not authorized to contribute to this goal.';
  END IF;

  -- 4. Insert the new contribution
  INSERT INTO public.goal_contributions (goal_id, user_id, amount)
  VALUES (goal_id_to_add_to, auth.uid(), contribution_amount);

  -- 5. Atomically update the goal's current amount
  UPDATE public.goals
  SET current_amount = current_amount + contribution_amount
  WHERE id = goal_id_to_add_to;

END;
$$;