class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.entityType,
    required this.createdAt,
    this.entityId,
    this.reason,
    this.beforeData,
    this.afterData,
    this.actorId,
  });
  final int id;
  final String action, entityType;
  final DateTime createdAt;
  final String? entityId, reason, actorId;
  final Map<String, dynamic>? beforeData, afterData;
}
