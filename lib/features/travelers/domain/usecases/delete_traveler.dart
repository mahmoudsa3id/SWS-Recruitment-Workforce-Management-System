import '../../../../core/result.dart';
import '../traveler_repository.dart';

class DeleteTraveler {
  const DeleteTraveler(this.repository);
  final TravelerRepository repository;

  Future<Result<bool>> call({required String travelerId, required String reason}) =>
      repository.deleteTraveler(travelerId: travelerId, reason: reason);
}
