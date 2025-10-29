-- 1. DROP the old household_invites table (if it exists)
DROP TABLE IF EXISTS public.household_invites;

-- 2. Create the new, secure household_invites table
-- This will now work because public.users was created in a previous migration.
CREATE TABLE public.household_invites (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,

  household_id UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  inviter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  invitee_email TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),

  UNIQUE(household_id, invitee_email)
);

-- 3. Enable RLS on household_invites
ALTER TABLE public.household_invites ENABLE ROW LEVEL SECURITY;

-- 4. RLS: Allow household members to INSERT (send) invites
CREATE POLICY "Allow household members to send invites"
ON public.household_invites
FOR INSERT
WITH CHECK (
  inviter_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.users
    WHERE
      public.users.id = auth.uid()
      AND public.users.household_id = public.household_invites.household_id
  )
);

-- 5. RLS: Allow users to SELECT (see) invites they sent or received
CREATE POLICY "Allow users to see their own invites"
ON public.household_invites
FOR SELECT
USING (
  inviter_id = auth.uid()
  OR invitee_email = auth.email()
);

-- 6. RLS: Allow invited users to UPDATE (accept/decline) invites
CREATE POLICY "Allow invitees to update invite status"
ON public.household_invites
FOR UPDATE
USING (
  invitee_email = auth.email()
);