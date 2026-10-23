/// Low-level persistent storage used by [LocalCache].
/// The IO implementation uses SQLite; the web implementation uses IndexedDB
/// because browsers cannot use the native SQLite driver directly.
abstract interface class CacheStorage {
  Future<Map<String, String>> loadAll();
  Future<void> put(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteByPrefix(String prefix);
  Future<void> clear();
  Future<void> close();
}
