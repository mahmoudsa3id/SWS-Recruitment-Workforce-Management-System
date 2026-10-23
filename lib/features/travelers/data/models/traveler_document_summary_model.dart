import '../../domain/entities/traveler_document_summary.dart';
class TravelerDocumentSummaryModel extends TravelerDocumentSummary {
  const TravelerDocumentSummaryModel({required super.id, required super.type, required super.fileName, required super.storagePath, super.mimeType, super.fileSize});
  factory TravelerDocumentSummaryModel.fromMap(Map<String, dynamic> map) => TravelerDocumentSummaryModel(id: '${map['id'] ?? ''}', type: '${map['document_type'] ?? 'مستندات أخرى'}', fileName: '${map['file_name'] ?? 'ملف'}', storagePath: '${map['storage_path'] ?? ''}', mimeType: map['mime_type']?.toString(), fileSize: map['file_size'] is num ? (map['file_size'] as num).toInt() : int.tryParse('${map['file_size']}'));
}
