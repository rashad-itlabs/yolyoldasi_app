import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/dial_codes.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/utils/phone_number.dart';
import '../../../../profile/domain/entities/user_enums.dart';
import '../../../domain/entities/auth_session.dart';
import '../../../domain/entities/otp_challenge.dart';
import '../../../domain/repositories/auth_repository.dart';

part 'phone_sign_in_event.dart';
part 'phone_sign_in_state.dart';

/// The two-step phone sign-in of API.md §3.
///
/// Both steps live in one bloc because they share state that has to survive the
/// move between them: the canonical number the server chose, the resend clock,
/// and the driver/passenger pick made before either step ran.
class PhoneSignInBloc extends Bloc<PhoneSignInEvent, PhoneSignInState> {
  PhoneSignInBloc({required AuthRepository auth})
    : _auth = auth,
      super(const PhoneSignInState()) {
    on<PhoneSignInPhoneChanged>(_onPhoneChanged);
    on<PhoneSignInModeChanged>(_onModeChanged);
    on<PhoneSignInCodeRequested>(_onCodeRequested);
    on<PhoneSignInCodeChanged>(_onCodeChanged);
    on<PhoneSignInCountryChanged>(_onCountryChanged);
    on<PhoneSignInReferralChanged>(_onReferralChanged);
    on<PhoneSignInSubmitted>(_onSubmitted);
    on<PhoneSignInPhoneEditRequested>(_onPhoneEditRequested);
    on<PhoneSignInTicked>(_onTicked);
  }

  final AuthRepository _auth;
  Timer? _resendTimer;

  void _onPhoneChanged(
    PhoneSignInPhoneChanged event,
    Emitter<PhoneSignInState> emit,
  ) {
    emit(state.copyWith(phone: event.phone, failure: () => null));
  }

  void _onModeChanged(
    PhoneSignInModeChanged event,
    Emitter<PhoneSignInState> emit,
  ) {
    emit(state.copyWith(mode: event.mode));
  }

  void _onCodeChanged(
    PhoneSignInCodeChanged event,
    Emitter<PhoneSignInState> emit,
  ) {
    emit(state.copyWith(code: event.code, failure: () => null));
  }

  /// Step 1, and the resend button — they are the same call.
  void _onCountryChanged(
    PhoneSignInCountryChanged event,
    Emitter<PhoneSignInState> emit,
  ) {
    if (state.country == event.country) return;

    // The number goes with the flag. The digits already typed were a number in
    // the old country, not this one, and carrying them over would look like
    // the app had understood something it had not.
    emit(state.copyWith(country: event.country, phone: '', failure: () => null));
  }

  void _onReferralChanged(
    PhoneSignInReferralChanged event,
    Emitter<PhoneSignInState> emit,
  ) {
    emit(state.copyWith(referralCode: event.code));
  }

  Future<void> _onCodeRequested(
    PhoneSignInCodeRequested event,
    Emitter<PhoneSignInState> emit,
  ) async {
    if (!state.canRequestCode) return;

    emit(state.copyWith(status: ActionStatus.inProgress, failure: () => null));

    // Full E.164, not the digits as typed.
    //
    // The server falls back to Azerbaijani heuristics for a bare number — a
    // nine-digit Georgian number would come back as `+994…`, and a Turkish one
    // written with its trunk zero as `+0555…`. Sending the dial code the user
    // actually picked removes the guesswork entirely.
    final e164 =
        PhoneNumbers.toE164(state.phone, country: state.country) ?? state.phone;

    final result = await _auth.requestCode(e164);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            step: PhoneSignInStep.code,
            status: ActionStatus.success,
            challenge: () => value,
            // A fresh code invalidates the previous one server-side, so a
            // half-typed old code must not stay on screen.
            code: '',
            resendIn: value.resendAfter.inSeconds,
          ),
        );
        _startResendTimer();
      case Err(:final failure):
        // A 429 here is the resend throttle, and it says how long is left —
        // running the clock down is more use than repeating the number.
        final wait = failure is RateLimitFailure ? failure.retryAfter : null;
        emit(
          state.copyWith(
            status: ActionStatus.failure,
            failure: () => failure,
            resendIn: wait?.inSeconds,
          ),
        );
        if (wait != null) _startResendTimer();
    }
  }

  /// Step 2.
  Future<void> _onSubmitted(
    PhoneSignInSubmitted event,
    Emitter<PhoneSignInState> emit,
  ) async {
    if (!state.canVerify) return;

    emit(
      state.copyWith(
        status: ActionStatus.inProgress,
        session: () => null,
        failure: () => null,
      ),
    );

    final result = await _auth.verifyCode(
      // The number the server normalised, not what was typed — §3 is explicit
      // that verify has to be given back the phone from the request response.
      phone: state.challenge!.phone,
      code: state.code,
      referralCode: state.referralCode,
    );
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(status: ActionStatus.success, session: () => value),
        );
      case Err(:final failure):
        // The code is cleared on any failure: every one of them (wrong,
        // expired, spent, cancelled after five tries) means this code will
        // never work, so leaving it in the boxes only invites a re-tap.
        emit(
          state.copyWith(
            status: ActionStatus.failure,
            code: '',
            failure: () => failure,
          ),
        );
    }
  }

  void _onPhoneEditRequested(
    PhoneSignInPhoneEditRequested event,
    Emitter<PhoneSignInState> emit,
  ) {
    _resendTimer?.cancel();
    emit(
      state.copyWith(
        step: PhoneSignInStep.phone,
        status: ActionStatus.idle,
        code: '',
        challenge: () => null,
        failure: () => null,
        // The throttle is per number, so going back to change it must not
        // inherit the previous number's wait.
        resendIn: 0,
      ),
    );
  }

  void _onTicked(PhoneSignInTicked event, Emitter<PhoneSignInState> emit) {
    final remaining = state.resendIn - 1;
    if (remaining <= 0) _resendTimer?.cancel();
    emit(state.copyWith(resendIn: remaining < 0 ? 0 : remaining));
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    if (state.resendIn <= 0) return;
    _resendTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const PhoneSignInTicked()),
    );
  }

  @override
  Future<void> close() {
    _resendTimer?.cancel();
    return super.close();
  }
}
