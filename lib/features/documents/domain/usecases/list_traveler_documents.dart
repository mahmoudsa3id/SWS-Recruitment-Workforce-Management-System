import '../../../../core/result.dart';
import '../entities/traveler_document.dart';
import '../repositories/documents_repository.dart';

class ListTravelerDocuments {
  const ListTravelerDocuments(this.repository);
  final DocumentsRepository repository;
  Future<Result<List<TravelerDocument>>> call(String id) =>
      repository.listForTraveler(id);
}
