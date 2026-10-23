import '../../domain/entities/system_settings.dart';

class SystemSettingsModel extends SystemSettings {
  const SystemSettingsModel({
    required super.appName,
    required super.language,
    required super.signedInEmail,
    required super.cacheNamespace,
  });
  factory SystemSettingsModel.fromMap(Map<String, dynamic> m) =>
      SystemSettingsModel(
        appName: '${m['app_name'] ?? 'SWS'}',
        language: '${m['language'] ?? 'العربية (RTL)'}',
        signedInEmail: '${m['signed_in_email'] ?? '—'}',
        cacheNamespace: '${m['cache_namespace'] ?? 'sws_cache_v1_'}',
      );
}
