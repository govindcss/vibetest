-- Supabase Row Level Security (RLS) Policies for Event-Based Communities Feature

-- Helper function to check if a user is a member of an event.
-- SECURITY DEFINER allows this function to bypass RLS internally to check membership.
CREATE OR REPLACE FUNCTION public.is_event_member(p_event_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM public.event_users eu
        WHERE eu.event_id = p_event_id AND eu.user_id = p_user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
COMMENT ON FUNCTION public.is_event_member(UUID, UUID) IS 'Checks if a given user is a member of a specific event. Runs with definer privileges to check event_users table.';

-- Helper function to get a user's role in an event.
-- SECURITY DEFINER allows this function to bypass RLS internally.
CREATE OR REPLACE FUNCTION public.get_event_role(p_event_id UUID, p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_role TEXT;
BEGIN
    SELECT role INTO v_role
    FROM public.event_users eu
    WHERE eu.event_id = p_event_id AND eu.user_id = p_user_id;
    RETURN v_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
COMMENT ON FUNCTION public.get_event_role(UUID, UUID) IS 'Retrieves the role of a user in a specific event. Runs with definer privileges.';

-- Helper function to check if a user is an event host (either original creator or has 'host' role).
-- SECURITY DEFINER allows this function to bypass RLS internally.
CREATE OR REPLACE FUNCTION public.is_event_host(p_event_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS ( -- Check if user is the creator of the event
        SELECT 1
        FROM public.events e
        WHERE e.id = p_event_id AND e.created_by = p_user_id
    ) OR (public.get_event_role(p_event_id, p_user_id) = 'host'); -- Check if user has 'host' role in event_users
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
COMMENT ON FUNCTION public.is_event_host(UUID, UUID) IS 'Checks if a user is considered a host of an event (either creator or has ''host'' role). Runs with definer privileges.';

-- Grant execute on helper functions to the 'authenticated' role.
-- This allows authenticated users to call these functions in their RLS policies.
GRANT EXECUTE ON FUNCTION public.is_event_member(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_event_role(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_event_host(UUID, UUID) TO authenticated;


-- 1. RLS for 'events' table
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow select for public events, members, or creators"
ON public.events
FOR SELECT
USING (
    is_public = TRUE OR -- Public events are visible to anyone (including anonymous if anon role has select)
    (auth.role() = 'authenticated' AND public.is_event_member(id, auth.uid())) OR -- Members can see events they joined
    (auth.role() = 'authenticated' AND created_by = auth.uid()) -- Creators can see their own events
);
COMMENT ON POLICY "Allow select for public events, members, or creators" ON public.events IS 'Users can select public events, events they are members of, or events they created.';

CREATE POLICY "Allow authenticated users to insert events"
ON public.events
FOR INSERT
TO authenticated -- Specify role explicitly
WITH CHECK (created_by = auth.uid()); -- Ensure created_by is set to the current user
COMMENT ON POLICY "Allow authenticated users to insert events" ON public.events IS 'Authenticated users can create new events; created_by is enforced.';

CREATE POLICY "Allow update for creators or hosts"
ON public.events
FOR UPDATE
TO authenticated
USING (public.is_event_host(id, auth.uid())) -- Only creators or hosts can update
WITH CHECK (public.is_event_host(id, auth.uid())); -- Ensure the condition remains true after update
COMMENT ON POLICY "Allow update for creators or hosts" ON public.events IS 'Only event creators or users with a ''host'' role can update event details.';

CREATE POLICY "Allow delete for creators or hosts"
ON public.events
FOR DELETE
TO authenticated
USING (public.is_event_host(id, auth.uid())); -- Only creators or hosts can delete
COMMENT ON POLICY "Allow delete for creators or hosts" ON public.events IS 'Only event creators or users with a ''host'' role can delete events.';


-- 2. RLS for 'event_users' table
ALTER TABLE public.event_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow select own entries or other members of same event"
ON public.event_users
FOR SELECT
TO authenticated
USING (
    user_id = auth.uid() OR -- Users can see their own membership details
    EXISTS ( -- Users can see other members if they are also a member of that event
        SELECT 1
        FROM public.event_users eu_check
        WHERE eu_check.user_id = auth.uid() AND eu_check.event_id = public.event_users.event_id
    )
);
COMMENT ON POLICY "Allow select own entries or other members of same event" ON public.event_users IS 'Users can see their own event memberships and other members of events they are part of.';

CREATE POLICY "Allow authenticated users to join public events or if host (future: invites)"
ON public.event_users
FOR INSERT
TO authenticated
WITH CHECK (
    user_id = auth.uid() AND -- Users can only insert themselves
    EXISTS ( -- Check if the event they are trying to join is public
        SELECT 1 FROM public.events e
        WHERE e.id = public.event_users.event_id AND e.is_public = TRUE
    )
    -- TODO: Extend with logic for private event invites or hosts adding users.
    -- OR public.is_event_host(public.event_users.event_id, auth.uid()) -- Example: Allow host to add anyone (careful with roles)
);
COMMENT ON POLICY "Allow authenticated users to join public events or if host (future: invites)" ON public.event_users IS 'Users can join public events. Future: Implement invite system for private events.';


CREATE POLICY "Allow users to leave or hosts/creators to remove others"
ON public.event_users
FOR DELETE
TO authenticated
USING (
    user_id = auth.uid() OR -- Users can remove themselves (leave event)
    public.is_event_host(event_id, auth.uid()) -- Event hosts can remove any user from their event
);
COMMENT ON POLICY "Allow users to leave or hosts/creators to remove others" ON public.event_users IS 'Users can leave events. Event hosts can remove users from their events.';


-- 3. RLS for 'event_chats' table
ALTER TABLE public.event_chats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow select for event members"
ON public.event_chats
FOR SELECT
TO authenticated
USING (public.is_event_member(event_id, auth.uid()));
COMMENT ON POLICY "Allow select for event members" ON public.event_chats IS 'Only members of an event can read its chat messages.';

CREATE POLICY "Allow insert for event members"
ON public.event_chats
FOR INSERT
TO authenticated
WITH CHECK (
    user_id = auth.uid() AND -- Users can only send messages as themselves
    public.is_event_member(event_id, auth.uid()) -- Only members of an event can post messages
);
COMMENT ON POLICY "Allow insert for event members" ON public.event_chats IS 'Only members of an event can send chat messages, and only as themselves.';
-- Note: Updates/Deletes on chat messages are typically disallowed or handled by moderators with elevated privileges.


-- 4. RLS for 'event_forum_threads' table
ALTER TABLE public.event_forum_threads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow select for event members"
ON public.event_forum_threads
FOR SELECT
TO authenticated
USING (public.is_event_member(event_id, auth.uid()));
COMMENT ON POLICY "Allow select for event members" ON public.event_forum_threads IS 'Only members of an event can read its forum threads.';

CREATE POLICY "Allow insert for event members"
ON public.event_forum_threads
FOR INSERT
TO authenticated
WITH CHECK (
    user_id = auth.uid() AND -- Users can only create threads as themselves
    public.is_event_member(event_id, auth.uid()) -- Only members of an event can create threads
);
COMMENT ON POLICY "Allow insert for event members" ON public.event_forum_threads IS 'Only members of an event can create forum threads, and only as themselves.';

CREATE POLICY "Allow update for thread creators or event hosts"
ON public.event_forum_threads
FOR UPDATE
TO authenticated
USING (
    user_id = auth.uid() OR -- Thread creator can update their own thread
    public.is_event_host(event_id, auth.uid()) -- Event hosts can update any thread in their event
)
WITH CHECK (
    user_id = auth.uid() OR
    public.is_event_host(event_id, auth.uid())
);
COMMENT ON POLICY "Allow update for thread creators or event hosts" ON public.event_forum_threads IS 'Thread creators can update their own threads. Event hosts can update any thread in their event.';

CREATE POLICY "Allow delete for thread creators or event hosts"
ON public.event_forum_threads
FOR DELETE
TO authenticated
USING (
    user_id = auth.uid() OR -- Thread creator can delete their own thread
    public.is_event_host(event_id, auth.uid()) -- Event hosts can delete any thread in their event
);
COMMENT ON POLICY "Allow delete for thread creators or event hosts" ON public.event_forum_threads IS 'Thread creators can delete their own threads. Event hosts can delete any thread in their event.';


-- 5. RLS for 'event_forum_replies' table
ALTER TABLE public.event_forum_replies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow select replies for event members"
ON public.event_forum_replies
FOR SELECT
TO authenticated
USING (
    EXISTS ( -- Check if the user is a member of the event to which the parent thread belongs
        SELECT 1
        FROM public.event_forum_threads eft
        WHERE eft.id = public.event_forum_replies.thread_id AND public.is_event_member(eft.event_id, auth.uid())
    )
);
COMMENT ON POLICY "Allow select replies for event members" ON public.event_forum_replies IS 'Only members of the event (associated with the parent thread) can read replies.';

CREATE POLICY "Allow insert replies for event members"
ON public.event_forum_replies
FOR INSERT
TO authenticated
WITH CHECK (
    user_id = auth.uid() AND -- Users can only post replies as themselves
    EXISTS ( -- Check if the user is a member of the event to which the parent thread belongs
        SELECT 1
        FROM public.event_forum_threads eft
        WHERE eft.id = public.event_forum_replies.thread_id AND public.is_event_member(eft.event_id, auth.uid())
    )
);
COMMENT ON POLICY "Allow insert replies for event members" ON public.event_forum_replies IS 'Only members of the event (associated with the parent thread) can post replies, and only as themselves.';

CREATE POLICY "Allow update for reply creators or event hosts"
ON public.event_forum_replies
FOR UPDATE
TO authenticated
USING (
    user_id = auth.uid() OR -- Reply creator can update their own reply
    EXISTS ( -- Event hosts can update any reply in their event's threads
        SELECT 1
        FROM public.event_forum_threads eft
        WHERE eft.id = public.event_forum_replies.thread_id AND public.is_event_host(eft.event_id, auth.uid())
    )
)
WITH CHECK (
    user_id = auth.uid() OR
    EXISTS (
        SELECT 1
        FROM public.event_forum_threads eft
        WHERE eft.id = public.event_forum_replies.thread_id AND public.is_event_host(eft.event_id, auth.uid())
    )
);
COMMENT ON POLICY "Allow update for reply creators or event hosts" ON public.event_forum_replies IS 'Reply creators can update their own replies. Event hosts can update any reply in threads of their event.';

CREATE POLICY "Allow delete for reply creators or event hosts"
ON public.event_forum_replies
FOR DELETE
TO authenticated
USING (
    user_id = auth.uid() OR -- Reply creator can delete their own reply
    EXISTS ( -- Event hosts can delete any reply in their event's threads
        SELECT 1
        FROM public.event_forum_threads eft
        WHERE eft.id = public.event_forum_replies.thread_id AND public.is_event_host(eft.event_id, auth.uid())
    )
);
COMMENT ON POLICY "Allow delete for reply creators or event hosts" ON public.event_forum_replies IS 'Reply creators can delete their own replies. Event hosts can delete any reply in threads of their event.';

-- General Note on RLS:
-- `auth.role() = 'authenticated'` is used to ensure policies apply to logged-in users.
-- `auth.uid()` provides the ID of the currently authenticated user.
-- Helper functions (`is_event_member`, `get_event_role`, `is_event_host`) are defined with `SECURITY DEFINER`
-- to allow them to query tables they need access to, regardless of the calling user's direct RLS permissions on those tables.
-- This is a common and powerful pattern but requires that the helper functions themselves are secure and do not leak data inadvertently.
-- The policies here are examples and might need further refinement based on specific application security requirements (e.g., handling anonymous users, more granular roles).```
File rls_policies.sql overwritten successfully.
```
**Review of `rls_policies.sql`:**

*   **Clarity & Readability:**
    *   Added `COMMENT ON FUNCTION` and `COMMENT ON POLICY` for all helper functions and RLS policies to explain their purpose and logic.
    *   Explicitly specified `public.` schema for all functions and tables.
    *   Improved formatting for better readability.
*   **Correctness & RLS Logic:**
    *   **Helper Functions:** Ensured all helper functions are `SECURITY DEFINER` as this is critical for them to correctly check permissions across tables RLS might otherwise restrict for the calling user.
    *   **Events Table:**
        *   SELECT: Clarified that public events are visible to anyone (if `anon` role has SELECT permission on the table, which is typical in Supabase). Added `auth.role() = 'authenticated'` checks for member/creator specific visibility.
        *   INSERT: Added `TO authenticated` and ensured `created_by` is set to `auth.uid()`.
        *   UPDATE/DELETE: Verified use of `is_event_host`.
    *   **Event Users Table:**
        *   SELECT: Logic seems sound.
        *   INSERT: Modified the policy to be more explicit: users can join *public* events. Left a TODO comment about future enhancements for private event invites or hosts adding users directly, as this can get complex (e.g., host adding another user with a specific role).
        *   DELETE: Logic for leaving or being removed by host is correct.
    *   **Event Chats, Forum Threads, Forum Replies:**
        *   SELECT policies correctly use `is_event_member` (directly or indirectly via parent thread).
        *   INSERT policies ensure `user_id = auth.uid()` and the user is an event member.
        *   UPDATE/DELETE policies for forum content allow the content creator OR an event host to modify/delete. This is a common pattern.
    *   **General:**
        *   Consistently used `auth.uid()` for current user checks.
        *   Added `TO authenticated` for INSERT/UPDATE/DELETE policies for clarity on which roles these policies apply to. The `USING` clause is for rows the operation *applies to* (for SELECT, UPDATE, DELETE), and the `WITH CHECK` clause is for rows that are *being inserted or updated*.
        *   Added a general note at the end about RLS principles used.

The RLS policies are now more thoroughly documented and have some minor logical clarifications (e.g., joining public events). The structure using helper functions is good.

Next, I'll start reviewing the Flutter code, beginning with the models. I will add DartDocs and check for any refinements. I'll do this file by file.

Starting with `lib/models/event.dart`.
