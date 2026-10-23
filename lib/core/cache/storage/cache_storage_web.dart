import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'cache_storage.dart';

/// SQLite/WASM adapter for Flutter Web. The database is persisted in the
/// browser's IndexedDB by sqflite_common_ffi_web. Run its setup command to
/// place sqlite3.wasm and sqflite_sw.js in the web/ directory.
Future<CacheStorage> openCacheStorage() async {
  final database = await databaseFactoryFfiWeb.openDatabase(
    'sws_local_cache.db',
  );
  await database.execute('''
    CREATE TABLE IF NOT EXISTS cache_entries (
      cache_key TEXT PRIMARY KEY NOT NULL,
      cache_value TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await database.execute(
    'CREATE INDEX IF NOT EXISTS idx_cache_entries_updated_at ON cache_entries(updated_at)',
  );
  return _WebSqliteCacheStorage(database);
}

class _WebSqliteCacheStorage implements CacheStorage {
  _WebSqliteCacheStorage(this._database);
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
