import '../../../../core/result.dart';
import '../repositories/documents_repository.dart';

class DeleteTravelerDocument {
  const DeleteTravelerDocument(this.repository);
  final DocumentsRepository repository;
  Future<Result<void>> call({
    required String documentId,
    required String storagePath,
    required String reason,
  }) => repository.deleteDocument(
    documentId: documentId,
    storagePath: storagePath,
    reason: reason,
  );
}
