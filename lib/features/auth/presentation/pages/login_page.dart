import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/dial_codes.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/analytics.dart';
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
import '../widgets/country_picker_sheet.dart';

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

  /// Opens the dial-code picker and tells the bloc what came back.
  Future<void> _pickCountry(BuildContext context, Country current) async {
    final bloc = context.read<PhoneSignInBloc>();
    final picked = await CountryPickerSheet.show(context, selected: current);
    if (picked == null) return;

    // Clears the field as well as the state: the controller holds its own text
    // and would otherwise keep the old digits under the new flag.
    _phoneController.clear();
    bloc.add(PhoneSignInCountryChanged(picked));
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
          // The end of the sign-up funnel. `is_new_user` is what separates a
          // returning user from an acquisition, and `has_referral` says
          // whether an invite brought them.
          context.read<Analytics>().log(
            Ev.signInCompleted,
            params: {
              'mode': state.mode.apiValue,
              'is_new_user': state.session!.isNewUser,
              'has_referral': state.referralCode.trim().isNotEmpty,
            },
          );

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
        final l10n = context.l10n;

        return DismissKeyboard(
          child: AppScaffold(
            // The way out of the sign-in screen.
            //
            // Browsing does not need an account (API.md §18), so this screen is
            // an offer rather than a gate — and an offer needs a "no". Without
            // it, anyone who arrives here by pressing a button they did not
            // mean to is stuck asking for an SMS to get back to the search
            // form.
            //
            // `go`, not `pop`: the screen is reached both by a push (from a
            // booking button) and by a replace (from onboarding), and only one
            // of those has anything to pop back to.
            actions: [
              if (state.step.isPhone)
                TextButton(
                  onPressed: () => context.go(Routes.home),
                  child: Text(l10n.skipSignIn),
                ),
              HGap.sm,
            ],
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

      // The dial code used to be a fixed `+994` printed under the box, which
      // meant a driver on a Turkish SIM could not sign in at all. It is now a
      // picker — still Azerbaijan on open, because that is where almost every
      // account comes from.
      // Above the number rather than beside it. Side by side reads tighter,
      // but the flag, the dial code and a country name cannot share a line
      // with a phone field at a large text scale without one of them being
      // cut — and the people most likely to need this picker are the ones
      // least able to guess what got cut.
      VGap.xl,
      AppPickerField(
        label: l10n.countryCodeTitle,
        value: '${state.country.flag}  ${state.country.name}  '
            '${state.country.prefix}',
        icon: Icons.public_rounded,
        onTap: () => _pickCountry(context, state.country),
      ),

      VGap.lg,
      AppTextField(
        controller: _phoneController,
        label: l10n.phoneNumber,
        hint: l10n.phoneHint,
        isRequired: true,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.telephoneNumber],
        // Rebuilt per country: the grouping and the digit cap both depend on
        // it, so a `const` formatter would keep Azerbaijani spacing on a
        // foreign number.
        inputFormatters: [_PhoneFormatter(state.country)],
        errorText: state.failure?.message(l10n),
        onChanged: (value) =>
            context.read<PhoneSignInBloc>().add(PhoneSignInPhoneChanged(value)),
        onSubmitted: (_) => state.canRequestCode ? _requestCode() : null,
      ),

      // Folded away rather than shown outright: almost nobody arrives with a
      // code, and an empty field above the sign-in button would read as one
      // more thing being asked for.
      VGap.md,
      _ReferralField(
        onChanged: (value) => context.read<PhoneSignInBloc>().add(
          PhoneSignInReferralChanged(value),
        ),
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
  const _PhoneFormatter(this.country);

  final Country country;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = PhoneNumbers.formatAsTyped(
      newValue.text,
      country: country,
    );
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


/// The optional invite-code field, collapsed until asked for.
class _ReferralField extends StatefulWidget {
  const _ReferralField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_ReferralField> createState() => _ReferralFieldState();
}

class _ReferralFieldState extends State<_ReferralField> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (!_expanded) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => setState(() => _expanded = true),
          icon: const Icon(Icons.card_giftcard_rounded, size: 18),
          label: Text(l10n.referralCodeHint),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    return AppTextField(
      label: l10n.referralCode,
      hint: l10n.referralCodeHint,
      autofocus: true,
      prefixIcon: Icons.card_giftcard_rounded,
      textCapitalization: TextCapitalization.characters,
      maxLength: 12,
      onChanged: widget.onChanged,
    );
  }
}
