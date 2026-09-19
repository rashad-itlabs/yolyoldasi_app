import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/network/upload_file.dart';
import '../../../domain/entities/driver_profile.dart';
import '../../../domain/entities/user_enums.dart';
import '../../../domain/repositories/driver_repository.dart';

part 'driver_profile_event.dart';
part 'driver_profile_state.dart';

/// Driver verification: the four documents and the publish gate they open.
///
/// Provided above the shell rather than per screen, because the publish tab's
/// enabled state depends on it as much as the documents screen does.
class DriverProfileBloc extends Bloc<DriverProfileEvent, DriverProfileState> {
  DriverProfileBloc({required DriverRepository drivers})
    : _drivers = drivers,
      super(const DriverProfileState()) {
    on<DriverProfileRequested>(_onRequested);
    on<DriverDocumentUploaded>(_onDocumentUploaded);
    on<DriverInstantBookingDefaultChanged>(_onInstantBookingDefaultChanged);
    on<DriverProfileFailureCleared>(_onFailureCleared);
  }

  final DriverRepository _drivers;

  Future<void> _onRequested(
    DriverProfileRequested event,
    Emitter<DriverProfileState> emit,
  ) async {
    if (state.status.isBusy) return;
    if (state.status.isSuccess && !event.force) return;

    final hasData = state.profile != null;
    emit(
      state.copyWith(
        status: hasData ? DataStatus.refreshing : DataStatus.loading,
        failure: () => null,
      ),
    );

    final result = await _drivers.profile();
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: DataStatus.success, profile: () => value));
      case Err(:final failure):
        // An account that has never been a driver may well 404 here; that is
        // not an error state, it is the empty one.
        if (failure is NotFoundFailure) {
          emit(
            state.copyWith(
              status: DataStatus.success,
              profile: () => DriverProfile.initial,
            ),
          );
          return;
        }
        emit(
          state.copyWith(
            status: hasData ? DataStatus.success : DataStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }

  Future<void> _onDocumentUploaded(
    DriverDocumentUploaded event,
    Emitter<DriverProfileState> emit,
  ) async {
    if (state.uploadStatus.isInProgress) return;

    final oversized =
        !event.file.fitsWithin(AppRules.maxDocumentBytes) ||
        !(event.backFile?.fitsWithin(AppRules.maxDocumentBytes) ?? true);
    if (oversized) {
      emit(
        state.copyWith(
          uploadingType: () => event.type,
          uploadStatus: ActionStatus.failure,
          failure: () =>
              const ValidationFailure(FailureCode.invalidInput, field: 'file'),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        uploadingType: () => event.type,
        uploadStatus: ActionStatus.inProgress,
        failure: () => null,
      ),
    );

    final result = await _drivers.uploadDocument(
      type: event.type,
      file: event.file,
      backFile: event.backFile,
    );

    switch (result) {
      case Ok(:final value):
        // The repository already re-read the profile, so the recomputed
        // aggregate status lands with the document.
        emit(
          state.copyWith(
            uploadStatus: ActionStatus.success,
            uploadingType: () => null,
            status: DataStatus.success,
            profile: () => value,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            uploadStatus: ActionStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }

  Future<void> _onInstantBookingDefaultChanged(
    DriverInstantBookingDefaultChanged event,
    Emitter<DriverProfileState> emit,
  ) async {
    final current = state.profile;
    if (current == null || current.instantBookingDefault == event.value) return;

    // Optimistic: a switch that lags behind the finger feels broken.
    emit(
      state.copyWith(
        profile: () => current.copyWith(instantBookingDefault: event.value),
      ),
    );

    final result = await _drivers.setInstantBookingDefault(event.value);
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(profile: () => value));
      case Err(:final failure):
        emit(state.copyWith(profile: () => current, failure: () => failure));
    }
  }

  void _onFailureCleared(
    DriverProfileFailureCleared event,
    Emitter<DriverProfileState> emit,
  ) {
    emit(
      state.copyWith(
        failure: () => null,
        uploadStatus: ActionStatus.idle,
        uploadingType: () => null,
      ),
    );
  }
}
