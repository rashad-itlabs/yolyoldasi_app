import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../bloc/session/session_bloc.dart';

/// Three-page value proposition, shown once before the login screen.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;

  static const int _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Ends onboarding on the search screen, not the sign-in screen.
  ///
  /// The pitch has just been made; the honest next step is showing the goods.
  /// Asking for a phone number here is asking someone to pay at the door of an
  /// empty room — it was the single biggest leak in the funnel.
  ///
  /// The router's redirect reads `onboardingSeen`, so recording it is enough to
  /// move on; the explicit `go` only avoids waiting a frame for it.
  void _finish() {
    context.read<SessionBloc>().add(const SessionOnboardingSeen());
    context.go(Routes.home);
  }

  /// The direct way in, for someone who already has an account.
  ///
  /// Secondary rather than primary: a returning user knows what they came for
  /// and will find one button, while a first-time visitor should not have to
  /// decide anything before seeing a single ride.
  void _signIn() {
    context.read<SessionBloc>().add(const SessionOnboardingSeen());
    context.go(Routes.login);
  }

  void _next() {
    if (_index >= _pageCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(duration: Motion.normal, curve: Motion.emphasized);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final pages = <({String title, String body})>[
      (title: l10n.onboard1Title, body: l10n.onboard1Body),
      (title: l10n.onboard2Title, body: l10n.onboard2Body),
      (title: l10n.onboard3Title, body: l10n.onboard3Body),
    ];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.maxContentWidth),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.page,
                    Gap.md,
                    Gap.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      const BrandMark(size: 30),
                      HGap.md,
                      Text(
                        l10n.appName,
                        style: context.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(onPressed: _finish, child: Text(l10n.skip)),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pageCount,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      // Centred on a tall screen, scrollable on a short one:
                      // a bare scroll view would pin the copy to the top and
                      // leave a gap above the button.
                      return LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Gap.xxl,
                                vertical: Gap.lg,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight:
                                      (constraints.maxHeight - Gap.lg * 2)
                                          .clamp(0.0, double.infinity),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OnboardingArt(index: index)
                                        .animate(key: ValueKey(index))
                                        .fadeIn(duration: 420.ms)
                                        .slideY(
                                          begin: 0.06,
                                          curve: Motion.emphasized,
                                        ),
                                    VGap.xxxl,
                                    Text(
                                          page.title,
                                          textAlign: TextAlign.center,
                                          style: context.text.headlineMedium,
                                        )
                                        .animate(key: ValueKey('t$index'))
                                        .fadeIn(
                                          delay: 100.ms,
                                          duration: 380.ms,
                                        ),
                                    VGap.md,
                                    Text(
                                          page.body,
                                          textAlign: TextAlign.center,
                                          style: context.text.bodyLarge
                                              ?.copyWith(
                                                color: context
                                                    .palette
                                                    .textSecondary,
                                              ),
                                        )
                                        .animate(key: ValueKey('b$index'))
                                        .fadeIn(
                                          delay: 180.ms,
                                          duration: 380.ms,
                                        ),
                                  ],
                                ),
                              ),
                            ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Gap.page),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pageCount, (index) {
                          final active = index == _index;
                          return AnimatedContainer(
                            duration: Motion.fast,
                            curve: Motion.standard,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: active
                                  ? context.colors.primary
                                  : context.palette.border,
                              borderRadius: Radii.pillAll,
                            ),
                          );
                        }),
                      ),
                      VGap.xl,
                      AppButton(
                        label: _index == _pageCount - 1
                            ? l10n.getStarted
                            : l10n.next,
                        onPressed: _next,
                        trailingIcon: _index == _pageCount - 1
                            ? null
                            : Icons.arrow_forward_rounded,
                      ),
                      // Only on the last page: before the pitch is finished
                      // there is nothing to sign in *for*.
                      if (_index == _pageCount - 1) ...[
                        VGap.sm,
                        AppButton.ghost(
                          label: l10n.signIn,
                          onPressed: _signIn,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
