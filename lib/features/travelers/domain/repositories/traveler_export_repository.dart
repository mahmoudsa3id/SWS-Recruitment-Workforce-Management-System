import 'dart:typed_data';
import '../../../../core/result.dart';

abstract interface class TravelerExportRepository {
  Future<Result<Uint8List>> exportTravelerFile(String travelerId);
}
