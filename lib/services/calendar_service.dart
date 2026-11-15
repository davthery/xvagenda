import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:googleapis_auth/auth_io.dart';
import '../config/google_calendar_config.dart';
import '../models/rugby_event.dart';
import '../utils/logger.dart';
import 'database_service.dart';

/// Service de synchronisation avec Google Agenda (Calendar API)
///
/// Miroir de [GoogleSheetsService] : expose `init()`, `fetchEvents()`,
/// `fetchEventsByDateRange()`, `fetchEventsForMonth()`.
///
/// Les erreurs réseau/API sont **propagées** à l'appelant : c'est lui qui
/// décide du repli sur le cache local (voir `HomeScreen._loadEvents`).
class CalendarService {
  final _logger = AppLogger();
  final _dbService = DatabaseService();

  AutoRefreshingAuthClient? _client;
  gcal.CalendarApi? _calendar;

  /// Initialise la connexion à Google Agenda.
  ///
  /// Idempotent : sans effet si déjà initialisé. Après un échec (ex. hors
  /// ligne), un nouvel appel retente la connexion.
  Future<void> init() async {
    if (_calendar != null) return;

    try {
      final credentials = ServiceAccountCredentials.fromJson(
        GoogleCalendarConfig.credentials,
      );
      final client = await clientViaServiceAccount(
        credentials,
        const [gcal.CalendarApi.calendarScope],
      );
      _client = client;
      _calendar = gcal.CalendarApi(client);

      _logger.info(
          '🔌 Service Google Agenda initialisé (calendrier: ${GoogleCalendarConfig.calendarId})');
    } catch (e) {
      _logger.error('Erreur lors de l\'initialisation de Google Agenda',
          error: e);
      rethrow;
    }
  }

  /// Expose l'API Calendar initialisée (utile pour des outils, ex. migration).
  gcal.CalendarApi get calendarApi {
    final calendar = _calendar;
    if (calendar == null) {
      throw StateError('CalendarService non initialisé : appeler init() avant');
    }
    return calendar;
  }

  /// Libère le client HTTP authentifié.
  void close() {
    _client?.close();
    _client = null;
    _calendar = null;
  }

  /// Récupère tous les événements depuis Google Agenda et met à jour le cache.
  ///
  /// Lève une exception si l'agenda est injoignable.
  Future<List<RugbyEvent>> fetchEvents() async {
    await init();

    _logger.info('🔄 Récupération des événements depuis Google Agenda...');

    final gcal.Events page;
    try {
      page = await calendarApi.events.list(
        GoogleCalendarConfig.calendarId,
        maxResults: 2500,
        singleEvents: true, // décompose les récurrences en instances concrètes
      );
    } catch (e) {
      _logger.error(
          '❌ Erreur lors de la récupération des événements Google Agenda',
          error: e);
      rethrow;
    }

    _logger
        .info('📊 Nombre d\'événements récupérés: ${page.items?.length ?? 0}');

    final events = _mapEvents(page.items);
    _logger.success('✅ ${events.length} événements valides récupérés');

    // Sauvegarde en cache hors ligne. Un échec d'écriture locale ne doit pas
    // faire échouer un chargement réseau réussi.
    if (events.isNotEmpty) {
      try {
        await _dbService.insertEvents(events);
      } catch (e) {
        _logger.error('❌ Erreur lors de la mise en cache des événements',
            error: e);
      }
    }

    return events;
  }

  /// Récupère les événements dans une plage de dates.
  ///
  /// Lève une exception si l'agenda est injoignable.
  Future<List<RugbyEvent>> fetchEventsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    await init();

    try {
      // timeMin/timeMax attendent des instants ; le SDK googleapis les
      // sérialise lui-même en UTC (ISO 8601 Z).
      final page = await calendarApi.events.list(
        GoogleCalendarConfig.calendarId,
        timeMin: startDate,
        timeMax: endDate,
        maxResults: 2500,
        singleEvents: true,
      );
      return _mapEvents(page.items);
    } catch (e) {
      _logger.error(
          '❌ Erreur lors de la récupération des événements (plage de dates)',
          error: e);
      rethrow;
    }
  }

  /// Récupère les événements d'un mois spécifique.
  Future<List<RugbyEvent>> fetchEventsForMonth(DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);

    return fetchEventsByDateRange(startDate, endDate);
  }

  /// Retourne les événements en cache hors ligne.
  Future<List<RugbyEvent>> getEventsFromCache() async {
    try {
      return await _dbService.getAllEvents();
    } catch (e) {
      _logger.error('❌ Erreur lors de la récupération des événements en cache',
          error: e);
      return [];
    }
  }

  // Convertit les événements agenda en RugbyEvent ; un événement mal formé
  // est ignoré (et loggé) sans faire échouer l'ensemble.
  List<RugbyEvent> _mapEvents(List<gcal.Event>? items) {
    final events = <RugbyEvent>[];
    for (final item in items ?? const <gcal.Event>[]) {
      try {
        events.add(RugbyEvent.fromCalendarEvent(item));
      } catch (e) {
        _logger.error('❌ Erreur lors du mapping de l\'événement ${item.id}',
            error: e);
      }
    }
    return events;
  }
}
