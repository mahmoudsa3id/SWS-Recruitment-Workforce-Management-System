import 'cache_storage.dart';

Future<CacheStorage> openCacheStorage() async => _UnsupportedCacheStorage();

class _UnsupportedCacheStorage implements CacheStorage {
  @override
  Future<Map<String, String>> loadAll() async => <String, String>{};
  @override
  Future<void> put(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteByPrefix(String prefix) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> close() async {}
}
