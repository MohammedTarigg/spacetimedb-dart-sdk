# SpacetimeDB Flutter Example

A Flutter app demonstrating the SpacetimeDB Dart SDK with two tabs: Notes (CRUD + status management) and Chat (real-time messaging with presence).

**Features shown:** WebSocket connection, real-time table sync, reducer calls, sealed class pattern matching (NoteStatus), connection status UI, server timestamps, online presence, multi-client chat.

## Prerequisites

- Flutter SDK (3.27+)
- SpacetimeDB CLI — [install](https://spacetimedb.com/install)
- Rust toolchain (to build the server module)

## Setup

### 1. Start SpacetimeDB

```bash
# Option A: Native
spacetime start

# Option B: Docker
docker run --rm -p 3000:3000 clockworklabs/spacetime start
```

### 2. Build and publish the server module

```bash
cd spacetime_test_module   # from the SDK root
spacetime build
spacetime publish notesdb -s http://localhost:3000
```

### 3. Generate client code

```bash
cd example/flutter_notes
dart run spacetimedb_dart_sdk:generate -s http://localhost:3000 -d notesdb -o lib/generated
```

### 4. Run the app

```bash
flutter run              # default device
flutter run -d chrome    # web
flutter run -d macos     # macOS desktop
```

To test real-time sync, open the app on two devices or browsers pointed at the same SpacetimeDB instance. Messages and note changes sync instantly across all connected clients.

## Architecture

```
lib/
  main.dart                  — App entry, bottom navigation (Notes / Chat)
  spacetimedb_service.dart   — ChangeNotifier wrapping SpacetimeDbClient
  screens/
    notes_list_screen.dart   — Note list with status filter chips
    note_edit_screen.dart    — Create / edit form with status management
    chat_screen.dart         — Real-time chat with online presence
  widgets/
    note_card.dart           — Card with status chip, timestamps, swipe-to-delete
    connection_status_indicator.dart — Live connection dot in AppBar
```

No external state management. The SDK's table change streams drive UI rebuilds via `ChangeNotifier` + `ListenableBuilder`.

## Server Module Schema

Defined in `spacetime_test_module/src/lib.rs`:

| Table | Fields |
|-------|--------|
| `Note` | `id: u32` (PK), `title`, `content`, `timestamp`, `status: NoteStatus` |
| `User` | `identity: Identity` (PK), `name: Option<String>`, `online: bool` |
| `Message` | `sender: Identity`, `sent: u64`, `text: String` |

| Reducer | Description |
|---------|-------------|
| `create_note(title, content)` | Creates a note with Draft status |
| `update_note(note_id, title, content)` | Updates title and content |
| `set_note_status(note_id, status)` | Transitions status (Draft/Published/Archived) |
| `delete_note(note_id)` | Deletes by ID |
| `send_message(text)` | Sends a chat message |
| `set_name(name)` | Sets display name for current user |
| `client_connected` | Auto: creates/updates User on connect |
| `client_disconnected` | Auto: marks User offline on disconnect |
