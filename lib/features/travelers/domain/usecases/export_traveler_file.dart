import 'dart:typed_data';
import '../../../../core/result.dart';
import '../repositories/traveler_export_repository.dart';

class ExportTravelerFile {
  const ExportTravelerFile(this.repository);
  final TravelerExportRepository repository;

  Future<Result<Uint8List>> call(String travelerId) =>
      repository.exportTravelerFile(travelerId);
}
