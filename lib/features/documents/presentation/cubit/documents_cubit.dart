import 'dart:typed_data';
import '../../../../core/data_sync/accounting_data_sync.dart';
import '../../domain/entities/traveler_document.dart';
import '../../domain/usecases/list_traveler_documents.dart';
import '../../domain/usecases/upload_traveler_document.dart';
import '../../domain/usecases/create_document_link.dart';
import '../../domain/usecases/download_traveler_document.dart';
import '../../domain/usecases/delete_traveler_document.dart';

sealed class DocumentsState {
  const DocumentsState();
}

final class DocumentsInitial extends DocumentsState {
  const DocumentsInitial();
}

final class DocumentsLoading extends DocumentsState {
  const DocumentsLoading();
}

final class DocumentsLoaded extends DocumentsState {
  const DocumentsLoaded(this.items);
  final List<TravelerDocument> items;
}

final class DocumentsFailure extends DocumentsState {
  const DocumentsFailure(this.message);
  final String message;
}

class DocumentsCubit extends AccountingSyncCubit<DocumentsState> {
  DocumentsCubit(
    this._list,
    this._upload,
    this._link,
    this._delete,
    this._download,
  ) : super(const DocumentsInitial());
  final ListTravelerDocuments _list;
  final UploadTravelerDocument _upload;
  final CreateDocumentLink _link;
  final DeleteTravelerDocument _delete;
  final DownloadTravelerDocument _download;
  String? currentTravelerId;

  @override
  Future<void> refreshAfterDataChange() async {
    final travelerId = currentTravelerId;
    if (travelerId != null) await load(travelerId);
  }

  Future<void> load(String id) async {
    if (isClosed) return;
    currentTravelerId = id;
    emit(const DocumentsLoading());
    final result = await _list(id);
    // A request may finish after the traveler profile route has been closed.
    if (isClosed) return;
    result.fold(
      (failure) => emit(DocumentsFailure(failure.message)),
      (items) => emit(DocumentsLoaded(items)),
    );
  }

  Future<String?> upload({
    required String travelerId,
    required String type,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final r = await _upload(
      travelerId: travelerId,
      type: type,
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
    );
    return r.fold((f) => f.message, (_) {
      AccountingDataSync.notifyChanged();
      return null;
    });
  }

  Future<Uint8List?> download(String path) async {
    final r = await _download(path);
    return r.fold((_) => null, (v) => v);
  }

  Future<String?> delete({
    required String documentId,
    required String storagePath,
    required String reason,
  }) async {
    final r = await _delete(
      documentId: documentId,
      storagePath: storagePath,
      reason: reason,
    );
    return r.fold((f) => f.message, (_) {
      AccountingDataSync.notifyChanged();
      return null;
    });
  }

  Future<String?> link(String path) async {
    final r = await _link(path);
    return r.fold((f) => f.message, (v) => v);
  }
}
