-- This file ONLY creates the RPC function
-- It assumes 'household_invites' was created by the previous migration
CREATE OR REPLACE FUNCTION public.accept_invite(
  invite_id_to_accept UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER -- <-- THIS IS THE FIX
SET search_path = public -- Required for SECURITY DEFINER
AS $$
DECLARE
  household_to_join UUID;
  invitee_user_id UUID := auth.uid();
BEGIN
  -- 1. Update the invite status
  UPDATE public.household_invites
  SET status = 'accepted'
  WHERE
    id = invite_id_to_accept
    AND invitee_email = (SELECT email FROM auth.users WHERE id = invitee_user_id)
    AND status = 'pending'
  RETURNING household_id INTO household_to_join;

  -- 2. Check if update worked
  IF household_to_join IS NULL THEN
    RAISE EXCEPTION 'Invite not found or user not authorized.';
  END IF;

  -- 3. Update the user's profile
  UPDATE public.users
  SET household_id = household_to_join
  WHERE id = invitee_user_id;
END;
$$;