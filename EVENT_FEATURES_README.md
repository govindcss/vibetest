# Event-Based Communities Feature

This document outlines the Event-Based Communities feature developed for a Flutter application using Supabase as the backend. The feature allows users to create, discover, and interact with events, including chat and forum functionalities within each event.

## Feature Overview

Users can:
-   View a list of upcoming events (public or those they are part of).
-   View detailed information about a specific event.
-   Join and leave public events.
-   (If event host) Manage event privacy (public/private).
-   Participate in a real-time chat within an event.
-   Engage in forum discussions within an event:
    -   View a list of forum threads.
    -   Create new forum threads.
    -   View a specific thread and its replies.
    -   Post replies to threads.

## Flutter Components

The Flutter application code is structured into models, repositories, providers (using Riverpod for state management), and UI elements (screens and widgets).

### Key Directories:
-   `lib/models/`: Contains data model classes mirroring Supabase tables.
    -   `event.dart`: Represents an event.
    -   `event_user.dart`: Represents a user's membership/role in an event.
    -   `chat_message.dart`: Represents a message in an event's chat.
    -   `forum_thread.dart`: Represents a thread in an event's forum.
    -   `forum_reply.dart`: Represents a reply within a forum thread.
-   `lib/repositories/`: Contains classes responsible for data fetching and manipulation from Supabase.
    -   `event_repository.dart`: Handles all CRUD operations and streaming for events, chat, and forum.
-   `lib/providers/`: Contains Riverpod providers for state management.
    -   `event_providers.dart`: Manages the state for the list of events (`EventListNotifier`).
    -   `event_details_provider.dart`: Manages state for a single event's details and attendees (`EventDetailsNotifier`).
    -   `event_chat_provider.dart`: Provides a real-time stream of chat messages for an event.
    -   `forum_providers.dart`: Manages state for forum threads list (`ForumThreadsNotifier`) and thread details with replies (`ForumThreadDetailsNotifier`).
-   `lib/ui/`: Contains UI elements.
    -   `screens/events_list_screen.dart`: Displays the main list of events.
    -   `screens/event_details_screen.dart`: Displays details of a selected event, and embeds chat and forum views.
    -   `screens/create_forum_thread_screen.dart`: Form to create a new forum thread.
    -   `screens/forum_thread_screen.dart`: Displays a forum thread and its replies.
    -   `widgets/event_chat_view.dart`: Widget for event chat functionality.
    -   `widgets/event_forum_view.dart`: Widget for event forum thread listing.

## Supabase Backend

The Supabase backend consists of several tables and Row Level Security (RLS) policies to manage data and access control.

### Tables:
(Defined in `schema.sql`)
1.  **`events`**: Stores event details (name, description, time, location, privacy, creator).
2.  **`event_users`**: Junction table for event membership (event_id, user_id, role, joined_at).
3.  **`event_chats`**: Stores chat messages for events (event_id, user_id, message, created_at).
4.  **`event_forum_threads`**: Stores forum threads for events (event_id, user_id, title, content, created_at, updated_at).
5.  **`event_forum_replies`**: Stores replies to forum threads (thread_id, user_id, message, created_at, parent_reply_id).

### Row Level Security (RLS) Policies:
(Defined in `rls_policies.sql`)
-   **Events**:
    -   Public events are selectable by anyone.
    -   Members and creators can select private events they are associated with.
    -   Authenticated users can create events.
    -   Event creators/hosts can update or delete their events.
-   **Event Users (Membership)**:
    -   Users can view their own memberships.
    -   Members of an event can view other members of the same event.
    -   Authenticated users can join public events.
    -   Users can leave events; hosts can remove members.
-   **Event Chats**:
    -   Event members can select/read chat messages.
    -   Event members can insert new messages.
-   **Forum Threads & Replies**:
    -   Event members can select/read threads and replies.
    -   Event members can insert new threads and replies.
    -   Content creators or event hosts can update/delete threads and replies.
-   **Helper Functions**: SQL functions (`is_event_member`, `get_event_role`, `is_event_host`) are used to simplify RLS policies. These run with `SECURITY DEFINER` privileges.

### Prerequisites & Setup:

1.  **Supabase Project**: A Supabase project must be set up.
2.  **Enable Extensions**:
    *   `uuid-ossp`: Run `CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;`
    *   `postgis` (if using `GEOGRAPHY` type): Enable via Supabase Dashboard or SQL.
3.  **Apply Schema**: Execute the SQL commands in `schema.sql` to create tables, indexes, and triggers.
4.  **Apply RLS Policies**: Execute the SQL commands in `rls_policies.sql` to enable Row Level Security and define access policies.
5.  **Flutter Configuration**: Ensure the Flutter app is correctly configured with your Supabase project URL and anon key.

## Running Tests

The project includes unit and widget tests for key components.

1.  **Install Dev Dependencies**: Ensure `mockito` and `build_runner` are in your `pubspec.yaml`'s `dev_dependencies`.
2.  **Generate Mocks**: For tests involving mocks (repositories, providers), run:
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```
3.  **Run Tests**:
    ```bash
    flutter test
    ```
    This command will execute all tests in the `test/` directory.

This feature provides a robust foundation for event-based communities within the application. Further enhancements can include user profiles, notifications, event invitations, advanced moderation tools, and more detailed location-based services.
