import 'dart:typed_data';
import '../../../../core/data_sync/accounting_data_sync.dart';
import '../../domain/entities/traveler_profile.dart';
import '../../domain/usecases/add_payment.dart';
import '../../domain/usecases/load_profile.dart';
import '../../domain/usecases/set_traveler_stage.dart';
import '../../domain/usecases/update_traveler.dart';
import '../../domain/usecases/set_traveler_ticket_booking.dart';
import '../../domain/usecases/set_traveler_avatar.dart';

sealed class TravelerProfileState {
  const TravelerProfileState();
}

final class TravelerProfileInitial extends TravelerProfileState {
  const TravelerProfileInitial();
}

final class TravelerProfileLoading extends TravelerProfileState {
  const TravelerProfileLoading();
}

final class TravelerProfileLoaded extends TravelerProfileState {
  const TravelerProfileLoaded(this.profile);
  final TravelerProfile profile;
}

final class TravelerProfileFailure extends TravelerProfileState {
  const TravelerProfileFailure(this.message);
  final String message;
}

class TravelerProfileCubit extends AccountingSyncCubit<TravelerProfileState> {
  TravelerProfileCubit(this._load, this._payment, this._stage, this._update, this._ticketBooking, this._avatar)
    : super(const TravelerProfileInitial());

  final LoadTravelerProfile _load;
  final AddTravelerPayment _payment;
  final SetTravelerStage _stage;
  final UpdateTraveler _update;
  final SetTravelerTicketBooking _ticketBooking;
  final SetTravelerAvatar _avatar;
  String? _id;

  @override
  Future<void> refreshAfterDataChange() async {
    final id = _id;
    if (id != null) await load(id);
  }

  Future<void> load(String id) async {
    if (isClosed) return;
    _id = id;
    emit(const TravelerProfileLoading());
    final result = await _load(id);
    // Profile loads can finish after the user has left the route.
    if (isClosed) return;
    result.fold(
      (failure) => emit(TravelerProfileFailure(failure.message)),
      (profile) => emit(TravelerProfileLoaded(profile)),
    );
  }

  Future<String?> addPayment({
    required String travelerId,
    required double amount,
    required String method,
    required String note,
  }) async {
    final result = await _payment(
      travelerId: travelerId,
      amount: amount,
      method: method,
      note: note,
    );
    String? paymentError;
    await result.fold((failure) async { paymentError = failure.message; }, (_) async {
      final current = state;
      final isFirstPayment = current is TravelerProfileLoaded && current.profile.netPaid <= 0;
      if (isFirstPayment) {
        final stageResult = await _stage(travelerId: travelerId, stage: 'submitted', value: true);
        stageResult.fold((failure) { paymentError = 'تم تسجيل الدفعة، لكن تعذر تحديث المرحلة إلى «قدم»: ${failure.message}'; }, (_) {});
      }
      AccountingDataSync.notifyChanged();
      await load(travelerId);
    });
    return paymentError;
  }

  Future<String?> setTicketBooking({required String? type, required String? note}) async {
    final id = _id;
    if (id == null) return 'ملف المسافر غير محمّل.';
    final result = await _ticketBooking(travelerId: id, type: type, note: note);
    return result.fold((failure) => failure.message, (_) {
      AccountingDataSync.notifyChanged();
      load(id);
      return null;
    });
  }

  Future<String?> setAvatar({required String fileName, required String mimeType, required Uint8List bytes}) async {
    final id = _id;
    if (id == null) return 'ملف المسافر غير محمّل.';
    final result = await _avatar(travelerId: id, fileName: fileName, mimeType: mimeType, bytes: bytes);
    return result.fold((failure) => failure.message, (_) {
      AccountingDataSync.notifyChanged();
      load(id);
      return null;
    });
  }

  Future<String?> updateTraveler({
    required String fullName,
    required String phone,
    required double agreementTotal,
    String? salesPerson,
    String? country,
  }) async {
    final id = _id;
    if (id == null) return 'ملف المسافر غير محمّل.';
    final result = await _update(
      travelerId: id,
      fullName: fullName,
      phone: phone,
      agreementTotal: agreementTotal,
      salesPerson: salesPerson,
      country: country,
    );
    return result.fold((failure) => failure.message, (_) {
      AccountingDataSync.notifyChanged();
      return null;
    });
  }

  Future<String?> setStage({required String stage, required bool value}) async {
    final id = _id;
    if (id == null) return 'ملف المسافر غير محمّل.';
    final result = await _stage(travelerId: id, stage: stage, value: value);
    return result.fold((failure) => failure.message, (_) {
      AccountingDataSync.notifyChanged();
      load(id);
      return null;
    });
  }
}
