import 'package:equatable/equatable.dart';

/// What the server wants this build to do about its version.
enum AppUpdateStatus {
  /// Current enough. Nothing is shown.
  none,

  /// Newer release exists, but this one still works — a prompt the user may
  /// wave away.
  optional,

  /// Below the minimum the server accepts. The app is walled off until the
  /// user updates.
  forced,
}

/// The answer to `GET /app-version`.
///
/// The verdict is the server's, not the client's: [status] arrives already
/// decided, so raising the bar for an old release means changing one number in
/// the admin panel rather than shipping a build that knows the new rule. That
/// matters most in the case this exists for — the users who need the wall are
/// precisely the ones not running the latest code.
class AppUpdate extends Equatable {
  const AppUpdate({
    this.status = AppUpdateStatus.none,
    this.latestVersion,
    this.minVersion,
    this.storeUrl,
    this.message,
  });

  final AppUpdateStatus status;

  /// The release waiting in the store, for the "yeni versiya 1.2.0" line.
  final String? latestVersion;

  /// The oldest release still allowed — shown only on the forced screen, to
  /// explain why this one stopped working.
  final String? minVersion;

  /// Where to send the user. Null falls back to the compiled-in store link
  /// for this platform (`AppLinks`).
  final String? storeUrl;

  /// The admin's own wording, in the user's language. Null uses the app's
  /// generic copy, so an empty field in the panel is not a blank screen.
  final String? message;

  /// What every failure resolves to. A server that cannot be reached must
  /// never be the reason someone cannot open the app.
  static const AppUpdate none = AppUpdate();

  bool get blocks => status == AppUpdateStatus.forced;
  bool get isOptional => status == AppUpdateStatus.optional;

  @override
  List<Object?> get props => [
    status,
    latestVersion,
    minVersion,
    storeUrl,
    message,
  ];
}
