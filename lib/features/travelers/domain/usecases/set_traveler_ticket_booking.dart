import '../../../../core/result.dart';
import '../traveler_repository.dart';

class SetTravelerTicketBooking {
  const SetTravelerTicketBooking(this.repository);
  final TravelerRepository repository;
  Future<Result<void>> call({required String travelerId, required String? type, required String? note}) =>
      repository.setTicketBooking(travelerId: travelerId, type: type, note: note);
}
