import 'cache_storage.dart';
import 'cache_storage_stub.dart'
    if (dart.library.io) 'cache_storage_io.dart'
    if (dart.library.html) 'cache_storage_web.dart' as platform;

Future<CacheStorage> openCacheStorage() => platform.openCacheStorage();
