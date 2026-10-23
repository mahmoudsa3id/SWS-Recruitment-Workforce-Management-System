import '../../domain/entities/traveler_document.dart';

class TravelerDocumentModel extends TravelerDocument {
  const TravelerDocumentModel({
    required super.id,
    required super.travelerId,
    required super.type,
    required super.fileName,
    required super.storagePath,
    required super.createdAt,
    super.mimeType,
    super.fileSize,
  });
  factory TravelerDocumentModel.fromMap(Map<String, dynamic> m) =>
      TravelerDocumentModel(
        id: '${m['id'] ?? ''}',
        travelerId: '${m['traveler_id'] ?? ''}',
        type: '${m['document_type'] ?? 'مستندات أخرى'}',
        fileName: '${m['file_name'] ?? 'ملف'}',
        storagePath: '${m['storage_path'] ?? ''}',
        createdAt:
            DateTime.tryParse('${m['created_at'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        mimeType: m['mime_type']?.toString(),
        fileSize: m['file_size'] is num
            ? (m['file_size'] as num).toInt()
            : int.tryParse('${m['file_size']}'),
      );
}
