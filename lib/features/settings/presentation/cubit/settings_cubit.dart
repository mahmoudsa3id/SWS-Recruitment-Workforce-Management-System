import '../../../../core/data_sync/accounting_data_sync.dart';
import '../../domain/entities/system_settings.dart';
import '../../domain/usecases/clear_local_cache.dart';
import '../../domain/usecases/load_system_settings.dart';

sealed class SettingsState {
  const SettingsState();
}

final class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

final class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

final class SettingsLoaded extends SettingsState {
  const SettingsLoaded(this.settings);
  final SystemSettings settings;
}

final class SettingsFailure extends SettingsState {
  const SettingsFailure(this.message);
  final String message;
}

class SettingsCubit extends AccountingSyncCubit<SettingsState> {
  SettingsCubit(this._load, this._clear) : super(const SettingsInitial());

  final LoadSystemSettings _load;
  final ClearLocalCache _clear;

  @override
  Future<void> refreshAfterDataChange() => load();

  Future<void> load() async {
    emit(const SettingsLoading());
    final result = await _load();
    result.fold(
      (failure) => emit(SettingsFailure(failure.message)),
      (settings) => emit(SettingsLoaded(settings)),
    );
  }

  Future<String?> clearCache() async {
    final result = await _clear();
    return result.fold((failure) => failure.message, (_) => null);
  }
}
