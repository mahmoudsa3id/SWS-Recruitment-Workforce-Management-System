import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result.dart';
import '../../domain/entities/traveler_document.dart';
import '../../domain/repositories/documents_repository.dart';
import '../datasources/documents_remote_data_source.dart';
import '../models/traveler_document_model.dart';

class DocumentsRepositoryImpl implements DocumentsRepository {
  DocumentsRepositoryImpl(this.remote);
  final DocumentsRemoteDataSource remote;
  static const _types = {
    'الصورة والباسبور',
    'التأشيرة',
    'إثبات التاريخ',
    'تذكرة الطيران',
    'مستندات أخرى',
  };
  @override
  Future<Result<List<TravelerDocument>>> listForTraveler(String id) async {
    if (id.trim().isEmpty) {
      return const Left(ValidationFailure('يجب تحديد المسافر.'));
    }
    try {
      return Right(
        (await remote.list(
          id,
        )).map(TravelerDocumentModel.fromMap).toList(growable: false),
      );
    } catch (e) {
      return Left(ServerFailure('تعذر تحميل مستندات المسافر.', cause: e));
    }
  }

  @override
  Future<Result<String>> upload({
    required String travelerId,
    required String type,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (travelerId.trim().isEmpty) {
      return const Left(ValidationFailure('يجب تحديد المسافر.'));
    }
    if (!_types.contains(type)) {
      return const Left(ValidationFailure('نوع المستند غير مدعوم.'));
    }
    if (fileName.trim().isEmpty || bytes.isEmpty) {
      return const Left(ValidationFailure('الملف فارغ أو اسمه غير صحيح.'));
    }
    if (bytes.length > 15 * 1024 * 1024) {
      return const Left(
        ValidationFailure('الحد الأقصى لحجم الملف 15 ميجابايت.'),
      );
    }
    if (!{
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/webp',
    }.contains(mimeType)) {
      return const Left(
        ValidationFailure('يسمح بملفات PDF وJPEG وPNG وWebP فقط.'),
      );
    }
    try {
      return Right(
        await remote.upload(
          travelerId: travelerId,
          type: type,
          fileName: fileName,
          mimeType: mimeType,
          bytes: bytes,
        ),
      );
    } catch (e) {
      return Left(
        ServerFailure('تعذر رفع المستند أو تسجيل بياناته.', cause: e),
      );
    }
  }

  @override
  Future<Result<Uint8List>> download(String path) async {
    if (path.trim().isEmpty) {
      return const Left(ValidationFailure('مسار المستند غير صالح.'));
    }
    try {
      return Right(await remote.download(path));
    } catch (e) {
      return Left(ServerFailure('تعذر تنزيل المستند.', cause: e));
    }
  }

  @override
  Future<Result<void>> deleteDocument({
    required String documentId,
    required String storagePath,
    required String reason,
  }) async {
    if (documentId.trim().isEmpty ||
        storagePath.trim().isEmpty ||
        reason.trim().isEmpty) {
      return const Left(ValidationFailure('معرّف المستند وسبب الحذف مطلوبان.'));
    }
    try {
      await remote.deleteDocument(documentId, storagePath, reason);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('تعذر حذف المستند.', cause: e));
    }
  }

  @override
  Future<Result<String>> createSignedUrl(String path) async {
    if (path.trim().isEmpty) {
      return const Left(ValidationFailure('مسار المستند غير صالح.'));
    }
    try {
      return Right(await remote.signedUrl(path));
    } catch (e) {
      return Left(ServerFailure('تعذر إنشاء رابط تنزيل مؤقت.', cause: e));
    }
  }
}
