part of 'profile_form_bloc.dart';

class ProfileFormState extends Equatable {
  const ProfileFormState({
    this.fullName = '',
    this.about = '',
    this.gender = Gender.unspecified,
    this.birthYear,
    this.city,
    this.photoUrl,
    this.status = ActionStatus.idle,
    this.photoStatus = ActionStatus.idle,
    this.savedUser,
    this.failure,
    AppUser? original,
  }) : _original = original;

  final String fullName;
  final String about;
  final Gender gender;
  final int? birthYear;
  final City? city;

  /// Kept separate from the form fields: the photo is saved by its own
  /// endpoint the moment it is picked, so it is never part of the PATCH.
  final String? photoUrl;

  final ActionStatus status;
  final ActionStatus photoStatus;

  /// The profile `PATCH /me` returned. The page forwards it to [SessionBloc].
  final AppUser? savedUser;

  final Failure? failure;

  /// What the form was seeded with, so only genuine edits are sent.
  final AppUser? _original;

  bool get isNameValid =>
      fullName.trim().length >= AppRules.minFullNameLength &&
      fullName.trim().length <= AppRules.maxFullNameLength;

  bool get isAboutValid => about.length <= AppRules.maxAboutLength;

  bool get isBirthYearValid {
    final year = birthYear;
    if (year == null) return true;
    return year >= AppRules.minBirthYear && year <= AppRules.maxBirthYear;
  }

  bool get isValid => isNameValid && isAboutValid && isBirthYearValid;

  /// Whether anything differs from what was loaded. A submit with no changes
  /// would be a wasted round trip and, worse, an enabled button that does
  /// nothing visible.
  bool get isDirty {
    final original = _original;
    if (original == null) return isValid;
    return fullName.trim() != original.fullName.trim() ||
        about.trim() != original.about.trim() ||
        gender != original.gender ||
        birthYear != original.birthYear ||
        city?.id != original.city?.id;
  }

  bool get canSubmit => isValid && isDirty && !status.isBusy;

  /// A field-level message from Laravel's `errors` map, when the last failure
  /// carried one.
  String? errorFor(String field) {
    final current = failure;
    return current is ValidationFailure ? current.messageFor(field) : null;
  }

  ProfileFormState copyWith({
    String? fullName,
    String? about,
    Gender? gender,
    int? Function()? birthYear,
    City? Function()? city,
    String? Function()? photoUrl,
    ActionStatus? status,
    ActionStatus? photoStatus,
    AppUser? Function()? savedUser,
    Failure? Function()? failure,
    AppUser? Function()? original,
  }) {
    return ProfileFormState(
      fullName: fullName ?? this.fullName,
      about: about ?? this.about,
      gender: gender ?? this.gender,
      birthYear: birthYear != null ? birthYear() : this.birthYear,
      city: city != null ? city() : this.city,
      photoUrl: photoUrl != null ? photoUrl() : this.photoUrl,
      status: status ?? this.status,
      photoStatus: photoStatus ?? this.photoStatus,
      savedUser: savedUser != null ? savedUser() : this.savedUser,
      failure: failure != null ? failure() : this.failure,
      original: original != null ? original() : _original,
    );
  }

  /// Rebuilds the form around a profile the server just confirmed, so the
  /// "dirty" check starts again from the saved values.
  factory ProfileFormState.fromUser(AppUser user) => ProfileFormState(
    fullName: user.fullName,
    about: user.about,
    gender: user.gender,
    birthYear: user.birthYear,
    city: user.city,
    photoUrl: user.photoUrl,
    original: user,
  );

  @override
  List<Object?> get props => [
    fullName,
    about,
    gender,
    birthYear,
    city,
    photoUrl,
    status,
    photoStatus,
    savedUser,
    failure,
  ];
}
