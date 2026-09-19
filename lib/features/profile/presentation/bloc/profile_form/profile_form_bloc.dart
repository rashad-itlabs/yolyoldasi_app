import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/network/upload_file.dart';
import '../../../../cities/domain/entities/city.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/user_enums.dart';
import '../../../domain/repositories/user_repository.dart';

part 'profile_form_event.dart';
part 'profile_form_state.dart';

/// Backs both the first-run profile setup and later edits.
///
/// One bloc for both because they are the same `PATCH /me` against the same
/// fields; the only difference is whether the router got here because
/// `full_name` was still empty.
class ProfileFormBloc extends Bloc<ProfileFormEvent, ProfileFormState> {
  ProfileFormBloc({required UserRepository users})
    : _users = users,
      super(const ProfileFormState()) {
    on<ProfileFormStarted>(_onStarted);
    on<ProfileFullNameChanged>(_onFullNameChanged);
    on<ProfileAboutChanged>(_onAboutChanged);
    on<ProfileGenderChanged>(_onGenderChanged);
    on<ProfileBirthYearChanged>(_onBirthYearChanged);
    on<ProfileCityChanged>(_onCityChanged);
    on<ProfilePhotoPicked>(_onPhotoPicked);
    on<ProfileFormSubmitted>(_onSubmitted);
    on<ProfileFormFailureCleared>(_onFailureCleared);
  }

  final UserRepository _users;

  void _onStarted(ProfileFormStarted event, Emitter<ProfileFormState> emit) {
    final user = event.user;
    emit(
      user == null ? const ProfileFormState() : ProfileFormState.fromUser(user),
    );
  }

  void _onFullNameChanged(
    ProfileFullNameChanged event,
    Emitter<ProfileFormState> emit,
  ) {
    emit(state.copyWith(fullName: event.value, failure: () => null));
  }

  void _onAboutChanged(
    ProfileAboutChanged event,
    Emitter<ProfileFormState> emit,
  ) {
    emit(state.copyWith(about: event.value, failure: () => null));
  }

  void _onGenderChanged(
    ProfileGenderChanged event,
    Emitter<ProfileFormState> emit,
  ) {
    emit(state.copyWith(gender: event.value, failure: () => null));
  }

  void _onBirthYearChanged(
    ProfileBirthYearChanged event,
    Emitter<ProfileFormState> emit,
  ) {
    emit(state.copyWith(birthYear: () => event.value, failure: () => null));
  }

  void _onCityChanged(
    ProfileCityChanged event,
    Emitter<ProfileFormState> emit,
  ) {
    emit(state.copyWith(city: () => event.city, failure: () => null));
  }

  Future<void> _onPhotoPicked(
    ProfilePhotoPicked event,
    Emitter<ProfileFormState> emit,
  ) async {
    if (!event.photo.fitsWithin(AppRules.maxPhotoBytes)) {
      emit(
        state.copyWith(
          photoStatus: ActionStatus.failure,
          failure: () =>
              const ValidationFailure(FailureCode.invalidInput, field: 'photo'),
        ),
      );
      return;
    }

    emit(
      state.copyWith(photoStatus: ActionStatus.inProgress, failure: () => null),
    );

    final result = await _users.uploadPhoto(event.photo);
    switch (result) {
      case Ok(:final value):
        // `POST /me/photo` answers with the whole profile, so the session can
        // be updated from here without a follow-up `GET /me`.
        emit(
          state.copyWith(
            photoStatus: ActionStatus.success,
            photoUrl: () => value.photoUrl,
            savedUser: () => value,
            original: () => value,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            photoStatus: ActionStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }

  Future<void> _onSubmitted(
    ProfileFormSubmitted event,
    Emitter<ProfileFormState> emit,
  ) async {
    if (!state.isValid || state.status.isBusy) return;

    emit(
      state.copyWith(
        status: ActionStatus.inProgress,
        failure: () => null,
        savedUser: () => null,
      ),
    );

    // Only what changed is sent — `PATCH /me` leaves omitted fields alone, and
    // the wrapped arguments are how a cleared field is told apart from an
    // untouched one.
    final original = state._original;
    final result = await _users.updateProfile(
      fullName: _changed(state.fullName.trim(), original?.fullName.trim())
          ? state.fullName.trim()
          : null,
      about: _changed(state.about.trim(), original?.about.trim())
          ? () => state.about.trim()
          : null,
      gender: _changed(state.gender, original?.gender) ? state.gender : null,
      birthYear: _changed(state.birthYear, original?.birthYear)
          ? () => state.birthYear
          : null,
      cityId: _changed(state.city?.id, original?.city?.id)
          ? () => state.city?.id
          : null,
    );

    switch (result) {
      case Ok(:final value):
        emit(
          ProfileFormState.fromUser(
            value,
          ).copyWith(status: ActionStatus.success, savedUser: () => value),
        );
      case Err(:final failure):
        emit(
          state.copyWith(status: ActionStatus.failure, failure: () => failure),
        );
    }
  }

  /// `true` when the field differs from what the form was seeded with. A form
  /// with no original (first-run setup) sends everything the user filled in.
  static bool _changed<T>(T current, T? original) => current != original;

  void _onFailureCleared(
    ProfileFormFailureCleared event,
    Emitter<ProfileFormState> emit,
  ) {
    emit(
      state.copyWith(
        failure: () => null,
        status: ActionStatus.idle,
        photoStatus: ActionStatus.idle,
      ),
    );
  }
}
