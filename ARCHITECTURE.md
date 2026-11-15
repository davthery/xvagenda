# Architecture — XV Agenda

> État au 15/11/2026, branche `googleAgenda` (migration Google Sheets → Google Calendar en cours).

## 1. Vue d'ensemble

XV Agenda est une application Flutter (Android, iOS, macOS, Linux, Windows) qui affiche le planning du club de rugby du **XV de l'Erdre** dans un calendrier (vues mois / semaine / jour).

- **Source de vérité** : un Google Agenda partagé (nouveau) ou une Google Sheet (historique), lus via un **compte de service** Google.
- **Cache local** : SQLite, utilisé quand le réseau est indisponible (mode « Hors ligne »).
- **Lecture seule** : l'app ne crée ni ne modifie d'événements. Seul l'outil `tool/migrate_sheet_to_calendar.dart` écrit dans l'agenda.

Il n'y a ni gestionnaire d'état (Provider, Bloc, Riverpod…), ni injection de dépendances, ni routeur : l'architecture est volontairement simple, en **couches** (UI → services → modèle), avec un `StatefulWidget` qui orchestre tout.

```
┌──────────────────────────────────────────────────────────────┐
│ UI (lib/screens)                                             │
│   HomeScreen ──push──▶ LogViewerScreen                       │
│      │  (setState, EventController de calendar_view)         │
└──────┼───────────────────────────────────────────────────────┘
       │ choisit la source via GoogleSheetsConfig.useCalendar
┌──────▼───────────────────────────────────────────────────────┐
│ Services (lib/services)                                      │
│   CalendarService ─┐                   GoogleSheetsService ─┐│
│   (googleapis)     │                   (gsheets)            ││
│                    └──────▶ DatabaseService (singleton) ◀───┘│
│                             SQLite: table rugby_events       │
└──────┬───────────────────────────────────────────────────────┘
       │ produisent / consomment
┌──────▼───────────────┐   ┌─────────────────┐  ┌──────────────┐
│ Modèle               │   │ Config          │  │ Utils        │
│ RugbyEvent           │   │ *_config.dart   │  │ AppLogger    │
│  fromCalendarEvent() │   │ (git-ignorés)   │  │ (singleton)  │
│  fromSheetRow()      │   └─────────────────┘  └──────────────┘
│  toMap()/fromMap()   │
└──────────────────────┘
```

## 2. Arborescence

```
lib/
├── main.dart                         # Bootstrap : sqflite FFI (desktop), logger, SharedPreferences, MaterialApp
├── config/
│   ├── google_calendar_config.dart          # ⚠️ git-ignoré : credentials, calendarId, categoryKey
│   ├── google_calendar_config_template.dart # modèle versionné
│   ├── google_sheets_config.dart            # ⚠️ git-ignoré : credentials, spreadsheetId, worksheetTitle, useCalendar
│   └── google_sheets_config_template.dart   # modèle versionné (sans useCalendar)
├── models/
│   └── rugby_event.dart              # Modèle unique + mappings (Sheets, Calendar, SQLite)
├── services/
│   ├── calendar_service.dart         # Lecture Google Calendar API v3 + mise en cache
│   ├── google_sheets_service.dart    # Lecture Google Sheets (historique) + mise en cache
│   └── database_service.dart         # Accès SQLite (singleton)
├── screens/
│   ├── home_screen.dart              # Écran principal : chargement, calendrier, détails
│   └── log_viewer_screen.dart        # Affichage / copie des logs du jour
└── utils/
    └── logger.dart                   # Logger console + fichier (rotation 7 jours)

tool/migrate_sheet_to_calendar.dart   # CLI de migration Sheet → Calendar (idempotente)
test/google_calendar_service_test.dart# Tests d'intégration (vrais appels réseau)
test/widget_test.dart, test/xvagenda/ # Tests widget par défaut
production/                           # ⚠️ git-ignoré : ancienne copie de lib/ (contient une vraie clé)
```

