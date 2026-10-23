class TravelerDocument {
  const TravelerDocument({
    required this.id,
    required this.travelerId,
    required this.type,
    required this.fileName,
    required this.storagePath,
    required this.createdAt,
    this.mimeType,
    this.fileSize,
  });
  final String id, travelerId, type, fileName, storagePath;
  final DateTime createdAt;
  final String? mimeType;
  final int? fileSize;
}
