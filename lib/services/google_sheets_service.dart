import 'package:gsheets/gsheets.dart';
import '../models/rugby_event.dart';
import '../utils/logger.dart';

class GoogleSheetsService {
  // Vos credentials Google Sheets API
  // IMPORTANT: Remplacer ces valeurs par vos propres credentials
  static const _credentials = r'''
{
 "type": "service_account",
  "project_id": "agenda2flutter",
  "private_key_id": "b39b65570650e546a243cef9dd23f5223a5ca260",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC8Ka8ugcffUaP5\nDd0rKsGkN72fLSBxQ3WePsFKTRPbjw3HcBo+gdEQF+9m57HTUDnavM6r+u3MpDSw\nDfGZGuTgAgYX6jSO5UcYDzpZCFAor5SRX+vIIkFOxTM7oWFJojRDWiWCa00U0gYX\nLss6k2H2bjhCmYZClwOtqMqQWrNqpfsi8uD9s36Lzw/IgmUIhXprbz2V/jQUyzN9\n2PXnMM10VxCu4bBe/KLWcqyPflI6Vcby5T+zBn8hmr6a9WPodtHi71FieG8XlPbO\nIT03a5WuVN5qSEhGt5nhQU5p6r9xEsYmJe6eq346RtjYUkIxA3I6rICURweHov3D\nqaF0M5OXAgMBAAECggEAWfG1F06bW+FbOADMEcfo85ZfkrjQEsRT83Z9EAbjMKdj\nx0uLiAinBoHigvbLNr9ZQHnTcztKM/Hka6nmrLDB6mCdSA5A3HO19cbFtex24NP5\neTp4a10QidZTJLSCXF/oiq+LUZn4KTUyCx/nrtLn15QdWZyopKkqbXdLiRCKRjZJ\no1BklbFxQql9gr/9Dd79yzL2A8hebQkauJaEWUINK2X1nnosl7TS//w2/ZtvtFvR\n6myNkFOiakVC69OMDVz+gP/hPhOpe6RhdajQw0bIB/A3wrCjWdWWS6b8jIeG6gL4\nwe+KwjFORe4u9DhW6DLClpypwjqx7OQgbjXgvpsP3QKBgQDxDbQvGzZ/kcMA7DP1\nUNFNQJ9kgNlt4Lska4UkBvGCgSHhf5EXpBTXuki0YTX+DI24KKq59fqdVW0wkZf2\n8AmmPpyFNUz92pY63wgc+M7q/yKf0+9JTlYrIzO41ieF67BXz9R1lzoledNQ66sn\nUsWQiR4FU3FWqGi/3RoiuZF/tQKBgQDH1G9DryDyJXH0Pkb+WSLUGyUFLN8I8mDK\nF6hUDbQNFQ3UQBKZ5k5jSR1p7b8yR7Kri9y4HCntcWzhT1b6qjj6i9E9rIwhOvxl\na2ReKka42z+AYfzzAMHTRvwIqec9+GDJShIJwK3ZuWyIZjBFQ0WHLBgAI4gBSxw9\noNIHl+zdmwKBgGe7B/DFexxGc23wNyO31Xmy92RedjJsZNv1UOQCAOex/gx1wtAz\nkayLw0GsG3npmQrIpT9E9MXDvysJXCWtgdmCVASWvTz4VXGcDHe7Mf+6LwIsR2p6\nRWZmzZkavwNIOyhujPTVUPZTiHXoFEzlt5LNDpgoIjuyWPFHijmrNUuJAoGAHiZP\nI0cpEV/U8aTz0SxhtN7jlwROImtvbw5it0vZ/p9OlteT9uRor1I4veLBFjT7ICba\nBm05ZjnW06fE180XC7ZMu6FtAxaDPkoVup9mTD3INvaR05gpplbvb98ypIb1E2m5\njv8jO9ZeKbZBUjH0K5DbjinOO2O5vxKkncCuXEECgYEAuhK0dCx1rChRJW++Yee/\nV+/KlKJNEylEQzZwIMeWYZwUUeq2kSYqW8bvbY7OBeBdQcGaEmxy0eL3OUCNU4JC\nwYoQfak7TSMLm7Ml/P94482MCFaG6cq2BvgEGUk5PWVqi3RFh9nxyaiLe/+lxxlI\ntEHU84rtiDnFF6b3wjl3vFw=\n-----END PRIVATE KEY-----\n",
  "client_email": "gsheets@agenda2flutter.iam.gserviceaccount.com",
  "client_id": "110225566697883866790",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/gsheets%40agenda2flutter.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
''';

  // ID de votre Google Sheet
  static const _spreadsheetId = '1bx6UsUSK332jkwnGWHUW9ox9hb3vVppa6m1ITGzhBW8';
  
  // Nom de la feuille contenant les événements
  static const _worksheetTitle = 'Planning';

  final _logger = AppLogger();
  
  GSheets? _gsheets;
  Spreadsheet? _spreadsheet;
  Worksheet? _worksheet;

  // Initialise la connexion à Google Sheets
  Future<void> init() async {
    try {
      _gsheets = GSheets(_credentials);
      _spreadsheet = await _gsheets!.spreadsheet(_spreadsheetId);
      _worksheet = _spreadsheet!.worksheetByTitle(_worksheetTitle);
      
      if (_worksheet == null) {
        throw Exception('Feuille "$_worksheetTitle" introuvable');
      }
    } catch (e) {
      _logger.error('Erreur lors de l\'initialisation de Google Sheets', error: e);
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
        if (row.isEmpty || (row.length > 1 && row[1].toString().trim().isEmpty)) {
          _logger.debug('⏭️ Ligne ${i + 2} ignorée (vide)');
          continue;
        }
        
        try {
          final event = RugbyEvent.fromSheetRow(row);
          events.add(event);
        } catch (e) {
          _logger.error('❌ Erreur lors du parsing de la ligne ${i + 2}', error: e);
        }
      }

      _logger.success('✅ ${events.length} événements valides récupérés');
      return events;
    } catch (e) {
      _logger.error('❌ Erreur lors de la récupération des événements', error: e);
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
      return event.startTime.isAfter(startDate.subtract(const Duration(days: 1))) &&
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
