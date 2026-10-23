import 'dart:typed_data';
import '../../../../core/result.dart';
import '../traveler_repository.dart';

class SetTravelerAvatar {
  const SetTravelerAvatar(this.repository);
  final TravelerRepository repository;
  Future<Result<void>> call({required String travelerId, required String fileName, required String mimeType, required Uint8List bytes}) =>
      repository.setAvatar(travelerId: travelerId, fileName: fileName, mimeType: mimeType, bytes: bytes);
}
