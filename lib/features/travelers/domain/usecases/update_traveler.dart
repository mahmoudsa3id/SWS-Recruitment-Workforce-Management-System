import '../../../../core/result.dart';
import '../entities/traveler.dart';
import '../repositories/traveler_repository.dart';

class UpdateTraveler {
  const UpdateTraveler(this.repository);
  final TravelerRepository repository;
  Future<Result<Traveler>> call({
    required String travelerId,
    required String fullName,
    required String phone,
    required double agreementTotal,
    String? salesPerson,
    String? country,
  }) => repository.updateTraveler(
    travelerId: travelerId,
    fullName: fullName,
    phone: phone,
    agreementTotal: agreementTotal,
    salesPerson: salesPerson,
    country: country,
  );
}
