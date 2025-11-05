import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/library_entry.dart';
import '../utils/platform_utils.dart';
import 'logger_service.dart';

class LibraryService extends ChangeNotifier {
  LibraryService._({
    required this.logger,
    required Database database,
  })  : _database = database,
        _entries = const [];

  final LoggerService logger;
  final Database _database;
  final StreamController<List<LibraryEntry>> _entriesController =
      StreamController<List<LibraryEntry>>.broadcast();
  List<LibraryEntry> _entries;

  Stream<List<LibraryEntry>> get entriesStream => _entriesController.stream;
  List<LibraryEntry> get entries => List.unmodifiable(_entries);

  Future<void> refresh() async {
    final entries = await fetchAll();
    _entries = entries;
    _entriesController.add(entries);
    notifyListeners();
  }

  static Future<LibraryService> create({required LoggerService logger}) async {
    if (PlatformUtils.isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final supportDir = await getApplicationSupportDirectory();
    final dbFile = File(p.join(supportDir.path, 'eli_player.db'));
    final database = await openDatabase(
      dbFile.path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE library_entries (
            id TEXT PRIMARY KEY,
            url TEXT,
            title TEXT,
            artist TEXT,
            durationMs INTEGER,
            filePath TEXT,
            formatLabel TEXT,
            createdAt INTEGER,
            thumbnailPath TEXT,
            fileSize INTEGER
          )
        ''');
      },
    );

    final service = LibraryService._(logger: logger, database: database);
    await service.refresh();
    logger.i('LibraryService initialized at ${dbFile.path}');
    return service;
  }

  Future<void> addEntry(LibraryEntry entry) async {
    await _database.insert(
      'library_entries',
      {
        'id': entry.id,
        'url': entry.url,
        'title': entry.title,
        'artist': entry.artist,
        'durationMs': entry.durationMs,
        'filePath': entry.filePath,
        'formatLabel': entry.formatLabel,
        'createdAt': entry.createdAt.millisecondsSinceEpoch,
        'thumbnailPath': entry.thumbnailPath,
        'fileSize': entry.fileSize,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await refresh();
  }

  Future<List<LibraryEntry>> fetchAll() async {
    final rows = await _database.query(
      'library_entries',
      orderBy: 'createdAt DESC',
    );
    return rows.map(_mapRow).toList();
  }

  Future<List<LibraryEntry>> search(String query) async {
    final rows = await _database.query(
      'library_entries',
      where: 'title LIKE ? OR artist LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'createdAt DESC',
    );
    return rows.map(_mapRow).toList();
  }

  Future<void> remove(String id) async {
    await _database.delete(
      'library_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
    await refresh();
  }

  LibraryEntry _mapRow(Map<String, Object?> row) {
    return LibraryEntry(
      id: row['id']! as String,
      url: row['url']! as String,
      title: row['title']! as String,
      artist: row['artist']! as String,
      durationMs: row['durationMs']! as int,
      filePath: row['filePath']! as String,
      formatLabel: row['formatLabel']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['createdAt']! as int,
      ),
      thumbnailPath: row['thumbnailPath'] as String?,
      fileSize: row['fileSize'] as int?,
    );
  }

  @override
  void dispose() {
    _entriesController.close();
    _database.close();
    super.dispose();
  }
}
