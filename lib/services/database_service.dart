import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../models/rugby_event.dart';
import '../utils/logger.dart';


class DatabaseService {
  static const String _dbName = 'xvagenda.db';
  static const int _dbVersion = 1;
  static const String _eventsTable = 'rugby_events';

  static Database? _database;
  final _logger = AppLogger();

  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  // Getter pour la base de données
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  // Initialise la base de données
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = path.join(databasesPath, _dbName);

    _logger.info('🗄️ Initialisation de la base de données: $dbPath');

    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  // Crée les tables
  Future<void> _createDatabase(Database db, int version) async {
    _logger.info('📊 Création des tables de la base de données');

    await db.execute('''
      CREATE TABLE $_eventsTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        location TEXT,
        category TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    _logger.success('✅ Table $_eventsTable créée');
  }

  // Gère les mises à jour de schéma
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    _logger.info('🔄 Mise à jour de la base de données v$oldVersion -> v$newVersion');
  }

  // Insère ou remplace un événement
  Future<void> insertEvent(RugbyEvent event) async {
    final db = await database;
    await db.insert(
      _eventsTable,
      {
        ...event.toMap(),
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _logger.debug('💾 Événement sauvegardé: ${event.title}');
  }

  // Insère ou remplace plusieurs événements
  Future<void> insertEvents(List<RugbyEvent> events) async {
    final db = await database;
    final batch = db.batch();

    for (final event in events) {
      batch.insert(
        _eventsTable,
        {
          ...event.toMap(),
          'createdAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
    _logger.success('💾 ${events.length} événements sauvegardés en base');
  }

  // Récupère tous les événements
  Future<List<RugbyEvent>> getAllEvents() async {
    final db = await database;
    final maps = await db.query(
      _eventsTable,
      orderBy: 'startTime ASC',
    );

    if (maps.isEmpty) {
      _logger.debug('📭 Aucun événement en base de données');
      return [];
    }

    final events = maps.map((map) => RugbyEvent.fromMap(map)).toList();
    _logger.success('📖 ${events.length} événements chargés de la base');
    return events;
  }

  // Récupère les événements d'une plage de dates
  Future<List<RugbyEvent>> getEventsByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await database;
    final maps = await db.query(
      _eventsTable,
      where: 'startTime >= ? AND startTime <= ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'startTime ASC',
    );

    final events = maps.map((map) => RugbyEvent.fromMap(map)).toList();
    return events;
  }

  // Supprime tous les événements
  Future<void> deleteAllEvents() async {
    final db = await database;
    await db.delete(_eventsTable);
    _logger.info('🗑️ Tous les événements supprimés');
  }

  // Supprime un événement par ID
  Future<void> deleteEvent(String id) async {
    final db = await database;
    await db.delete(
      _eventsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    _logger.debug('🗑️ Événement supprimé: $id');
  }

  // Compte le nombre d'événements
  Future<int> getEventCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_eventsTable');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Ferme la base de données
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _logger.info('🔌 Base de données fermée');
    }
  }
}
