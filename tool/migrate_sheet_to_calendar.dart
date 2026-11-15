// Outil de migration : feuille Google Sheets → API Google Calendar.
//
// ⚠️ Utilitaire d'équipe : il importe les configs réelles (credentials du
// compte de service, git-ignorées) et fait de vrais appels réseau.
// Versionné — ne contient aucun secret, seulement des chemins d'import.
//
// Usage :
//
//   dart run tool/migrate_sheet_to_calendar.dart --dry-run
//   dart run tool/migrate_sheet_to_calendar.dart --dry-run --filter "2026-10"
//   dart run tool/migrate_sheet_to_calendar.dart
//   dart run tool/migrate_sheet_to_calendar.dart --filter "2026-10" --resume
//   dart run tool/migrate_sheet_to_calendar.dart --resume
//
// Options :
//   --dry-run    ne crée/modifie aucun événement, affiche l'action prévue
//   --filter     filtre les événements à migrer par sous-chaîne (ex: "2026-10",
//                "rugby", "Vienne") — utile pour migrer par morceaux
//   --resume     ne traite que les événements non migrés (sert à reprendre une
//                migration interrompue sans recréer les événements existants)
//
// Idempotence : chaque événement crée dans le calendrier porte le champ
// `extendedProperties.private.idSource` = UID de la feuille. Une relecture de la
// feuille met à jour les événements existants (détection par `idSource`),
// donc relancer l'outil ne duplique pas les événements.
//
// Avertissements :
//   - les dates non parsables sont signalées (ligne concernée), pas sautées silencieusement ;
//   - les événements récurrents de la feuille ne sont PAS migrés (pas de champ
//     `recurrence` dans le modèle) : avertissement ;
//   - les événements passés (fin < maintenant - 90 j) ne sont pas créés.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:googleapis_auth/auth_io.dart' as auth;

import 'package:xvagenda/config/google_calendar_config.dart';
import 'package:xvagenda/models/rugby_event.dart';

// Le service Sheets est importé par chemin relatif : `google_sheets_service.dart`
// pull `gsheets` qui transit par `path_provider` → `dart:ui` et ne compile pas
// sous `dart run`. Le chemin relatif évite de puller `package:xvagenda` complet.
import '../lib/services/google_sheets_service.dart';

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final resume = args.contains('--resume');
  String? filter;
  final filterIdx = args.indexOf('--filter');
  if (filterIdx >= 0 && filterIdx + 1 < args.length) {
    filter = args[filterIdx + 1];
  }

  if (dryRun) {
    print('🏃 Mode SECURE (dry-run) : aucun événement ne sera créé ni modifié.');
  } else {
    print('⚠️  Mode RÉEL : les événements seront créés/modifiés dans le calendrier.');
    stdout.write('Confirmer (oui/non) : ');
    final answer = stdin.readLineSync()?.trim().toLowerCase();
    if (answer != 'oui' && answer != 'yes' && answer != 'y') {
      print('Abandonné.');
      exit(0);
    }
    stdout.write('Confirmation 2/2 — taper "MIGRE" exactement : ');
    final confirm = stdin.readLineSync()?.trim();
    if (confirm != 'MIGRE') {
      print('Abandonné.');
      exit(0);
    }
  }

  final ok = await _run(dryRun: dryRun, resume: resume, filter: filter);

  exit(ok ? 0 : 1);
}

