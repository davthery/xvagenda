import '../utils/logger.dart';

class RugbyEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? category; // Ex: Match, Entraînement, Réunion
  
  static final _logger = AppLogger();

  RugbyEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    this.category,
  });

  // Constructeur depuis une ligne Google Sheets
  // Format attendu: [ID, Titre, Description, Date début, Date fin, Lieu, Catégorie]
  factory RugbyEvent.fromSheetRow(List<dynamic> row) {
    _logger.debug('📋 Parsing ligne Google Sheets:');
    for (int i = 0; i < row.length; i++) {
      _logger.debug('  [$i]: ${row[i]} (${row[i].runtimeType})');
    }
    
    final event = RugbyEvent(
      id: row.isNotEmpty ? row[0].toString() : '',
      title: row.length > 1 ? row[1].toString() : 'Sans titre',
      description: row.length > 2 ? row[2].toString() : '',
      startTime: row.length > 3 ? _parseDateTime(row[3].toString()) : DateTime.now(),
      endTime: row.length > 4 ? _parseDateTime(row[4].toString()) : DateTime.now(),
      location: row.length > 5 && row[5].toString().isNotEmpty ? row[5].toString() : null,
      category: row.length > 6 && row[6].toString().isNotEmpty ? row[6].toString() : null,
    );
    
    _logger.success('✅ Événement créé: ${event.title} - ${event.startTime}');
    return event;
  }

  // Parse une date au format ISO ou dd/MM/yyyy HH:mm
  static DateTime _parseDateTime(String dateStr) {
    if (dateStr.isEmpty) {
      _logger.warning('⚠️ Date vide détectée, utilisation de la date actuelle');
      return DateTime.now();
    }

    // Nettoyer la chaîne
    dateStr = dateStr.trim();
    
    try {
      // Format ISO 8601: 2025-12-01T14:00:00 ou 2025-12-01
      if (dateStr.contains('T') || dateStr.contains('-')) {
        final parsed = DateTime.parse(dateStr);
        _logger.success('✅ Date ISO parsée: $dateStr -> $parsed');
        return parsed;
      }
    } catch (e) {
      _logger.debug('❌ Échec parsing ISO pour: $dateStr');
    }

    try {
      // Format français: dd/MM/yyyy HH:mm ou dd/MM/yyyy
      if (dateStr.contains('/')) {
        final parts = dateStr.split(' ');
        final dateParts = parts[0].split('/');
        
        if (dateParts.length == 3) {
          final day = int.parse(dateParts[0].trim());
          final month = int.parse(dateParts[1].trim());
          final year = int.parse(dateParts[2].trim());
          
          int hour = 0;
          int minute = 0;
          
          // Si une heure est présente
          if (parts.length > 1 && parts[1].isNotEmpty) {
            final timeParts = parts[1].split(':');
            if (timeParts.length >= 2) {
              hour = int.parse(timeParts[0].trim());
              minute = int.parse(timeParts[1].trim());
            }
          }
          
          final parsed = DateTime(year, month, day, hour, minute);
          _logger.success('✅ Date française parsée: $dateStr -> $parsed');
          return parsed;
        }
      }
    } catch (e) {
      _logger.debug('❌ Échec parsing français pour: $dateStr - Erreur: $e');
    }

    try {
      // Format américain: MM/dd/yyyy HH:mm
      if (dateStr.contains('/')) {
        final parts = dateStr.split(' ');
        final dateParts = parts[0].split('/');
        
        if (dateParts.length == 3 && int.parse(dateParts[0]) > 12) {
          // Si le premier nombre > 12, c'est probablement un jour
          final day = int.parse(dateParts[1].trim());
          final month = int.parse(dateParts[0].trim());
          final year = int.parse(dateParts[2].trim());
          
          int hour = 0;
          int minute = 0;
          
          if (parts.length > 1 && parts[1].isNotEmpty) {
            final timeParts = parts[1].split(':');
            if (timeParts.length >= 2) {
              hour = int.parse(timeParts[0].trim());
              minute = int.parse(timeParts[1].trim());
            }
          }
          
          final parsed = DateTime(year, month, day, hour, minute);
          _logger.success('✅ Date américaine parsée: $dateStr -> $parsed');
          return parsed;
        }
      }
    } catch (e) {
      _logger.debug('❌ Échec parsing américain pour: $dateStr');
    }

    // Format date Excel (numéro de série)
    try {
      final excelDate = double.tryParse(dateStr);
      if (excelDate != null && excelDate > 1) {
        // Excel compte depuis le 1/1/1900
        final baseDate = DateTime(1899, 12, 30);
        final parsed = baseDate.add(Duration(days: excelDate.floor()));
        _logger.success('✅ Date Excel parsée: $dateStr -> $parsed');
        return parsed;
      }
    } catch (e) {
      _logger.debug('❌ Échec parsing Excel pour: $dateStr');
    }

    _logger.warning('⚠️ Format de date non reconnu: "$dateStr", utilisation de la date actuelle');
    return DateTime.now();
  }

  @override
  String toString() {
    return 'RugbyEvent{title: $title, startTime: $startTime, location: $location}';
  }
}
