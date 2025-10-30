-- This function will be triggered after a new user signs up.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_household_id uuid;
BEGIN
  -- 1. Create a new household for the user.
  INSERT INTO public.households (name)
  VALUES ('My Household')
  RETURNING id INTO new_household_id;

  -- 2. Create a profile for the user in public.users.
  -- === THIS IS THE FIX ===
  -- We now also insert the user's email
  INSERT INTO public.users (id, email, household_id)
  VALUES (NEW.id, NEW.email, new_household_id);
  -- === END FIX ===

  RETURN NEW;
END;
$$;

-- Create the trigger that calls the function after each new user signup.
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_new_user();