## 3. Démarrage (`main.dart`)

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. Sur macOS / Linux / Windows : `sqfliteFfiInit()` et `databaseFactory = databaseFactoryFfi` (Android/iOS utilisent sqflite natif ; le web n'est pas géré).
3. `AppLogger().init()` : crée `<Documents>/logs/xvagenda_YYYY-MM-DD.log` et purge les logs de plus de 7 jours.
4. `SharedPreferences` : flag `has_launched` (première exécution, utilisé seulement pour un log).
5. `runApp(XVAgendaApp)` : `CalendarControllerProvider` + `MaterialApp` (Material 3, couleur de base verte) → `HomeScreen`.

> Note : le `EventController` fourni par `CalendarControllerProvider` n'est pas utilisé ; `HomeScreen` crée et passe le sien explicitement aux vues.

## 4. Flux de données

### 4.1 Chargement des événements (`HomeScreen._loadEvents`)

```
initState / bouton Rafraîchir / Réessayer
        │
        ▼
GoogleSheetsConfig.useCalendar ?
   ├─ true  → CalendarService.init() + fetchEvents()
   └─ false → GoogleSheetsService.init() + fetchEvents()
        │
        ├─ succès : le service mappe en RugbyEvent, puis DatabaseService.insertEvents() (upsert)
        │
        └─ exception : DatabaseService.getAllEvents()
                       ├─ non vide → _isOffline = true (badge « Hors ligne »)
                       └─ vide     → message d'erreur + bouton « Réessayer »
        │
        ▼
Chaque RugbyEvent → CalendarEventData (titre "HH:mm - titre", couleur par catégorie,
                    objet RugbyEvent complet dans `event`) → EventController
```

**Point d'attention.** Les méthodes `fetchEvents()` des deux services **attrapent leurs erreurs et renvoient `[]`** au lieu de les propager. Seul `init()` relance l'exception. Résultat : une coupure réseau pendant `fetchEvents()` (après un `init()` réussi) donne un calendrier vide au lieu du cache hors ligne. Avec `CalendarService`, `clientViaServiceAccount` dans `init()` échoue généralement sans réseau, donc le repli fonctionne dans la plupart des cas, mais pas tous.

### 4.2 Sources de données

| | `CalendarService` (cible) | `GoogleSheetsService` (historique) |
|---|---|---|
| Librairie | `googleapis` (Calendar v3) + `googleapis_auth` | `gsheets` |
| Auth | Compte de service, scope `calendarScope` | Compte de service |
| Lecture | `events.list(calendarId, singleEvents: true, maxResults: 2500)`, une seule page | Toutes les lignes à partir de la ligne 2 de la feuille `Planning` |
| Mapping | `RugbyEvent.fromCalendarEvent` | `RugbyEvent.fromSheetRow` |
| Catégorie | `extendedProperties.private['categorie']` | colonne 7 |
| Filtre par dates | Côté serveur (`timeMin`/`timeMax`) | En mémoire, après lecture complète |
| Mise en cache | Oui, dans `fetchEvents()` seulement | Oui, dans `fetchEvents()` |

Les deux services exposent la même interface informelle : `init()`, `fetchEvents()`, `fetchEventsByDateRange()`, `fetchEventsForMonth()`. Aucune classe abstraite ne la formalise. `HomeScreen` instancie les deux services et choisit avec un `if`.

### 4.3 Persistance (`DatabaseService`)

- Singleton (`factory` + `_internal`), base `xvagenda.db` (version 1) dans `getDatabasesPath()`.
- Table unique :

```sql
CREATE TABLE rugby_events (
  id TEXT PRIMARY KEY,          -- id Calendar ou UID de la feuille
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  startTime TEXT NOT NULL,      -- ISO 8601 (heure locale)
  endTime TEXT NOT NULL,
  location TEXT,
  category TEXT,
  createdAt TEXT NOT NULL
);
```

- Écriture : `insertEvents()` en batch avec `ConflictAlgorithm.replace` (upsert). **Aucune suppression** : un événement supprimé côté source reste dans le cache indéfiniment. Passer de Sheets à Calendar mélange aussi deux espaces d'identifiants dans la même table, ce qui peut créer des doublons visibles en mode hors ligne.
- `_upgradeDatabase` est vide : aucune migration de schéma n'est prévue.

### 4.4 Modèle (`RugbyEvent`)

Classe immuable : `id`, `title`, `description`, `startTime`, `endTime`, `location?`, `category?`.

- `fromCalendarEvent` : `dateTime` est converti en heure locale. Les événements « journée entière » (`date`) sont placés à 09:00. Une date absente donne `DateTime.now()`.
- `fromSheetRow` : `_parseDateTime` accepte l'ISO 8601, `YYYY-MM-DD HH:mm:ss`, `dd/MM/yyyy HH:mm[:ss]` (heuristique jour/mois, français par défaut) et le numéro de série Excel. Une date non reconnue donne `DateTime.now()` avec un warning.
- `toMap` / `fromMap` : sérialisation SQLite.

Le modèle importe `GoogleCalendarConfig` et `googleapis`, donc il dépend de la couche infrastructure. Dans une architecture plus stricte, ces mappings iraient dans les services ou dans des « mappers ».

## 5. Interface utilisateur

### `HomeScreen` (≈670 lignes, un seul `State`)

Il cumule plusieurs responsabilités :

- **Orchestration des données** (§4.1) : états `_isLoading`, `_errorMessage`, `_isOffline`.
- **Navigation calendrier** : `_currentView` (enum `CalendarViewType` mois/semaine/jour, choisi par un `SegmentedButton`), `_currentDate`, boutons précédent/suivant/aujourd'hui. Le pilotage passe par des `GlobalKey<MonthViewState|WeekViewState|DayViewState>` et `jumpTo…()`.
- **Rendu** : `MonthView` / `WeekView` / `DayView` du package `calendar_view`, plage limitée à **2025 → 2027** (codée en dur).
- **Détails** : `AlertDialog` pour un événement, `BottomSheet` pour la liste des événements d'un jour.
- **Présentation** : couleur par catégorie (`_getEventColor`) et formatage des dates en français, écrit à la main (la locale `intl` n'est pas utilisée).

Bugs mineurs repérés :
- Dans `_getEventColor`, `case 'Séniors'` et `case 'R5'` ne peuvent jamais correspondre, puisque la valeur testée passe d'abord par `toLowerCase()`.
- `_showDayEvents` utilise `Expanded` dans une `Column` en `mainAxisSize.min` à l'intérieur d'un bottom sheet, ce qui risque une erreur de layout.
- Le titre d'origine est retrouvé avec `split(' - ')[1]`, ce qui tronque les titres qui contiennent eux-mêmes « - ».

### `LogViewerScreen`

Lit `AppLogger.getLogContent()` (fichier du jour) et permet de le copier dans le presse-papiers.

## 6. Transverse

### Logging (`AppLogger`)
Singleton, niveaux `info / debug / warning / error / success`, messages préfixés par des emojis. Chaque message part sur la console (`print`) **et** dans le fichier du jour. Tous les niveaux, `debug` compris, sont écrits partout, sans filtrage en release. L'écriture est asynchrone et non attendue (« fire-and-forget »).

### Configuration et secrets
- Les fichiers `*_config.dart` réels sont **git-ignorés**. Les `*_template.dart` sont versionnés.
- Les credentials du compte de service sont **compilés dans le binaire** (constante Dart). Toute personne qui récupère l'APK/IPA peut donc extraire la clé privée. C'est acceptable pour un usage interne au club, mais le compte de service doit garder des droits minimaux. Le scope actuel `calendarScope` donne **lecture et écriture** ; `calendarReadonlyScope` suffirait pour l'app.
- Le flag `useCalendar` se trouve dans `GoogleSheetsConfig` et **n'existe pas dans le template** : un nouveau développeur qui part du template aura une erreur de compilation.

## 7. Outillage

### `tool/migrate_sheet_to_calendar.dart`
CLI Dart (`dart run tool/migrate_sheet_to_calendar.dart [--dry-run] [--filter X] [--resume]`). Il lit la feuille avec `GoogleSheetsService` et crée ou met à jour les événements dans l'agenda.
- **Idempotent** : chaque événement créé porte `extendedProperties.private.idSource` = UID de la ligne.
- Ignore les événements terminés depuis plus de 90 jours et ne migre pas les récurrences.

### Tests
- `test/google_calendar_service_test.dart` : tests d'**intégration** qui font de vrais appels au calendrier configuré (accessibilité, mapping, `fetchEvents` + cache). Ils exigent la config réelle et le réseau, donc ils ne conviennent pas à une CI sans secrets.
- Il n'y a pas de tests unitaires sur `_parseDateTime`, `fromCalendarEvent` ou `DatabaseService`. Ce sont pourtant les zones les plus faciles à tester et les plus sujettes aux régressions.

## 8. Dépendances principales

| Package | Rôle |
|---|---|
| `calendar_view` | Vues mois / semaine / jour |
| `googleapis`, `googleapis_auth` | Google Calendar API + auth compte de service |
| `gsheets` | Google Sheets (source historique) |
| `sqflite`, `sqflite_common_ffi` | Cache SQLite mobile / desktop |
| `shared_preferences` | Flag de premier lancement |
| `path_provider`, `path` | Dossiers documents et base |
| `intl` | Formatage des horodatages de logs |

## 9. Pistes d'évolution

1. **Abstraire la source** : une interface `EventSource { Future<List<RugbyEvent>> fetchEvents(); }` implémentée par les deux services, puis un `EventRepository` qui gère réseau → cache → repli. `HomeScreen` ne dépendrait plus que du repository.
2. **Propager les erreurs réseau** depuis `fetchEvents()` (ou renvoyer un résultat typé), pour que le repli hors ligne fonctionne toujours.
3. **Synchroniser le cache** : remplacer la table dans une transaction (`delete` + `insert`) au lieu d'un simple upsert, pour éliminer les événements supprimés et les anciens IDs Sheets.
4. **Découper `HomeScreen`** : widgets séparés pour la barre de vues, la barre de navigation et les dialogues, plus un état extrait (`ChangeNotifier` ou autre).
5. **Retirer Sheets** de l'app une fois la migration terminée (package `gsheets`, service, `fromSheetRow`, flag `useCalendar`) et ne le garder que pour l'outil.
6. **Sécurité** : passer au scope `calendarReadonlyScope` dans l'app et documenter `useCalendar` dans le template.
7. **Tests unitaires** sur le modèle (parsing et mapping Calendar) avec des `gcal.Event` construits à la main.
