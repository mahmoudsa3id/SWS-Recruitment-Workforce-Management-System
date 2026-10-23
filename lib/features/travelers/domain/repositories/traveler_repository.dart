import 'dart:typed_data';
import '../../../../core/result.dart';
import '../entities/traveler.dart';
import '../entities/traveler_profile.dart';

abstract interface class TravelerRepository {
  Future<Result<List<Traveler>>> list({String query = ''});
  Future<Result<Traveler>> create({
    required String fullName,
    required String phone,
    required double agreementTotal,
    String? salesPerson,
    String? country,
  });
  Future<Result<Traveler>> updateTraveler({
    required String travelerId,
    required String fullName,
    required String phone,
    required double agreementTotal,
    String? salesPerson,
    String? country,
  });
  Future<Result<TravelerProfile>> profile(String id);
  Future<Result<void>> addPayment({
    required String travelerId,
    required double amount,
    required String method,
    required String note,
  });
  Future<Result<void>> setStage({
    required String travelerId,
    required String stage,
    required bool value,
  });
  Future<Result<void>> setTicketBooking({
    required String travelerId,
    required String? type,
    required String? note,
  });
  Future<Result<void>> setAvatar({
    required String travelerId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  });
  Future<Result<void>> archiveTraveler({
    required String travelerId,
    required String reason,
  });
  Future<Result<bool>> deleteTraveler({
    required String travelerId,
    required String reason,
  });
}
