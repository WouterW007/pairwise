-- 1. Drop/Create the household_invites table
DROP TABLE IF EXISTS public.household_invites;
CREATE TABLE public.household_invites (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  household_id UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  inviter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  invitee_email TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  UNIQUE(household_id, invitee_email)
);

-- 2. Enable RLS on household_invites
ALTER TABLE public.household_invites ENABLE ROW LEVEL SECURITY;

-- 3. RLS: Allow household members to INSERT (send) invites
CREATE POLICY "Allow household members to send invites"
ON public.household_invites
FOR INSERT
WITH CHECK (
  inviter_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.users
    WHERE public.users.id = auth.uid()
    AND public.users.household_id = public.household_invites.household_id
  )
);

-- 4. RLS: Allow users to SELECT (see) invites
CREATE POLICY "Allow users to see their own invites"
ON public.household_invites
FOR SELECT
USING (
  inviter_id = auth.uid()
  OR invitee_email = auth.email()
);

-- 5. RLS: Allow invitees to UPDATE (accept/decline) invites
CREATE POLICY "Allow invitees to update invite status"
ON public.household_invites
FOR UPDATE
USING (
  invitee_email = auth.email()
);

-- 6. Create the accept_invite RPC function
CREATE OR REPLACE FUNCTION public.accept_invite(
  invite_id_to_accept UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
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