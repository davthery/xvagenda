# XV Agenda - Application Mobile Flutter

Application mobile pour visualiser les événements du planning du club de rugby du XV de l'Erdre.

## Fonctionnalités

- 📅 Visualisation des événements dans un calendrier mensuel
- 🔄 Récupération automatique des données depuis Google Sheets
- 🎨 Différentes couleurs selon les catégories (Match, Entraînement, Réunion)
- 📱 Compatible Android et iOS
- 🔍 Affichage des détails de chaque événement
- 📝 Système de logging complet (console + fichier)
- 🐛 Visualisateur de logs intégré pour le débogage

## Structure du projet

```
lib/
├── main.dart                    # Point d'entrée de l'application
├── models/
│   └── rugby_event.dart         # Modèle de données pour les événements
├── services/
│   └── google_sheets_service.dart  # Service pour récupérer les données
├── screens/
│   ├── home_screen.dart         # Page principale avec le calendrier
│   └── log_viewer_screen.dart   # Visualisateur de logs
└── utils/
    └── logger.dart              # Système de logging centralisé
```

## Configuration

### 1. Installation des dépendances

```bash
flutter pub get
```

### 2. Configuration Google Sheets API

Pour utiliser l'application, vous devez configurer l'accès à Google Sheets :

1. Créez un projet dans [Google Cloud Console](https://console.cloud.google.com/)
2. Activez l'API Google Sheets
3. Créez un compte de service et téléchargez les credentials JSON
4. Ouvrez `lib/services/google_sheets_service.dart`
5. Remplacez les valeurs suivantes :
   - `_credentials` : Collez le contenu de votre fichier JSON de credentials
   - `_spreadsheetId` : L'ID de votre Google Sheet (dans l'URL)
   - `_worksheetTitle` : Le nom de la feuille (par défaut "Planning")

### 3. Format du Google Sheet

Votre feuille Google Sheets doit avoir les colonnes suivantes :

| ID | Titre | Description | Date début | Date fin | Lieu | Catégorie |
|----|-------|-------------|------------|----------|------|-----------|
| 1 | Match amical | Description | 01/12/2025 14:00 | 01/12/2025 16:00 | Stade | Match |
| 2 | Entraînement | Description | 03/12/2025 19:00 | 03/12/2025 21:00 | Terrain | Entraînement |

**Formats de date acceptés :**
- ISO 8601 : `2025-12-01T14:00:00`
- Format français : `01/12/2025 14:00`

## Lancement de l'application

```bash
# Pour Android
flutter run

# Pour iOS (sur macOS uniquement)
flutter run -d ios

# Pour générer un APK
flutter build apk

# Pour générer un IPA
flutter build ios

# Nettoyer les fichiers de build
flutter clean

```

## Dépendances principales

- `gsheets: ^0.5.0` - Accès à Google Sheets
- `calendar_view: ^1.0.4` - Affichage du calendrier
- `intl: ^0.18.1` - Gestion des dates et formats
- `path_provider: ^2.1.1` - Accès au système de fichiers pour les logs

## Système de logging

L'application utilise un système de logging personnalisé qui :
- ✅ Écrit dans la console pour le développement
- ✅ Enregistre dans un fichier pour le débogage
- ✅ Conserve les logs pendant 7 jours
- ✅ Permet la visualisation en temps réel via l'interface

### Accès aux logs

1. **Depuis l'application** : Appuyez sur l'icône 📄 dans la barre supérieure
2. **Fichier de log** : `Documents/logs/xvagenda_YYYY-MM-DD.log`

### Niveaux de log

- `INFO` : Informations générales
- `DEBUG` : Détails de débogage
- `SUCCESS` : Opérations réussies
- `WARNING` : Avertissements
- `ERROR` : Erreurs avec stack trace

## Personnalisation

### Couleurs des catégories

Dans `lib/screens/home_screen.dart`, méthode `_getEventColor()` :

```dart
Color _getEventColor(String? category) {
  switch (category?.toLowerCase()) {
    case 'match':
      return Colors.red;
    case 'entraînement':
      return Colors.green;
    case 'réunion':
      return Colors.orange;
    default:
      return Colors.blue;
  }
}
```

### Thème de l'application

Dans `lib/main.dart`, vous pouvez modifier le `ThemeData` :

```dart
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.green, // Changez la couleur principale ici
  ),
),
```

## Problèmes courants

### Erreur de connexion à Google Sheets
- Vérifiez que les credentials sont corrects
- Assurez-vous que le compte de service a accès au Google Sheet
- Vérifiez que l'API Google Sheets est activée dans votre projet GCP

### Dates mal formatées
- Utilisez le format `dd/MM/yyyy HH:mm` ou ISO 8601
- Vérifiez que toutes les dates sont valides dans votre feuille

## Licence

Ce projet est open source et disponible pour le club du XV de l'Erdre.
