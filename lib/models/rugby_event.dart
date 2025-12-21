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

  // Convertir en Map pour la base de données
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'category': category,
    };
  }

  // Créer depuis une Map de la base de données
  factory RugbyEvent.fromMap(Map<String, dynamic> map) {
    return RugbyEvent(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: DateTime.parse(map['endTime'] as String),
      location: map['location'] as String?,
      category: map['category'] as String?,
    );
  }

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

  // Parse une date au format ISO, Google Sheets ou dd/MM/yyyy HH:mm:ss
  static DateTime _parseDateTime(String dateStr) {
    if (dateStr.isEmpty) {
      _logger.warning('⚠️ Date vide détectée, utilisation de la date actuelle');
      return DateTime.now();
    }

    // Nettoyer la chaîne
    dateStr = dateStr.trim();
    _logger.debug('🔍 Tentative de parsing: "$dateStr"');
    
    try {
      // Format ISO 8601: 2025-12-01T14:00:00 ou 2025-12-01
      if (dateStr.contains('T') || (dateStr.contains('-') && dateStr.length >= 10)) {
        final parsed = DateTime.parse(dateStr);
        _logger.success('✅ Date ISO parsée: $dateStr -> $parsed');
        return parsed;
      }
    } catch (e) {
      _logger.debug('❌ Échec parsing ISO pour: $dateStr');
    }

    try {
      // Format YYYY-MM-DD (Google Sheets peut retourner ça)
      if (dateStr.contains('-') && !dateStr.contains('/')) {
        final parts = dateStr.split(' ');
        final dateParts = parts[0].split('-');
        
        if (dateParts.length == 3) {
          final year = int.parse(dateParts[0].trim());
          final month = int.parse(dateParts[1].trim());
          final day = int.parse(dateParts[2].trim());
          
          int hour = 0;
          int minute = 0;
          int second = 0;
          
          // Si une heure est présente
          if (parts.length > 1 && parts[1].isNotEmpty) {
            final timeParts = parts[1].split(':');
            if (timeParts.isNotEmpty) {
              hour = int.parse(timeParts[0].trim());
            }
            if (timeParts.length >= 2) {
              minute = int.parse(timeParts[1].trim());
            }
            if (timeParts.length >= 3) {
              second = int.parse(timeParts[2].trim());
            }
          }
          
          final parsed = DateTime(year, month, day, hour, minute, second);
          _logger.success('✅ Date YYYY-MM-DD parsée: $dateStr -> $parsed');
          return parsed;
        }
      }
    } catch (e) {
      _logger.debug('❌ Échec parsing YYYY-MM-DD pour: $dateStr - Erreur: $e');
    }

    try {
      // Format français: dd/MM/yyyy HH:mm:ss ou dd/MM/yyyy HH:mm ou dd/MM/yyyy
      if (dateStr.contains('/')) {
        final parts = dateStr.split(' ');
        final dateParts = parts[0].split('/');
        
        if (dateParts.length == 3) {
          final firstNum = int.parse(dateParts[0].trim());
          final secondNum = int.parse(dateParts[1].trim());
          final year = int.parse(dateParts[2].trim());
          
          // Heuristique: si le premier nombre > 12, c'est le jour (format français)
          // sinon, vérifier le mois
          int day, month;
          if (firstNum > 12) {
            day = firstNum;
            month = secondNum;
          } else if (secondNum > 12) {
            // Format américain détecté
            month = firstNum;
            day = secondNum;
          } else {
            // Ambigü - par défaut, on suppose français
            day = firstNum;
            month = secondNum;
          }
          
          int hour = 0;
          int minute = 0;
          int second = 0;
          
          // Si une heure est présente
          if (parts.length > 1 && parts[1].isNotEmpty) {
            final timeParts = parts[1].split(':');
            if (timeParts.isNotEmpty) {
              hour = int.parse(timeParts[0].trim());
            }
            if (timeParts.length >= 2) {
              minute = int.parse(timeParts[1].trim());
            }
            if (timeParts.length >= 3) {
              second = int.parse(timeParts[2].trim());
            }
          }
          
          final parsed = DateTime(year, month, day, hour, minute, second);
          _logger.success('✅ Date avec slash parsée ($day/$month/$year): $dateStr -> $parsed');
          return parsed;
        }
      }
    } catch (e) {
      _logger.debug('❌ Échec parsing avec slash pour: $dateStr - Erreur: $e');
    }

    // Format date Excel (numéro de série)
    try {
      final excelDate = double.tryParse(dateStr);
      if (excelDate != null && excelDate > 1) {
        // Excel compte depuis le 1/1/1900
        final baseDate = DateTime(1899, 12, 30);
        final parsed = baseDate.add(Duration(days: excelDate.floor()));
        
        // Gérer les heures décimales pour Excel
        if (excelDate != excelDate.floor()) {
          final fractionalPart = excelDate - excelDate.floor();
          
          // Convertir la fraction en heures, minutes, secondes
          final totalSeconds = fractionalPart * 24 * 60 * 60;
          final hours = (totalSeconds ~/ 3600).toInt();
          final remainingSeconds = totalSeconds - (hours * 3600);
          final minutes = (remainingSeconds ~/ 60).toInt();
          final seconds = (remainingSeconds - (minutes * 60)).toInt();
          
          _logger.debug('🔢 Excel: fraction=$fractionalPart -> ${hours}h:${minutes}m:${seconds}s');
          
          final result = DateTime(
            parsed.year,
            parsed.month,
            parsed.day,
            hours,
            minutes,
            seconds,
          );
          _logger.success('✅ Date Excel parsée: $dateStr -> $result');
          return result;
        }
        
        _logger.success('✅ Date Excel parsée (sans heure): $dateStr -> $parsed');
        return parsed;
      }
    } catch (e) {
      _logger.debug('❌ Échec parsing Excel pour: $dateStr - Erreur: $e');
    }

    _logger.warning('⚠️ Format de date non reconnu: "$dateStr", utilisation de la date actuelle');
    return DateTime.now();
  }

  @override
  String toString() {
    return 'RugbyEvent{title: $title, startTime: $startTime, location: $location}';
  }
}
