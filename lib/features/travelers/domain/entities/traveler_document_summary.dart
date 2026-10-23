class TravelerDocumentSummary {
  const TravelerDocumentSummary({required this.id, required this.type, required this.fileName, required this.storagePath, this.mimeType, this.fileSize});
  final String id, type, fileName, storagePath;
  final String? mimeType;
  final int? fileSize;
}
