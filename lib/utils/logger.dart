import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  File? _logFile;
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDirectory = Directory('${directory.path}/logs');
      
      if (!await logDirectory.exists()) {
        await logDirectory.create(recursive: true);
      }
      
      final fileName = 'xvagenda_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.log';
      _logFile = File('${logDirectory.path}/$fileName');
      
      // Nettoyer les anciens logs (garder seulement les 7 derniers jours)
      _cleanOldLogs(logDirectory);
    } catch (e) {
      print('⚠️ Impossible d\'initialiser le fichier de log: $e');
    }
  }

  void _cleanOldLogs(Directory logDirectory) async {
    try {
      final now = DateTime.now();
      final files = logDirectory.listSync();
      
      for (var file in files) {
        if (file is File && file.path.endsWith('.log')) {
          final stat = await file.stat();
          final age = now.difference(stat.modified).inDays;
          
          if (age > 7) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      // Ignorer les erreurs de nettoyage
    }
  }

  void _log(String level, String message, {Object? error, StackTrace? stackTrace}) {
    final timestamp = _dateFormat.format(DateTime.now());
    final logMessage = '[$timestamp] [$level] $message';
    
    // Afficher sur la console
    print(logMessage);
    
    if (error != null) {
      print('Error: $error');
    }
    
    if (stackTrace != null) {
      print('StackTrace: $stackTrace');
    }
    
    // Écrire dans le fichier
    _writeToFile(logMessage, error, stackTrace);
  }

  void _writeToFile(String message, Object? error, StackTrace? stackTrace) async {
    if (_logFile == null) return;
    
    try {
      final buffer = StringBuffer(message);
      buffer.writeln();
      
      if (error != null) {
        buffer.writeln('Error: $error');
      }
      
      if (stackTrace != null) {
        buffer.writeln('StackTrace: $stackTrace');
      }
      
      await _logFile!.writeAsString(
        buffer.toString(),
        mode: FileMode.append,
      );
    } catch (e) {
      // Ne pas bloquer l'application si l'écriture échoue
    }
  }

  void info(String message) {
    _log('INFO', message);
  }

  void debug(String message) {
    _log('DEBUG', message);
  }

  void warning(String message) {
    _log('WARNING', message);
  }

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message, error: error, stackTrace: stackTrace);
  }

  void success(String message) {
    _log('SUCCESS', message);
  }

  Future<String?> getLogFilePath() async {
    return _logFile?.path;
  }

  Future<String> getLogContent() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return 'Aucun log disponible';
    }
    
    try {
      return await _logFile!.readAsString();
    } catch (e) {
      return 'Erreur lors de la lecture des logs: $e';
    }
  }
}
