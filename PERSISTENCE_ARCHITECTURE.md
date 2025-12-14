# Architecture de Persistance des Données

## Vue d'ensemble

L'application implémente une stratégie de persistance en deux niveaux :

1. **SQLite (Base de données locale)** - Cache persistant des événements
2. **Google Sheets** - Source de vérité des événements

## Flux de chargement des événements

### Au démarrage de l'application

```
1. HomeScreen initialise _loadEvents()
   ↓
2. Tentative de connexion à Google Sheets
   ├─ SUCCÈS → Récupère les événements depuis Google Sheets
   │           → Les sauvegarde automatiquement en base SQLite
   │           → Affiche les événements
   │
   └─ ERREUR (pas de réseau) → Charge les événements depuis SQLite
                               → Affiche les événements en mode hors ligne
                               → Affiche un indicateur "Hors ligne" dans l'AppBar
```

## Services

### `DatabaseService`
Gère toutes les opérations SQLite.

**Méthodes principales :**
- `insertEvent(RugbyEvent)` - Insère/met à jour un événement
- `insertEvents(List<RugbyEvent>)` - Insère/met à jour plusieurs événements
- `getAllEvents()` - Récupère tous les événements
- `getEventsByDateRange(startDate, endDate)` - Filtrage par plage de dates
- `deleteAllEvents()` - Vide la base de données
- `getEventCount()` - Compte le nombre d'événements

**Caractéristiques :**
- Pattern Singleton pour une instance unique
- Crée automatiquement la table `rugby_events` au premier lancement
- Sérialisation/désérialisation JSON via `RugbyEvent.toMap()` et `RugbyEvent.fromMap()`

### `GoogleSheetsService`
Modifié pour sauvegarder les événements en base de données après un fetch réussi.

### `RugbyEvent`
Enrichi avec les méthodes :
- `toMap()` - Convertit l'objet en Map pour la sauvegarde
- `fromMap()` - Crée un objet depuis une Map

## Schéma de la base de données

```sql
CREATE TABLE rugby_events (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  startTime TEXT NOT NULL,
  endTime TEXT NOT NULL,
  location TEXT,
  category TEXT,
  createdAt TEXT NOT NULL
)
```

## Exemple d'utilisation

```dart
// Charger tous les événements
final dbService = DatabaseService();
final events = await dbService.getAllEvents();

// Sauvegarder des événements
final newEvent = RugbyEvent(
  id: '1',
  title: 'Match',
  description: 'XV vs Nantes',
  startTime: DateTime.now(),
  endTime: DateTime.now().add(Duration(hours: 2)),
);
await dbService.insertEvent(newEvent);

// Récupérer les événements d'une période
final startDate = DateTime(2025, 12, 1);
final endDate = DateTime(2025, 12, 31);
final monthEvents = await dbService.getEventsByDateRange(startDate, endDate);
```

## Mode hors ligne

Quand l'application détecte une absence de réseau :
1. Elle charge les événements depuis SQLite
2. Affiche un badge "Hors ligne" dans l'AppBar
3. L'utilisateur peut toujours consulter les événements en cache
4. Le bouton "Rafraîchir" permet de réessayer la connexion

## Avantages

✅ **Expérience utilisateur améliorée** - Accès aux événements même sans réseau
✅ **Performance** - Chargement rapide depuis le cache local
✅ **Résilience** - L'app continue de fonctionner en cas de problème réseau
✅ **Synchronisation** - Les données sont mises à jour automatiquement

## Installation des dépendances

```bash
flutter pub get
```

Les dépendances ajoutées :
- `sqflite: ^2.3.0` - Base de données SQLite
- `path: ^1.8.0` (inclus automatiquement avec sqflite)

