import 'package:equatable/equatable.dart';

/// What `POST /auth/phone/request` hands back: a code is now waiting against
/// [phone], and these are its terms.
///
/// The server normalises whatever the user typed (`0505550001`,
/// `050 555 00 01`, `994...`) into one E.164 number and returns it. [phone] is
/// that number, and it is what the verify step must send back — not the
/// original input, which may differ.
class OtpChallenge extends Equatable {
  const OtpChallenge({
    required this.phone,
    required this.expiresIn,
    required this.resendAfter,
    this.devCode,
  });

  /// Canonical `+994XXXXXXXXX`.
  final String phone;

  /// How long this code stays usable. Requesting a new one kills it early, so
  /// only the most recent code ever works.
  final Duration expiresIn;

  /// How long before another code may be requested. The API answers 429 until
  /// it has elapsed.
  final Duration resendAfter;

  /// The code itself, which the API returns while no SMS provider is wired up.
  ///
  /// Null once the server stops sending it — which is the point at which this
  /// whole field, and the banner that shows it, become dead code. Until then it
  /// is the only way to sign in on a device that receives no SMS.
  final String? devCode;

  @override
  List<Object?> get props => [phone, expiresIn, resendAfter, devCode];
}
