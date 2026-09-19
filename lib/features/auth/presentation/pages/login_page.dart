import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/otp_input.dart';
import '../../../profile/domain/entities/user_enums.dart';
import '../bloc/phone_sign_in/phone_sign_in_bloc.dart';
import '../bloc/session/session_bloc.dart';

/// Phone sign-in — API.md §3.
///
/// Both steps share one route. They are two halves of a single decision, the
/// second is worth nothing without the first, and keeping them here means the
/// router never has to reason about a half-finished sign-in: leaving the screen
/// leaves the whole flow.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<OtpInputState> _otpKey = GlobalKey<OtpInputState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _requestCode() {
    context.hideKeyboard();
    context.read<PhoneSignInBloc>().add(const PhoneSignInCodeRequested());
  }

  void _verify() {
    context.hideKeyboard();
    context.read<PhoneSignInBloc>().add(const PhoneSignInSubmitted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PhoneSignInBloc, PhoneSignInState>(
      listenWhen: (previous, current) =>
          (previous.session != current.session && current.session != null) ||
          (previous.code != current.code && current.code.isEmpty),
      listener: (context, state) {
        // The session is what actually signs the user in; the router redirects
        // as soon as it flips. The chosen mode rides along, so the first screen
        // the user lands on is already the right side of the app.
        if (state.session != null) {
          context.read<SessionBloc>().add(
            SessionSignedIn(state.session!, mode: state.mode),
          );
          return;
        }
        // The bloc dropped the code — it was wrong, expired, or a fresh one was
        // just issued. The boxes own their own text, so they have to be told.
        _otpKey.currentState?.clear();
      },
      builder: (context, state) {
        return DismissKeyboard(
          child: AppScaffold(
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.xxxl,
                  Gap.page,
                  Gap.xxl,
                ),
                children: [
                  const BrandMark(size: 56),
                  VGap.xxl,
                  if (state.step.isPhone)
                    ..._phoneStep(context, state)
                  else
                    ..._codeStep(context, state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------ step 1

  List<Widget> _phoneStep(BuildContext context, PhoneSignInState state) {
    final l10n = context.l10n;
    final palette = context.palette;

    return [
      Text(l10n.loginTitle, style: context.text.displaySmall),
      VGap.sm,
      Text(
        l10n.loginSubtitle,
        style: context.text.bodyLarge?.copyWith(color: palette.textSecondary),
      ),

      VGap.xxl,
      Text(l10n.chooseModeTitle, style: context.text.titleMedium),
      VGap.sm,
      Text(
        l10n.chooseModeBody,
        style: context.text.bodySmall?.copyWith(color: palette.textSecondary),
      ),
      VGap.md,
      AppSegmented<UserMode>(
        value: state.mode,
        onChanged: (mode) =>
            context.read<PhoneSignInBloc>().add(PhoneSignInModeChanged(mode)),
        options: [
          (
            value: UserMode.passenger,
            label: l10n.passengerMode,
            icon: Icons.person_outline_rounded,
          ),
          (
            value: UserMode.driver,
            label: l10n.driverMode,
            icon: Icons.directions_car_outlined,
          ),
        ],
      ),
      // `PUT /me/mode` refuses `driver` until there is a car (API.md §5), and
      // that cannot be checked before `/me` has answered — so it is said up
      // front rather than after.
      if (state.mode.isDriver) ...[
        VGap.md,
        InfoBanner(
          tone: BannerTone.warning,
          icon: Icons.directions_car_outlined,
          message: l10n.driverModeNeedsVehicle,
        ),
      ],

      VGap.xl,
      AppTextField(
        controller: _phoneController,
        label: l10n.phoneNumber,
        hint: l10n.phoneHint,
        isRequired: true,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.telephoneNumber],
        inputFormatters: const [_PhoneFormatter()],
        prefixIcon: Icons.phone_outlined,
        // The country code is fixed and never typed, so it is stated rather
        // than asked for.
        helper: PhoneNumbers.countryCode,
        errorText: state.failure?.message(l10n),
        onChanged: (value) =>
            context.read<PhoneSignInBloc>().add(PhoneSignInPhoneChanged(value)),
        onSubmitted: (_) => state.canRequestCode ? _requestCode() : null,
      ),

      VGap.xl,
      AppButton(
        label: l10n.sendCode,
        onPressed: state.canRequestCode ? _requestCode : null,
        isLoading: state.status.isBusy,
      ),

      VGap.xl,
      const _TermsText(),
    ];
  }

  // ------------------------------------------------------------------ step 2

  List<Widget> _codeStep(BuildContext context, PhoneSignInState state) {
    final l10n = context.l10n;
    final palette = context.palette;
    final devCode = state.devCode;

    return [
      Text(l10n.otpTitle, style: context.text.displaySmall),
      VGap.sm,
      Text(
        // The server's canonical number, not what was typed — they can differ,
        // and the one that matters is the one the code was issued against.
        l10n.otpSentTo(PhoneNumbers.format(state.challenge?.phone ?? '')),
        style: context.text.bodyLarge?.copyWith(color: palette.textSecondary),
      ),
      VGap.sm,
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: AppButton.ghost(
          label: l10n.changeNumber,
          icon: Icons.edit_outlined,
          onPressed: state.status.isBusy
              ? null
              : () => context.read<PhoneSignInBloc>().add(
                  const PhoneSignInPhoneEditRequested(),
                ),
        ),
      ),

      // Only reachable while the API still echoes the code back; the moment an
      // SMS provider lands, `code` stops arriving and this disappears on its
      // own.
      if (devCode != null) ...[
        VGap.lg,
        InfoBanner(
          tone: BannerTone.warning,
          icon: Icons.sms_failed_outlined,
          title: l10n.devCodeTitle,
          message: l10n.devCodeBody,
          action: AppButton.ghost(
            label: devCode,
            icon: Icons.content_paste_rounded,
            onPressed: () => _otpKey.currentState?.fill(devCode),
          ),
        ),
      ],

      VGap.xxl,
      OtpInput(
        key: _otpKey,
        hasError: state.status.isFailure,
        enabled: !state.status.isBusy,
        onChanged: (value) =>
            context.read<PhoneSignInBloc>().add(PhoneSignInCodeChanged(value)),
        onCompleted: (_) => _verify(),
      ),
      if (state.failure != null) ...[
        VGap.md,
        Text(
          state.failure!.message(l10n),
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(color: context.colors.error),
        ),
      ],
      VGap.md,
      Text(
        l10n.otpAutoHint,
        textAlign: TextAlign.center,
        style: context.text.bodySmall?.copyWith(color: palette.textTertiary),
      ),

      VGap.xl,
      AppButton(
        label: l10n.verify,
        onPressed: state.canVerify ? _verify : null,
        isLoading: state.status.isBusy,
      ),
      VGap.md,
      Center(
        child: state.resendIn > 0
            // A dead button with the remaining time reads better than a live
            // one that would only earn another 429.
            ? Text(
                l10n.resendCountdown(_mmss(state.resendIn)),
                style: context.text.bodySmall?.copyWith(
                  color: palette.textTertiary,
                ),
              )
            : AppButton.ghost(
                label: l10n.resendCode,
                icon: Icons.refresh_rounded,
                onPressed: state.canRequestCode ? _requestCode : null,
              ),
      ),
    ];
  }

  static String _mmss(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// Groups the national number as it is typed: `50 123 45 67`.
///
/// The caret is parked at the end after every edit. Digits inserted in the
/// middle would otherwise land in the wrong place once the spacing shifts, and
/// a nine-digit field is retyped rather than edited in practice.
class _PhoneFormatter extends TextInputFormatter {
  const _PhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = PhoneNumbers.formatAsTyped(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Terms + privacy line under the submit button.
///
/// Stateful so the two [TapGestureRecognizer]s are disposed with the widget
/// rather than leaking for the lifetime of the app.
class _TermsText extends StatefulWidget {
  const _TermsText();

  @override
  State<_TermsText> createState() => _TermsTextState();
}

class _TermsTextState extends State<_TermsText> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()..onTap = () => _open(AppLinks.termsUrl);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _open(AppLinks.privacyUrl);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final base = context.text.bodySmall?.copyWith(color: palette.textTertiary);
    final link = base?.copyWith(
      color: context.colors.primary,
      fontWeight: FontWeight.w600,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: l10n.termsPrefix),
          TextSpan(text: l10n.termsOfUse, style: link, recognizer: _termsTap),
          TextSpan(text: l10n.termsAnd),
          TextSpan(
            text: l10n.privacyPolicy,
            style: link,
            recognizer: _privacyTap,
          ),
          TextSpan(text: l10n.termsSuffix),
        ],
      ),
      textAlign: TextAlign.center,
      style: base,
    );
  }
}
