part of 'app_update_bloc.dart';

class AppUpdateState extends Equatable {
  const AppUpdateState({
    this.update = AppUpdate.none,
    this.installed = AppVersionInfo.unknown,
    this.dismissedVersion,
  });

  final AppUpdate update;

  /// What this build is. Carried alongside the verdict because it is the
  /// other half of the same sentence — the update screen shows both, and
  /// keeping it here spares that screen a dependency on the whole object
  /// graph for one string.
  final AppVersionInfo installed;

  /// The release the user already said "later" to, from device preferences.
  final String? dismissedVersion;

  /// The router's cue to wall the app off. Everything else on screen is
  /// irrelevant while this is true.
  bool get blocks => update.blocks;

  /// Whether the optional prompt is still owed to the user.
  ///
  /// A release the user has waved away stays waved away until the store has
  /// a newer one. Nagging on every launch is how a dismissible prompt turns
  /// into a forced one nobody agreed to.
  bool get showsOptional =>
      update.isOptional &&
      (update.latestVersion == null || update.latestVersion != dismissedVersion);

  AppUpdateState copyWith({
    AppUpdate? update,
    String? Function()? dismissedVersion,
  }) {
    return AppUpdateState(
      update: update ?? this.update,
      installed: installed,
      dismissedVersion: dismissedVersion == null
          ? this.dismissedVersion
          : dismissedVersion(),
    );
  }

  @override
  List<Object?> get props => [update, installed, dismissedVersion];
}
