import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:googleapis_auth/auth_io.dart';
import '../config/google_calendar_config.dart';
import '../models/rugby_event.dart';
import '../utils/logger.dart';
import 'database_service.dart';

/// Service de synchronisation avec Google Agenda (Calendar API)
///
/// Miroir de [GoogleSheetsService] : expose `init()`, `fetchEvents()`,
/// `fetchEventsByDateRange()`, `fetchEventsForMonth()` et le fallback
/// hors ligne via la base de données locale.
class CalendarService {
  final _logger = AppLogger();
  final _dbService = DatabaseService();

  late final ServiceAccountCredentials _credentials;
  late final gcal.CalendarApi _calendar;
  DatabaseService? _db;

  // Initialise la connexion à Google Agenda
  Future<void> init() async {
    try {
      _credentials = ServiceAccountCredentials.fromJson(
        GoogleCalendarConfig.credentials,
      );
      final client = await clientViaServiceAccount(
        _credentials,
        const [gcal.CalendarApi.calendarScope],
      );
      _calendar = gcal.CalendarApi(client);
      _db = _dbService;

      _logger.info('🔌 Service Google Agenda initialisé (calendrier: ${GoogleCalendarConfig.calendarId})');
    } catch (e) {
      _logger.error('Erreur lors de l\'initialisation de Google Agenda',
          error: e);
      rethrow;
    }

  }

  /// Expose l'API Calendar initialisée (utile pour des outils, ex. migration).
  gcal.CalendarApi get calendarApi => _calendar;

  // Récupère tous les événements depuis Google Agenda
  Future<List<RugbyEvent>> fetchEvents() async {
    try {
      if (_db == null) {
        await init();
      }

      _logger.info('🔄 Récupération des événements depuis Google Agenda...');

      final page = await _calendar.events.list(
        GoogleCalendarConfig.calendarId,
        maxResults: 2500,
        singleEvents: true, // décompose les récurrences en instances concrètes
      );

      _logger.info('📊 Nombre d\'événements récupérés: ${page.items?.length ?? 0}');

      // Convertit chaque événement agenda en objet RugbyEvent
      final events = <RugbyEvent>[];
      for (final item in page.items ?? const <gcal.Event>[]) {
        try {
          final event = RugbyEvent.fromCalendarEvent(item);
          events.add(event);
        } catch (e) {
          _logger.error('❌ Erreur lors du mapping de l\'événement ${item.id}',
              error: e);
        }
      }

      _logger.success('✅ ${events.length} événements valides récupérés');

      // Sauvegarde les événements en base de données (cache hors ligne)
      if (events.isNotEmpty) {
        await _db!.insertEvents(events);
      }

      return events;
    } catch (e) {
      _logger.error('❌ Erreur lors de la récupération des événements Google Agenda',
          error: e);
      return [];
    }
  }

  // Récupère les événements dans une plage de dates
  Future<List<RugbyEvent>> fetchEventsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      if (_db == null) {
        await init();
      }

      // timeMin/timeMax attendent des instants ; le SDK googleapis les
      // sérialise lui-même en UTC (ISO 8601 Z).
      final page = await _calendar.events.list(
        GoogleCalendarConfig.calendarId,
        timeMin: startDate,
        timeMax: endDate,
        maxResults: 2500,
        singleEvents: true,
      );

      final events = <RugbyEvent>[];
      for (final item in page.items ?? const <gcal.Event>[]) {
        try {
          events.add(RugbyEvent.fromCalendarEvent(item));
        } catch (e) {
          _logger.error('❌ Erreur lors du mapping de l\'événement ${item.id}',
              error: e);
        }
      }

      return events;
    } catch (e) {
      _logger.error('❌ Erreur lors de la récupération des événements (plage de dates)',
          error: e);
      return [];
    }
  }

  // Récupère les événements d'un mois spécifique
  Future<List<RugbyEvent>> fetchEventsForMonth(DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);

    return fetchEventsByDateRange(startDate, endDate);
  }

  // Retourne les événements en cache hors ligne (utilisé par l'écran home
  // uniquement lorsque le réseau est indisponible)
  Future<List<RugbyEvent>> getEventsFromCache() async {
    try {
      return await _dbService.getAllEvents();
    } catch (e) {
      _logger.error('❌ Erreur lors de la récupération des événements en cache',
          error: e);
      return [];
    }
  }
}
