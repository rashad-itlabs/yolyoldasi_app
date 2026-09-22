part of 'phone_sign_in_bloc.dart';

sealed class PhoneSignInEvent extends Equatable {
  const PhoneSignInEvent();

  @override
  List<Object?> get props => const [];
}

class PhoneSignInPhoneChanged extends PhoneSignInEvent {
  const PhoneSignInPhoneChanged(this.phone);

  final String phone;

  @override
  List<Object?> get props => [phone];
}

/// The country the number belongs to, picked from the flag beside the field.
///
/// Clears whatever was typed: `50 123 45 67` means a different number under a
/// different dial code, and silently reinterpreting it would send the code to
/// a stranger.
class PhoneSignInCountryChanged extends PhoneSignInEvent {
  const PhoneSignInCountryChanged(this.country);

  final Country country;

  @override
  List<Object?> get props => [country];
}

/// An invite code, typed by someone a friend sent here.
///
/// Optional, and never blocks anything: a wrong code simply credits nobody.
class PhoneSignInReferralChanged extends PhoneSignInEvent {
  const PhoneSignInReferralChanged(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

/// Driver or passenger, chosen before the code is even requested.
class PhoneSignInModeChanged extends PhoneSignInEvent {
  const PhoneSignInModeChanged(this.mode);

  final UserMode mode;

  @override
  List<Object?> get props => [mode];
}

/// `POST /auth/phone/request`. Serves both the first request and every resend.
class PhoneSignInCodeRequested extends PhoneSignInEvent {
  const PhoneSignInCodeRequested();
}

class PhoneSignInCodeChanged extends PhoneSignInEvent {
  const PhoneSignInCodeChanged(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

/// `POST /auth/phone/verify`.
class PhoneSignInSubmitted extends PhoneSignInEvent {
  const PhoneSignInSubmitted();
}

/// "Nömrəni dəyiş" — back to step one, dropping the issued code.
class PhoneSignInPhoneEditRequested extends PhoneSignInEvent {
  const PhoneSignInPhoneEditRequested();
}

/// One second of the resend countdown. Raised by the bloc's own timer.
class PhoneSignInTicked extends PhoneSignInEvent {
  const PhoneSignInTicked();
}
