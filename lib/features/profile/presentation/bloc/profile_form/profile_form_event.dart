part of 'profile_form_bloc.dart';

sealed class ProfileFormEvent extends Equatable {
  const ProfileFormEvent();

  @override
  List<Object?> get props => const [];
}

/// Seeds the form from the signed-in profile. Fired when the screen opens.
class ProfileFormStarted extends ProfileFormEvent {
  const ProfileFormStarted(this.user);

  final AppUser? user;

  @override
  List<Object?> get props => [user];
}

class ProfileFullNameChanged extends ProfileFormEvent {
  const ProfileFullNameChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

class ProfileAboutChanged extends ProfileFormEvent {
  const ProfileAboutChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

class ProfileGenderChanged extends ProfileFormEvent {
  const ProfileGenderChanged(this.value);

  final Gender value;

  @override
  List<Object?> get props => [value];
}

class ProfileBirthYearChanged extends ProfileFormEvent {
  const ProfileBirthYearChanged(this.value);

  /// `null` clears the field, which `PATCH /me` accepts.
  final int? value;

  @override
  List<Object?> get props => [value];
}

class ProfileCityChanged extends ProfileFormEvent {
  const ProfileCityChanged(this.city);

  final City? city;

  @override
  List<Object?> get props => [city];
}

/// `POST /me/photo`. Uploads straight away rather than waiting for submit, so
/// the avatar updates while the rest of the form is still being filled in.
class ProfilePhotoPicked extends ProfileFormEvent {
  const ProfilePhotoPicked(this.photo);

  final UploadFile photo;

  @override
  List<Object?> get props => [photo];
}

/// `PATCH /me` with whatever actually changed.
class ProfileFormSubmitted extends ProfileFormEvent {
  const ProfileFormSubmitted();
}

class ProfileFormFailureCleared extends ProfileFormEvent {
  const ProfileFormFailureCleared();
}
