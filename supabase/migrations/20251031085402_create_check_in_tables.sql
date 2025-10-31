-- 1. Create the 'check_in_sessions' table
-- This stores the "header" for a specific money date
CREATE TABLE public.check_in_sessions (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    -- We can add a title later, e.g., "Money Date - Oct 2025"
    title TEXT
);

-- 2. Create the 'check_in_messages' table
-- This stores each individual prompt and reply
CREATE TABLE public.check_in_messages (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id uuid NOT NULL REFERENCES public.check_in_sessions(id) ON DELETE CASCADE,
    -- user_id is nullable:
    -- If NULL, it's a "prompt" from the app
    -- If NOT NULL, it's a "reply" from a user
    user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    "order" smallint NOT NULL DEFAULT 0, -- To keep messages in sequence
    content TEXT NOT NULL -- The prompt text or the user's reply
);

-- 3. Enable RLS on both tables
ALTER TABLE public.check_in_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.check_in_messages ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for 'check_in_sessions'
-- Allow household members to do anything with their *own* sessions
CREATE POLICY "Enable ALL access for household members on sessions"
ON public.check_in_sessions
FOR ALL
USING (
  (SELECT household_id FROM public.users WHERE id = auth.uid()) = household_id
)
WITH CHECK (
  (SELECT household_id FROM public.users WHERE id = auth.uid()) = household_id
);

-- 5. RLS Policies for 'check_in_messages'
-- Allow household members to read messages from their *own* sessions
CREATE POLICY "Enable READ access for household members on messages"
ON public.check_in_messages
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.check_in_sessions s
    JOIN public.users u ON s.household_id = u.household_id
    WHERE u.id = auth.uid() AND s.id = check_in_messages.session_id
  )
);

-- Allow household members to insert messages into their *own* sessions
CREATE POLICY "Enable INSERT access for household members on messages"
ON public.check_in_messages
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.check_in_sessions s
    JOIN public.users u ON s.household_id = u.household_id
    WHERE u.id = auth.uid() AND s.id = check_in_messages.session_id
  )
);