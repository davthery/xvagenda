import 'package:gsheets/gsheets.dart';
import '../config/google_sheets_config.dart';
import '../models/rugby_event.dart';
import '../utils/logger.dart';
import 'database_service.dart';

class GoogleSheetsService {
  final _logger = AppLogger();
  final _dbService = DatabaseService();

  GSheets? _gsheets;
  Spreadsheet? _spreadsheet;
  Worksheet? _worksheet;

  // Initialise la connexion à Google Sheets
  Future<void> init() async {
    try {
      _gsheets = GSheets(GoogleSheetsConfig.credentials);
      _spreadsheet =
          await _gsheets!.spreadsheet(GoogleSheetsConfig.spreadsheetId);
      _worksheet =
          _spreadsheet!.worksheetByTitle(GoogleSheetsConfig.worksheetTitle);

      if (_worksheet == null) {
        throw Exception(
            'Feuille "${GoogleSheetsConfig.worksheetTitle}" introuvable');
      }
    } catch (e) {
      _logger.error('Erreur lors de l\'initialisation de Google Sheets',
          error: e);
      rethrow;
    }
  }

  // Récupère tous les événements depuis Google Sheets
  Future<List<RugbyEvent>> fetchEvents() async {
    try {
      if (_worksheet == null) {
        await init();
      }

      _logger.info('🔄 Récupération des événements depuis Google Sheets...');

      // Récupère toutes les lignes (en sautant l'en-tête)
      final allRows = await _worksheet!.values.allRows(fromRow: 2);

      _logger.info('📊 Nombre de lignes récupérées: ${allRows.length}');

      // Convertit chaque ligne en objet RugbyEvent
      final events = <RugbyEvent>[];
      for (int i = 0; i < allRows.length; i++) {
        final row = allRows[i];
        if (row.isEmpty ||
            (row.length > 1 && row[1].toString().trim().isEmpty)) {
          _logger.debug('⏭️ Ligne ${i + 2} ignorée (vide)');
          continue;
        }

        try {
          final event = RugbyEvent.fromSheetRow(row);
          events.add(event);
        } catch (e) {
          _logger.error('❌ Erreur lors du parsing de la ligne ${i + 2}',
              error: e);
        }
      }

      _logger.success('✅ ${events.length} événements valides récupérés');

      // Sauvegarde les événements en base de données
      if (events.isNotEmpty) {
        await _dbService.insertEvents(events);
      }

      return events;
    } catch (e) {
      _logger.error('❌ Erreur lors de la récupération des événements',
          error: e);
      return [];
    }
  }

  // Récupère les événements dans une plage de dates
  Future<List<RugbyEvent>> fetchEventsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final allEvents = await fetchEvents();

    return allEvents.where((event) {
      return event.startTime
              .isAfter(startDate.subtract(const Duration(days: 1))) &&
          event.startTime.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  // Récupère les événements d'un mois spécifique
  Future<List<RugbyEvent>> fetchEventsForMonth(DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);

    return fetchEventsByDateRange(startDate, endDate);
  }
}
