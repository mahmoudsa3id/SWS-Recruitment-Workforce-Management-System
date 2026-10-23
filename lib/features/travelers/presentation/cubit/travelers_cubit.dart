import 'dart:typed_data';
import '../../../../core/data_sync/accounting_data_sync.dart';
import '../../domain/entities/traveler.dart';
import '../../domain/usecases/archive_traveler.dart';
import '../../domain/usecases/create_traveler.dart';
import '../../domain/usecases/delete_traveler.dart';
import '../../domain/usecases/list_travelers.dart';
import '../../domain/usecases/set_traveler_avatar.dart';

sealed class TravelersState {
  const TravelersState();
}

final class TravelersInitial extends TravelersState {
  const TravelersInitial();
}

final class TravelersLoading extends TravelersState {
  const TravelersLoading();
}

final class TravelersLoaded extends TravelersState {
  const TravelersLoaded(this.items);
  final List<Traveler> items;
}

final class TravelersFailure extends TravelersState {
  const TravelersFailure(this.message);
  final String message;
}

class TravelersCubit extends AccountingSyncCubit<TravelersState> {
  TravelersCubit(this._list, this._create, this._archive, this._delete, this._avatar)
    : super(const TravelersInitial(), listenToMonthChanges: true);

  final ListTravelers _list;
  final CreateTraveler _create;
  final ArchiveTraveler _archive;
  final DeleteTraveler _delete;
  final SetTravelerAvatar _avatar;
  String? lastCreatedTravelerId;
  String _query = '';

  @override
  Future<void> refreshAfterDataChange() => refresh();

  Future<void> load({String query = ''}) async {
    if (isClosed) return;
    _query = query;
    emit(const TravelersLoading());
    final result = await _list(query: query);
    // Do not emit if the route was disposed while the request was in flight.
    if (isClosed) return;
    result.fold(
      (failure) => emit(TravelersFailure(failure.message)),
      (items) => emit(TravelersLoaded(items)),
    );
  }

  Future<String?> create({
    required String fullName,
    required String phone,
    required double agreementTotal,
    String? salesPerson,
    String? country,
  }) async {
    final result = await _create(
      fullName: fullName,
      phone: phone,
      agreementTotal: agreementTotal,
      salesPerson: salesPerson,
      country: country,
    );
    return result.fold((failure) => failure.message, (traveler) {
      lastCreatedTravelerId = traveler.id;
      AccountingDataSync.notifyChanged();
      return null;
    });
  }

  Future<String?> setAvatarForTraveler({required String travelerId, required String fileName, required String mimeType, required Uint8List bytes}) async {
    final result = await _avatar(travelerId: travelerId, fileName: fileName, mimeType: mimeType, bytes: bytes);
    return result.fold((failure) => failure.message, (_) {
      AccountingDataSync.notifyChanged();
      return null;
    });
  }

  Future<String?> archive({
    required String travelerId,
    required String reason,
  }) async {
    final result = await _archive(travelerId: travelerId, reason: reason);
    return result.fold((failure) => failure.message, (_) {
      AccountingDataSync.notifyChanged();
      return null;
    });
  }

  Future<(String? error, bool filesPending)> deleteTraveler({
    required String travelerId,
    required String reason,
  }) async {
    final result = await _delete(travelerId: travelerId, reason: reason);
    return result.fold((failure) => (failure.message, false), (storageCleaned) {
      AccountingDataSync.notifyChanged();
      return (null, !storageCleaned);
    });
  }

  Future<void> refresh() => load(query: _query);
}
