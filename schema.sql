-- Supabase Schema for Event-Based Communities Feature

-- Enable UUID generation if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions; -- Specify schema for Supabase best practices

-- Note: Ensure PostGIS is enabled in your Supabase project for GEOGRAPHY type.
-- You can typically enable it via the Supabase Dashboard (Database -> Extensions -> PostGIS).
-- CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;
-- CREATE EXTENSION IF NOT EXISTS postgis_topology WITH SCHEMA extensions;


-- 1. Events Table
-- Stores information about events.
CREATE TABLE IF NOT EXISTS public.events (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(), -- Use extensions schema
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    name TEXT NOT NULL CHECK (char_length(name) > 0), -- Ensure name is not empty
    description TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    location_text TEXT,
    location_coordinates GEOGRAPHY(Point, 4326), -- Optional PostGIS field for geo-queries
    is_public BOOLEAN DEFAULT TRUE NOT NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- User who created the event

    CONSTRAINT end_time_after_start_time CHECK (end_time IS NULL OR end_time > start_time)
);
COMMENT ON TABLE public.events IS 'Stores all event details.';
COMMENT ON COLUMN public.events.id IS 'Primary key, unique identifier for the event.';
COMMENT ON COLUMN public.events.created_at IS 'Timestamp of when the event was created.';
COMMENT ON COLUMN public.events.name IS 'Public name of the event.';
COMMENT ON COLUMN public.events.description IS 'Detailed description of the event.';
COMMENT ON COLUMN public.events.start_time IS 'Date and time when the event starts.';
COMMENT ON COLUMN public.events.end_time IS 'Date and time when the event ends (optional).';
COMMENT ON COLUMN public.events.location_text IS 'User-friendly text description of the location.';
COMMENT ON COLUMN public.events.location_coordinates IS 'Geographic coordinates (latitude, longitude) of the event location.';
COMMENT ON COLUMN public.events.is_public IS 'Indicates if the event is publicly visible (TRUE) or private (FALSE).';
COMMENT ON COLUMN public.events.created_by IS 'Foreign key referencing the user who created the event.';

-- Indexes for common query patterns on events table
CREATE INDEX IF NOT EXISTS idx_events_start_time ON public.events(start_time);
CREATE INDEX IF NOT EXISTS idx_events_created_by ON public.events(created_by);
CREATE INDEX IF NOT EXISTS idx_events_is_public ON public.events(is_public);
-- GIST index for PostGIS spatial queries (only if location_coordinates is used frequently for geo-queries)
CREATE INDEX IF NOT EXISTS idx_events_location_coordinates ON public.events USING GIST (location_coordinates);


-- 2. Event Users Table (Junction Table)
-- Manages the many-to-many relationship between events and users (attendees, hosts, etc.).
CREATE TABLE IF NOT EXISTS public.event_users (
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    joined_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    role TEXT DEFAULT 'attendee' NOT NULL CHECK (role IN ('attendee', 'host', 'moderator')), -- Role of the user in the event
    PRIMARY KEY (event_id, user_id)
);
COMMENT ON TABLE public.event_users IS 'Junction table linking users to events they are part of.';
COMMENT ON COLUMN public.event_users.event_id IS 'Foreign key referencing the event.';
COMMENT ON COLUMN public.event_users.user_id IS 'Foreign key referencing the user.';
COMMENT ON COLUMN public.event_users.joined_at IS 'Timestamp of when the user joined the event.';
COMMENT ON COLUMN public.event_users.role IS 'Role of the user within the event (e.g., attendee, host).';

-- Indexes for common query patterns on event_users table
CREATE INDEX IF NOT EXISTS idx_event_users_event_id ON public.event_users(event_id);
CREATE INDEX IF NOT EXISTS idx_event_users_user_id ON public.event_users(user_id);


