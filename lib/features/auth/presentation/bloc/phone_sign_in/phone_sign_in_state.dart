part of 'phone_sign_in_bloc.dart';

/// Which half of the sign-in the screen is showing.
enum PhoneSignInStep {
  phone,
  code;

  bool get isPhone => this == PhoneSignInStep.phone;
  bool get isCode => this == PhoneSignInStep.code;
}

class PhoneSignInState extends Equatable {
  const PhoneSignInState({
    this.step = PhoneSignInStep.phone,
    this.phone = '',
    this.code = '',
    this.mode = UserMode.passenger,
    this.challenge,
    this.status = ActionStatus.idle,
    this.session,
    this.failure,
    this.resendIn = 0,
  });

  final PhoneSignInStep step;

  /// The number as typed. The canonical form the API settled on lives on
  /// [challenge] and is what verification is sent against.
  final String phone;

  final String code;

  /// Which side of the app to land on. Applied with `PUT /me/mode` once `/me`
  /// has answered — see [SessionSignedIn].
  final UserMode mode;

  /// Set once a code has been issued. Null on the first step.
  final OtpChallenge? challenge;

  final ActionStatus status;

  /// Set once the code is accepted. The sign-in screen hands it to
  /// [SessionBloc].
  final AuthSession? session;

  final Failure? failure;

  /// Seconds left before another code may be requested; 0 when it may be now.
  final int resendIn;

  bool get canRequestCode =>
      PhoneNumbers.isValid(phone) && !status.isBusy && resendIn == 0;

  bool get canVerify => code.length == AppRules.otpLength && !status.isBusy;

  /// The code the API echoes back while no SMS provider is wired up. Null once
  /// the server stops sending it.
  String? get devCode => challenge?.devCode;

  PhoneSignInState copyWith({
    PhoneSignInStep? step,
    String? phone,
    String? code,
    UserMode? mode,
    OtpChallenge? Function()? challenge,
    ActionStatus? status,
    AuthSession? Function()? session,
    Failure? Function()? failure,
    int? resendIn,
  }) {
    return PhoneSignInState(
      step: step ?? this.step,
      phone: phone ?? this.phone,
      code: code ?? this.code,
      mode: mode ?? this.mode,
      challenge: challenge != null ? challenge() : this.challenge,
      status: status ?? this.status,
      session: session != null ? session() : this.session,
      failure: failure != null ? failure() : this.failure,
      resendIn: resendIn ?? this.resendIn,
    );
  }

  @override
  List<Object?> get props => [
    step,
    phone,
    code,
    mode,
    challenge,
    status,
    session,
    failure,
    resendIn,
  ];
}
