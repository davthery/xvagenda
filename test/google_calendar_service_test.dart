// Test MANUEL d'appel réel à l'API Google Calendar.
//
// ⚠️ NON versionné (voir .gitignore) : il importe
// `lib/config/google_calendar_config.dart` (git-ignoré, credentials de service
// réels) et fait un vrai appel réseau. Exécuter avec :
//
//   flutter test test/google_calendar_service_test.dart
//
// Prérequis : le calendrier partagé a été créé et partagé (en lecture) avec
// l'email du compte de service `agenda2flutter@agenda2flutter.iam...`.
//
// À la fin, ce test affiche l'identifiant du calendrier (id, email) pour
// renseigner `calendarId` dans `lib/config/google_calendar_config.dart`,
// puis liste les événements du calendrier et vérifie le mapping
// `RugbyEvent.fromCalendarEvent`.
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xvagenda/config/google_calendar_config.dart';
import 'package:xvagenda/models/rugby_event.dart';
import 'package:xvagenda/services/calendar_service.dart';

void main() {
  late gcal.CalendarApi calendar;
  late gcal.Events eventsPage;

  setUpAll(() async {
    print('🔑 Compte de service agenda2flutter (le calendrier doit lui être partagé)');

    final credentials = ServiceAccountCredentials.fromJson(
      GoogleCalendarConfig.credentials,
    );
    final client = await clientViaServiceAccount(
      credentials,
      const [gcal.CalendarApi.calendarScope],
    );
    calendar = gcal.CalendarApi(client);

    // Affiche les calendriers accessibles : aide à trouver l'ID à renseigner
    // dans `GoogleCalendarConfig.calendarId`.
    final calendars = await calendar.calendarList.list();
    print('\n📅 Calendriers accessibles (${calendars.items?.length ?? 0}) :');
    for (final c in calendars.items ?? const <gcal.CalendarListEntry>[]) {
      final marker = c.id == GoogleCalendarConfig.calendarId ? '  ← configuré' : '';
      print('  • id: ${c.id}  |  calendrier: ${c.summary ?? '-'}  |  accès: ${c.accessRole ?? '-'}$marker');
    }
    print('');

    // Récupère les événements du calendrier configuré.
    eventsPage = await calendar.events.list(
      GoogleCalendarConfig.calendarId,
      maxResults: 2500,
      singleEvents: true,
    );
  });

  test('le calendrier configuré est accessible', () {
    expect(eventsPage.items, isNotNull);
    print('✅ Accès OK — ${eventsPage.items!.length} événement(s) dans "${eventsPage.summary ?? GoogleCalendarConfig.calendarId}"');
  });

  test('les événements sont mappés en RugbyEvent', () {
    final events = eventsPage.items!
        .map(RugbyEvent.fromCalendarEvent)
        .toList();

    print('📋 ÉVÉNEMENTS DU CALENDRIER (${events.length}) :');
    for (final e in events) {
      print('  • ${e.startTime.toLocal()} → ${e.endTime.toLocal()}  |  '
          '${e.title}  |  cat: ${e.category ?? '-'}  |  lieu: ${e.location ?? '-'}');
    }

    // Le mapping doit toujours produire un ID et un horaire valide.
    for (final e in events) {
      expect(e.id, isNotEmpty);
      expect(e.startTime, isNotNull);
      expect(e.endTime, isNotNull);
    }
    expect(events, isNotEmpty,
        reason: 'Le calendrier partagé doit contenir au moins un événement (voir l\'outil tool/migrate_sheet_to_calendar.dart)');
  });

  test('le service complet fetchEvents fonctionne (réseau + cache local)', () async {
    final service = CalendarService();
    await service.init();

    final events = await service.fetchEvents();
    print('🔄 fetchEvents() → ${events.length} événement(s)');
    expect(events, isNotEmpty);
  });
}