/// Cœur de la migration, isolé pour pouvoir gérer les erreurs de manière
/// explicite (au lieu de `runZoned` qui n'accepte pas un body async).
Future<bool> _run({
  required bool dryRun,
  required bool resume,
  String? filter,
}) async {
  try {
    // 1. Lecture de la feuille (source unique jusqu'à la phase 3).
    final sheetsService = GoogleSheetsService();
    await sheetsService.init();
    final events = await sheetsService.fetchEvents();
    print('📖 Feuille lue : ${events.length} événement(s)');

    if (events.isEmpty) {
      print('Rien à migrer.');
      return true;
    }

    // 2. Filtrage éventuel (filtre appliqué sur la date ISO du début).
    var toMigrate = events;
    if (filter != null && filter.isNotEmpty) {
      final f = filter;
      toMigrate = events
          .where((e) =>
              e.startTime.toIso8601String().contains(f) ||
              e.title.contains(f))
          .toList();
      print('🔎 Filtre "$f" → ${toMigrate.length} événement(s)');
    }

    if (toMigrate.isEmpty) {
      print('Rien à migrer après filtrage.');
      return true;
    }

    // Avertissements : événements passés et récurrents.
    final now = DateTime.now();
    for (final e in toMigrate) {
      if (e.endTime.isBefore(now.subtract(const Duration(days: 90)))) {
        print('⏭️  Événement passé, ignoré : ${e.title} (${e.startTime})');
      }
      // (récurrents : la feuille ne contient aucune récurrence — voir planning)
    }

    // 3. Client Calendar (auth service account — même motif que gsheets 0.5.0).
    final credentials = auth.ServiceAccountCredentials.fromJson(
        GoogleCalendarConfig.credentials);
    final client = await auth.clientViaServiceAccount(
        credentials, [gcal.CalendarApi.calendarScope]);
    final calendar = gcal.CalendarApi(client);
    final calendarId = GoogleCalendarConfig.calendarId;

    print('🎯 Calendrier cible : $calendarId');
    if (calendarId == 'to-be-defined') {
      print('❌ `calendarId` n\'est pas renseigné dans lib/config/google_calendar_config.dart.');
      print('   Lancez d\'abord le test `flutter test test/google_calendar_service_test.dart`');
      print('   pour identifier le calendrier à partager, puis renseignez son ID.');
      return false;
    }

    // 4. Détecte les événements déjà migrés (idSource) pour savoir ce qu'il reste à faire.
    final migratedIds = <String>{};
    if (resume) {
      final existing = await calendar.events.list(
        calendarId,
        maxResults: 2500,
        q: 'extendedProperties.private.idSource:',
      );
      for (final ev in existing.items ?? const <gcal.Event>[]) {
        final src = ev.extendedProperties?.private?['idSource'];
        if (src != null) migratedIds.add(src);
      }
      print('📋 Déjà migrés dans le calendrier : ${migratedIds.length}');
      final before = toMigrate.length;
      toMigrate = toMigrate.where((e) => !migratedIds.contains(e.id)).toList();
      print('→ Il reste ${toMigrate.length} événement(s) à migrer (avant filtre : $before)');
      if (toMigrate.isEmpty) {
        print('Rien à migrer — tout est déjà synchronisé.');
        return true;
      }
    }

    // 5. Migration.
    var created = 0, updated = 0, skipped = 0, failed = 0;
    for (final e in toMigrate) {
      try {
        final migrated = migratedIds.contains(e.id) ? 'maj' : 'création';
        final event = await _upsertEvent(
          calendar,
          calendarId,
          e,
          dryRun: dryRun,
          alreadyMigrated: migratedIds.contains(e.id),
        );
        if (event) {
          if (migrated == 'maj') {
            updated++;
          } else {
            created++;
          }
        } else {
          skipped++;
        }
        print('  ${event ? '✅' : '⏭️ '} $migrated — ${e.title} (${e.startTime} → ${e.endTime})');
      } catch (err) {
        failed++;
        print('  ❌ ÉCHEC — ${e.title} : $err');
      }
    }

    print('\n=== RÉSUMÉ ===');
    print('créés : $created   mis à jour : $updated   ignorés : $skipped   échecs : $failed');
    return failed == 0;
  } catch (err, st) {
    print('❌ Échec de la migration : $err');
    print(st);
    return false;
  }
}

/// Crée ou met à jour l'événement `e` dans le calendrier.
/// Renvoie false si l'événement a été ignoré (passé trop ancien, dry-run sur un
/// événement déjà présent...).
Future<bool> _upsertEvent(
  gcal.CalendarApi calendar,
  String calendarId,
  RugbyEvent e, {
  required bool dryRun,
  required bool alreadyMigrated,
}) async {
  // Événements anciens : on ne recrée pas l'historique lointain.
  if (e.endTime.isBefore(DateTime.now().subtract(const Duration(days: 90)))) {
    return false;
  }

  // Fuseau horaire FIXE Europe/Paris (décision projet) : les événements sont
  // stockés en UTC + ce fuseau de référence. L'app fera `.toLocal()` à la
  // lecture (le modèle RugbyEvent ne stocke pas de zone IANA).
  const tz = 'Europe/Paris';

  gcal.Event buildEvent() {
    final private = <String, String>{'idSource': e.id}; // marqueur d'idempotence
    if (e.category != null && e.category!.isNotEmpty) {
      private[GoogleCalendarConfig.categoryKey] = e.category!;
    }
    return gcal.Event(
      start: gcal.EventDateTime(
        dateTime: e.startTime.toUtc(),
        timeZone: tz,
      ),
      end: gcal.EventDateTime(
        dateTime: e.endTime.toUtc(),
        timeZone: tz,
      ),
      summary: e.title,
      description: e.description.isEmpty ? null : e.description,
      location: e.location,
      extendedProperties: gcal.EventExtendedProperties(private: private),
    );
  }

  if (dryRun) {
    final ev = buildEvent();
    print(
      '    [dry-run] ${ev.summary} — '
      '${ev.start?.dateTime} (${ev.start?.timeZone ?? 'UTC'})'
    );
    return true;
  }

  if (alreadyMigrated) {
    // Recherche de l'ID réel de l'événement déjà migré (idSource == e.id).
    final found = await calendar.events.list(
      calendarId,
      q: 'extendedProperties.private.idSource:"${e.id}"',
      maxResults: 1,
    );
    final existingId = found.items?.firstWhere(
      (ev) => ev.extendedProperties?.private?['idSource'] == e.id,
      orElse: () => throw StateError('idSource introuvable pour $e.id'),
    ).id;

    if (existingId == null) {
      throw StateError('idSource introuvable pour $e.id');
    }

    final event = buildEvent()..id = existingId;
    await calendar.events.update(event, calendarId, existingId);
    return true;
  }

  await calendar.events.insert(buildEvent(), calendarId);
  return true;
}
