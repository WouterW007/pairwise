-- 1. DROP the old household_invites table (if it exists)
DROP TABLE IF EXISTS public.household_invites;

-- 2. Create the new, secure household_invites table
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
-- (This policy is unchanged and correct)
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
-- === THIS IS THE FIX ===
DROP POLICY IF EXISTS "Allow users to see their own invites" ON public.household_invites;
CREATE POLICY "Allow users to see their own invites"
ON public.household_invites
FOR SELECT
USING (
  -- Condition 1: You are the inviter
  inviter_id = auth.uid()

  OR -- <--- THE FIX: UN-COMMENTED THIS LINE

  -- Condition 2: You are the invitee
  invitee_email = (
    SELECT email
    FROM public.users
    WHERE id = auth.uid()
  )
);
-- === END FIX ===

-- 6. RLS: Allow invited users to UPDATE (accept/decline) invites
-- === THIS IS THE FIX ===
DROP POLICY IF EXISTS "Allow invitees to update invite status" ON public.household_invites;
CREATE POLICY "Allow invitees to update invite status"
ON public.household_invites
FOR UPDATE
USING (
  -- (This also now checks against your 'public.users' email)
  invitee_email = (
    SELECT email
    FROM public.users
    WHERE id = auth.uid()
  )
);
-- === END FIX ===