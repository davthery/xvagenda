# XV Agenda - AI Agent Instructions

## Project Overview
XV Agenda is a Flutter mobile app displaying rugby club events from a Google Sheets source with local SQLite caching. The architecture prioritizes offline-first resilience and logging for debugging.

**Key domains:** Flutter, Google Sheets integration, SQLite persistence, calendar UI, multi-platform support (Android, iOS, macOS, Linux, Windows).

## Architecture & Data Flow

### Persistence Two-Tier Strategy
```
User Input/External → Google Sheets → GoogleSheetsService (fetch + parse)
                                          ↓
                                    DatabaseService (cache to SQLite)
                                          ↓
                                    HomeScreen (display events)
                          ↑
                    Network unavailable?
                    Load from SQLite cache
```

**Key insight:** App always tries Google Sheets first. On network failure, silently loads from SQLite and displays "Hors ligne" indicator in AppBar.

### Service Architecture
- **`DatabaseService`** (Singleton): Manages all SQLite operations via [database_service.dart](lib/services/database_service.dart)
  - Uses singleton pattern: `static final DatabaseService _instance = DatabaseService._internal()`
  - Auto-creates schema on first run via `onCreate` callback
  - Methods: `insertEvent()`, `insertEvents()`, `getAllEvents()`, `getEventsByDateRange()`, `deleteAllEvents()`
  - Serialization via `RugbyEvent.toMap()` / `RugbyEvent.fromMap()`

- **`GoogleSheetsService`**: Fetches from Google Sheets and triggers DB save via [google_sheets_service.dart](lib/services/google_sheets_service.dart)
  - Calls `_dbService.insertEvents()` after successful fetch
  - Handles Google Sheets credential setup (currently hardcoded—requires secure configuration)
  - Parses flexible date formats (ISO 8601, DD/MM/YYYY HH:mm)

- **`RugbyEvent`** Model: Central data class at [models/rugby_event.dart](lib/models/rugby_event.dart)
  - Properties: `id`, `title`, `description`, `startTime`, `endTime`, `location`, `category`
  - Factory constructors: `fromMap()` (DB), `fromSheetRow()` (Google Sheets with logging)
  - Static `_parseDateTime()` handles multiple date formats with fallback to `DateTime.now()`

### Platform-Specific Database Initialization
See [main.dart](lib/main.dart):
```dart
if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
  sqlfiteFfiInit();  // Native platforms use sqflite_common_ffi
  databaseFactory = databaseFactoryFfi;
}
```
- **Android/iOS:** Native sqflite driver
- **macOS/Linux/Windows:** `sqflite_common_ffi` wrapper
- **Web:** Not supported (would use SharedPreferences for localStorage)

## Critical Patterns & Conventions

### Logging & Debugging
[utils/logger.dart](lib/utils/logger.dart) provides centralized logging with emoji-prefixed messages:
- `logger.info('🔄 message')` → Console + file
- `logger.success('✅ message')`
- `logger.warning('⚠️ message')`
- `logger.error('❌ message', error: e)`
- `logger.debug('🔍 message')` → File only

Logs stored locally for 7 days; accessible via LogViewerScreen. **Always use AppLogger for tracing data flows.**

### Event Parsing from Google Sheets
[models/rugby_event.dart](lib/models/rugby_event.dart) accepts variable column counts:
```dart
// Flexible: only columns 1-4 required (id, title, description, startTime)
RugbyEvent.fromSheetRow([
  '1', 
  'Match', 
  'XV vs Nantes', 
  '2025-12-01T14:00:00',  // ISO 8601 OR dd/MM/yyyy HH:mm
  '2025-12-01T16:00:00',
  'Stade',        // Optional location
  'Match'         // Optional category
])
```
- Logs each parsed column with type info for debugging
- Empty location/category → `null` (not empty strings)
- Invalid dates → defaults to `DateTime.now()` with warning log

### Material 3 Theme (ColorScheme from Seed)
[main.dart](lib/main.dart): Uses `ColorScheme.fromSeed(seedColor: Colors.green)` for dynamic theming.

### Calendar Display
[screens/home_screen.dart](lib/screens/home_screen.dart) uses `calendar_view` package:
- EventController initialized in MaterialApp via `CalendarControllerProvider`
- Events added to controller on load: `eventController.add(event)`
- Monthly view with category-based styling

## Build & Deployment Commands
```bash
flutter pub get              # Install dependencies
flutter run                  # Debug on default device
flutter run -d ios           # macOS only: iOS simulator
flutter build apk            # Production Android APK
flutter build ios            # iOS app (requires Xcode)
flutter clean                # Remove build artifacts
```

## Key Dependencies
- **`gsheets: ^0.5.0`** – Service account auth to Google Sheets API
- **`calendar_view: ^1.0.4`** – Month/week/day calendar UI
- **`sqflite: ^2.3.0`** + **`sqflite_common_ffi: ^2.3.0`** – SQLite with FFI support
- **`shared_preferences: ^2.2.2`** – Simple K/V store (e.g., first-run flag)
- **`path_provider: ^2.1.1`** – Platform-aware file/DB paths
- **`intl: ^0.20.2`** – Date/time formatting and i18n

## Configuration Requirements
1. **Google Sheets API credentials** (hardcoded in `GoogleSheetsService`—security risk in production):
   - Service account JSON with `private_key` and `client_email`
   - Spreadsheet ID (from URL)
   - Worksheet title (default: "Planning")

2. **SQLite initialization** must complete before first DB query (done in `main()` async block)

3. **Android min SDK:** 21 (set in pubspec.yaml `flutter_launcher_icons`)

## Common Workflows

### Adding a New Event Field
1. Add field to `RugbyEvent` constructor and class properties
2. Update `toMap()` and `fromMap()` serialization
3. Update `fromSheetRow()` factory if sourcing from Google Sheets
4. Update database schema in `DatabaseService._createDatabase()` (bump `_dbVersion`)
5. Handle migration in `_upgradeDatabase()` if not first run

### Debugging Network Issues
1. Check logs in LogViewerScreen or terminal output
2. `GoogleSheetsService._worksheet == null` indicates init failed
3. Inspect date parsing: `_parseDateTime()` logs each format attempt
4. Verify Google Sheets credentials and API enablement

### Offline Mode Testing
Disconnect network → `_loadEvents()` in HomeScreen catches exception → loads from SQLite → displays "Hors ligne" badge.

## Testing Considerations
- No test suite currently implemented
- Suggested: Unit tests for `_parseDateTime()`, `RugbyEvent.fromMap()`, `DatabaseService` CRUD operations
- Integration tests for Google Sheets fetch → DB save → display flow

## Notes for AI Agents
- **Logging is your friend:** Every major operation logs its state. Always check logs before assuming behavior.
- **Singleton DatabaseService:** Only one instance per app lifecycle. Safe to call `DatabaseService()` anywhere.
- **DateTime handling is complex:** Multiple input formats (ISO 8601, French dd/MM/yyyy). Test thoroughly if adding new parsing.
- **Credentials hardcoded:** Production deployment must move to environment variables or secure vaults.
- **No error dialogs:** Failures silently fallback (network → cache). Consider adding user-facing error notifications.
