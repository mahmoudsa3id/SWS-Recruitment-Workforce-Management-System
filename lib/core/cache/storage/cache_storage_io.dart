import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'cache_storage.dart';

Future<CacheStorage> openCacheStorage() async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final database = await openDatabase(
    p.join(directory.path, 'sws_local_cache.db'),
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE cache_entries (
          cache_key TEXT PRIMARY KEY NOT NULL,
          cache_value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_cache_entries_updated_at ON cache_entries(updated_at)',
      );
    },
  );
  return _SqliteCacheStorage(database);
}

class _SqliteCacheStorage implements CacheStorage {
  _SqliteCacheStorage(this._database);
  final Database _database;

  @override
  Future<Map<String, String>> loadAll() async {
    final rows = await _database.query('cache_entries');
    return {
      for (final row in rows)
        row['cache_key']! as String: row['cache_value']! as String,
    };
  }

  @override
  Future<void> put(String key, String value) async {
    await _database.insert(
      'cache_entries',
      {
        'cache_key': key,
        'cache_value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String key) async {
    await _database.delete(
      'cache_entries',
      where: 'cache_key = ?',
      whereArgs: [key],
    );
  }

  @override
  Future<void> deleteByPrefix(String prefix) async {
    await _database.delete(
      'cache_entries',
      where: 'substr(cache_key, 1, ?) = ?',
      whereArgs: [prefix.length, prefix],
    );
  }

  @override
  Future<void> clear() async => _database.delete('cache_entries');

  @override
  Future<void> close() => _database.close();
}
