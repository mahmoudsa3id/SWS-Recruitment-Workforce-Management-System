import '../../../../core/result.dart';
import '../entities/traveler_profile.dart';
import '../repositories/traveler_repository.dart';

class LoadTravelerProfile {
  const LoadTravelerProfile(this.repository);
  final TravelerRepository repository;
  Future<Result<TravelerProfile>> call(String id) => repository.profile(id);
}
