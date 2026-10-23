import '../../../../core/result.dart';
import '../repositories/traveler_repository.dart';

class ArchiveTraveler {
  const ArchiveTraveler(this.repository);
  final TravelerRepository repository;
  Future<Result<void>> call({
    required String travelerId,
    required String reason,
  }) => repository.archiveTraveler(travelerId: travelerId, reason: reason);
}
