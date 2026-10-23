import 'dart:async';
import 'dart:convert';

import 'storage/cache_storage.dart';
import 'storage/cache_storage_factory.dart';

/// TTL cache for non-authoritative UI snapshots.
///
/// Supabase remains the source of truth. This cache never authorizes a user and
/// never queues or commits financial writes while offline. SQLite is used on
/// Android/Windows/macOS/Linux; the browser uses IndexedDB because native
/// SQLite is not directly available in a normal Flutter Web runtime.
class LocalCache {
  LocalCache._(this._storage, this._values);

  static const _prefix = 'sws_cache_v1_';
  final CacheStorage _storage;
  final Map<String, String> _values;

  static Future<LocalCache> create() async {
    final storage = await openCacheStorage();
    try {
      final values = await storage.loadAll();
      return LocalCache._(storage, values);
    } catch (_) {
      await storage.close();
      rethrow;
    }
  }

  Future<void> writeJson(
    String key,
    Object value, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final physicalKey = '$_prefix$key';
    final payload = <String, Object>{
      'expiresAt': DateTime.now().add(ttl).millisecondsSinceEpoch,
      'data': value,
    };
    final encoded = jsonEncode(payload);
    await _storage.put(physicalKey, encoded);
    _values[physicalKey] = encoded;
  }

  /// Synchronous reads are served from the map loaded during startup.
  /// Persistent writes still go to SQLite/IndexedDB before this cache is updated.
  Object? readJson(String key) {
    final physicalKey = '$_prefix$key';
    final raw = _values[physicalKey];
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        unawaited(remove(key));
        return null;
      }
      final expires = decoded['expiresAt'];
      if (expires is! num ||
          DateTime.now().millisecondsSinceEpoch >= expires) {
        unawaited(remove(key));
        return null;
      }
      return decoded['data'];
    } on FormatException {
      unawaited(remove(key));
      return null;
    }
  }

  Future<void> remove(String key) async {
    final physicalKey = '$_prefix$key';
    _values.remove(physicalKey);
    await _storage.delete(physicalKey);
  }

  /// Removes cache entries whose logical keys start with [keyPrefix].
  Future<void> removeKeysStartingWith(String keyPrefix) async {
    final physicalPrefix = '$_prefix$keyPrefix';
    final keys = _values.keys
        .where((key) => key.startsWith(physicalPrefix))
        .toList(growable: false);
    for (final key in keys) {
      _values.remove(key);
    }
    await _storage.deleteByPrefix(physicalPrefix);
  }

  /// Backward-compatible prefix invalidation used by repositories.
  Future<void> removePrefix(String keyPrefix) =>
      removeKeysStartingWith(keyPrefix);

  /// Clears only this app's cached snapshots, never business records.
  Future<void> clearAll() async {
    final keys = _values.keys
        .where((key) => key.startsWith(_prefix))
        .toList(growable: false);
    for (final key in keys) {
      _values.remove(key);
    }
    await _storage.deleteByPrefix(_prefix);
  }

  Future<void> close() => _storage.close();
}
