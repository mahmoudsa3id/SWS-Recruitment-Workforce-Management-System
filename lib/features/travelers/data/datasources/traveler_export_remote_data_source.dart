import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../documents/domain/entities/traveler_document.dart';

class TravelerExportRemoteDataSource {
  TravelerExportRemoteDataSource(this.client);
  final SupabaseClient client;
  static const bucket = 'sws-private-documents';

  Future<Uint8List> downloadDocument(TravelerDocument document) =>
      client.storage.from(bucket).download(document.storagePath);
}
