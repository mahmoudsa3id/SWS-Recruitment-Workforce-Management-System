import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/printing/traveler_summary_pdf.dart';
import '../../../../core/result.dart';
import '../../../documents/domain/repositories/documents_repository.dart';
import '../../domain/repositories/traveler_export_repository.dart';
import '../../domain/traveler_repository.dart';
import '../datasources/traveler_export_remote_data_source.dart';

class TravelerExportRepositoryImpl implements TravelerExportRepository {
  TravelerExportRepositoryImpl(this.travelers, this.documents, this.remote);
  final TravelerRepository travelers;
  final DocumentsRepository documents;
  final TravelerExportRemoteDataSource remote;

  @override
  Future<Result<Uint8List>> exportTravelerFile(String travelerId) async {
    if (travelerId.trim().isEmpty) return const Left(ValidationFailure('ملف المسافر غير صالح.'));
    final profileResult = await travelers.profile(travelerId);
    return profileResult.fold<Future<Result<Uint8List>>>(
      (failure) async => Left(failure),
      (profile) async {
        final documentsResult = await documents.listForTraveler(travelerId);
        return documentsResult.fold<Future<Result<Uint8List>>>(
          (failure) async => Left(failure),
          (items) async {
            try {
              final archive = Archive();
              final summary = await TravelerSummaryPdf.build(profile);
              archive.addFile(ArchiveFile('00-ملخص-البيانات-والحساب.pdf', summary.length, summary));
              const order = ['الصورة والباسبور', 'التأشيرة', 'إثبات التاريخ', 'تذكرة الطيران', 'مستندات أخرى'];
              var fileIndex = 1;
              for (final type in order) {
                final matching = items.where((item) => item.type == type).toList()
                  ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                for (final item in matching) {
                  final bytes = await remote.downloadDocument(item);
                  final safeName = item.fileName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
                  final path = '${fileIndex.toString().padLeft(3, '0')}-$type/$safeName';
                  archive.addFile(ArchiveFile(path, bytes.length, bytes));
                  fileIndex++;
                }
              }
              final encoded = ZipEncoder().encode(archive);
              if (encoded == null || encoded.isEmpty) {
                return const Left(ServerFailure('تعذر إنشاء ملف ZIP للمسافر.'));
              }
              return Right(Uint8List.fromList(encoded));
            } catch (error) {
              return Left(ServerFailure('تعذر إنشاء ملف المسافر. تحقق من اتصالك وإمكانية الوصول إلى جميع المستندات.', cause: error));
            }
          },
        );
      },
    );
  }
}
