import 'dart:typed_data';
import '../../../../core/result.dart';
import '../repositories/documents_repository.dart';

class DownloadTravelerDocument {
  const DownloadTravelerDocument(this.repository);
  final DocumentsRepository repository;
  Future<Result<Uint8List>> call(String storagePath) => repository.download(storagePath);
}