-- 3. Event Chats Table
-- Stores chat messages for each event.
CREATE TABLE IF NOT EXISTS public.event_chats (
    id BIGSERIAL PRIMARY KEY,
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- User who sent the message
    message TEXT NOT NULL CHECK (char_length(message) > 0), -- Ensure message is not empty
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
COMMENT ON TABLE public.event_chats IS 'Stores chat messages associated with events.';
COMMENT ON COLUMN public.event_chats.id IS 'Primary key, unique identifier for the chat message.';
COMMENT ON COLUMN public.event_chats.event_id IS 'Foreign key referencing the event this chat belongs to.';
COMMENT ON COLUMN public.event_chats.user_id IS 'Foreign key referencing the user who sent the message.';
COMMENT ON COLUMN public.event_chats.message IS 'Content of the chat message.';
COMMENT ON COLUMN public.event_chats.created_at IS 'Timestamp of when the message was sent.';

-- Indexes for common query patterns on event_chats table
CREATE INDEX IF NOT EXISTS idx_event_chats_event_id_created_at ON public.event_chats(event_id, created_at DESC);


-- 4. Event Forum Threads Table
-- Stores discussion threads for each event.
CREATE TABLE IF NOT EXISTS public.event_forum_threads (
    id BIGSERIAL PRIMARY KEY,
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- User who created the thread
    title TEXT NOT NULL CHECK (char_length(title) > 0), -- Ensure title is not empty
    content TEXT, -- Optional: if the first post is part of the thread itself
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL -- To track last reply or edit
);
COMMENT ON TABLE public.event_forum_threads IS 'Stores forum threads for events.';
COMMENT ON COLUMN public.event_forum_threads.id IS 'Primary key, unique identifier for the forum thread.';
COMMENT ON COLUMN public.event_forum_threads.event_id IS 'Foreign key referencing the event this thread belongs to.';
COMMENT ON COLUMN public.event_forum_threads.user_id IS 'Foreign key referencing the user who created the thread.';
COMMENT ON COLUMN public.event_forum_threads.title IS 'Title of the forum thread.';
COMMENT ON COLUMN public.event_forum_threads.content IS 'Optional main content of the thread starter post.';
COMMENT ON COLUMN public.event_forum_threads.created_at IS 'Timestamp of when the thread was created.';
COMMENT ON COLUMN public.event_forum_threads.updated_at IS 'Timestamp of the last activity (creation, reply, edit) in the thread.';

-- Indexes for common query patterns on event_forum_threads table
CREATE INDEX IF NOT EXISTS idx_event_forum_threads_event_id_updated_at ON public.event_forum_threads(event_id, updated_at DESC);


-- 5. Event Forum Replies Table
-- Stores replies to forum threads.
CREATE TABLE IF NOT EXISTS public.event_forum_replies (
    id BIGSERIAL PRIMARY KEY,
    thread_id BIGINT REFERENCES public.event_forum_threads(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- User who posted the reply
    message TEXT NOT NULL CHECK (char_length(message) > 0), -- Ensure message is not empty
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    parent_reply_id BIGINT REFERENCES public.event_forum_replies(id) ON DELETE SET NULL -- For nested replies (optional)
);
COMMENT ON TABLE public.event_forum_replies IS 'Stores replies to forum threads.';
COMMENT ON COLUMN public.event_forum_replies.id IS 'Primary key, unique identifier for the forum reply.';
COMMENT ON COLUMN public.event_forum_replies.thread_id IS 'Foreign key referencing the forum thread this reply belongs to.';
COMMENT ON COLUMN public.event_forum_replies.user_id IS 'Foreign key referencing the user who posted the reply.';
COMMENT ON COLUMN public.event_forum_replies.message IS 'Content of the forum reply.';
COMMENT ON COLUMN public.event_forum_replies.created_at IS 'Timestamp of when the reply was posted.';
COMMENT ON COLUMN public.event_forum_replies.parent_reply_id IS 'Optional foreign key for creating nested/threaded replies.';

-- Indexes for common query patterns on event_forum_replies table
CREATE INDEX IF NOT EXISTS idx_event_forum_replies_thread_id_created_at ON public.event_forum_replies(thread_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_event_forum_replies_parent_reply_id ON public.event_forum_replies(parent_reply_id);


-- Function to update 'updated_at' timestamp on the parent event_forum_threads table
-- when a new reply is inserted into event_forum_replies.
CREATE OR REPLACE FUNCTION public.update_thread_updated_at_on_new_reply()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.event_forum_threads
    SET updated_at = NOW()
    WHERE id = NEW.thread_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; -- SECURITY DEFINER to ensure it can update the table.

-- Trigger to execute the function after a new reply is inserted.
CREATE TRIGGER trigger_update_thread_timestamp_on_reply
AFTER INSERT ON public.event_forum_replies
FOR EACH ROW
EXECUTE FUNCTION public.update_thread_updated_at_on_new_reply();
COMMENT ON TRIGGER trigger_update_thread_timestamp_on_reply ON public.event_forum_replies IS 'Updates the parent thread''s updated_at timestamp upon a new reply.';

-- Function to update 'updated_at' timestamp on event_forum_threads when its own content/title is edited.
CREATE OR REPLACE FUNCTION public.update_thread_updated_at_on_thread_edit()
RETURNS TRIGGER AS $$
BEGIN
    -- Only update if title or content actually changed, to avoid unnecessary updates/trigger loops.
    IF OLD.title IS DISTINCT FROM NEW.title OR OLD.content IS DISTINCT FROM NEW.content THEN
        NEW.updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to execute the function before an update on event_forum_threads.
CREATE TRIGGER trigger_update_thread_timestamp_on_thread_edit
BEFORE UPDATE ON public.event_forum_threads
FOR EACH ROW
EXECUTE FUNCTION public.update_thread_updated_at_on_thread_edit();
COMMENT ON TRIGGER trigger_update_thread_timestamp_on_thread_edit ON public.event_forum_threads IS 'Updates the thread''s updated_at timestamp if its title or content is modified.';

-- Ensure all tables are in the 'public' schema explicitly for clarity.
-- Supabase default is public, but being explicit is good practice.
-- All auth.users references are to Supabase's built-in authentication users table.```
File schema.sql overwritten successfully.
```
**Review of `schema.sql`:**

*   **Clarity & Readability:**
    *   Added comments to explain the purpose of each table and important columns.
    *   Added comments for triggers and functions.
    *   Specified `public` schema for all tables and functions for clarity, and `extensions` for extensions like `uuid-ossp`.
    *   Added `NOT NULL` to `created_at` and default values where sensible (e.g., `is_public`, `role`).
*   **Consistency:** Ensured consistent use of `UUID` vs `BIGSERIAL` for IDs.
*   **Correctness:**
    *   Added `NOT NULL` to foreign key columns where appropriate (e.g., `event_id` in `event_users`).
    *   Added `CHECK` constraints for non-empty text fields (name, title, message) and for `event_users.role`.
    *   Added `CHECK (end_time IS NULL OR end_time > start_time)` for the `events` table.
    *   The `updated_at` trigger for `event_forum_threads` was refined to only update `updated_at` if `title` or `content` actually change, preventing unnecessary writes if other columns are updated.
    *   The `update_thread_updated_at_on_new_reply` function is correctly defined.
*   **Indexing:**
    *   Added an index on `events.is_public`.
    *   Reviewed existing indexes; they seem appropriate for common query patterns (e.g., ordering by `created_at` or `updated_at`, filtering by `event_id`).
    *   Changed chat index to `(event_id, created_at DESC)` as chats are usually fetched in reverse chronological order for display, then reversed on client, or queried with limit for latest. Or `ASC` if infinite scrolling from bottom. Kept `ASC` for replies as per previous version, assuming typical forum reading order. Changed chat index to `DESC` as it's more common for initial "latest messages" query.
    *   Added an index on `event_forum_replies.parent_reply_id` as this would be queried if displaying nested replies.

The schema looks more robust and well-documented now.

Next, I'll review and refine `rls_policies.sql`.
