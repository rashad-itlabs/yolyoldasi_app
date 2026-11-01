import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../domain/entities/driver_profile.dart';
import '../../domain/entities/pro_status.dart';
import '../../domain/entities/user_enums.dart';
import '../bloc/driver_profile/driver_profile_bloc.dart';

/// What PRO gives a driver, and the way in.
///
/// Free for now (API.md §7): a one-off trial, which is why the screen leads
/// with what changes for the driver rather than with a price. Four states, all
/// read from `GET /driver/profile`: active, trial on offer, trial on offer
/// but documents not approved yet, and trial used.
class ProPage extends StatelessWidget {
  const ProPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocConsumer<DriverProfileBloc, DriverProfileState>(
      listenWhen: (previous, current) =>
          previous.proTrialStatus != current.proTrialStatus,
      listener: (context, state) {
        if (state.proTrialStatus.isSuccess) {
          HapticFeedback.heavyImpact();
          AppFeedback.success(context, l10n.proActivated);
        }
        final failure = state.failure;
        if (state.proTrialStatus.isFailure && failure != null) {
          AppFeedback.error(context, failure.message(l10n));
          context.read<DriverProfileBloc>().add(
            const DriverProfileFailureCleared(),
          );
        }
      },
      builder: (context, state) {
        final profile = state.profileOrInitial;
        final pro = profile.pro ?? const ProStatus();

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: ProColors.onGold,
            elevation: 0,
            scrolledUnderElevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
          ),
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Hero(pro: pro),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.contentMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.page,
                      Gap.xxl,
                      Gap.page,
                      Gap.xxl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Benefits(),
                        VGap.xxl,
                        const _Preview(),
                        if (!pro.isActive && !pro.trialAvailable) ...[
                          VGap.xxl,
                          _Notice(
                            icon: Icons.schedule_rounded,
                            title: l10n.proExpiredTitle,
                            body: l10n.proExpiredBody,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _Action(
            profile: profile,
            pro: pro,
            isStarting: state.proTrialStatus.isInProgress,
          ),
        );
      },
    );
  }
}

/// The gold header: crown, name, promise — and, once PRO is on, until when.
class _Hero extends StatelessWidget {
  const _Hero({required this.pro});

  final ProStatus pro;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final until = pro.until;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ProColors.heroGradient,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(Radii.xxl)),
      ),
      padding: EdgeInsets.fromLTRB(
        Gap.page,
        // Already includes the app bar: the body extends behind it, and the
        // Scaffold adds its height to the top padding for exactly that.
        MediaQuery.paddingOf(context).top,
        Gap.page,
        Gap.xxxl,
      ),
      child: Column(
        children: [
          Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.35),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.amber700.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 48,
                  color: ProColors.onGold,
                ),
              )
              .animate()
              .scale(
                begin: const Offset(0.6, 0.6),
                duration: Motion.slow,
                curve: Motion.spring,
              )
              .then(delay: 200.ms)
              .shimmer(
                duration: 1200.ms,
                color: Colors.white.withValues(alpha: 0.7),
              ),
          VGap.lg,
          Text(
            '${l10n.appName} PRO',
            textAlign: TextAlign.center,
            style: context.text.headlineMedium?.copyWith(
              color: ProColors.onGold,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          VGap.sm,
          Text(
            l10n.proTagline,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(
              color: ProColors.onGold.withValues(alpha: 0.85),
            ),
          ),
          if (pro.isActive) ...[
            VGap.lg,
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: Radii.pillAll,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: ProColors.onGold,
                  ),
                  HGap.sm,
                  Flexible(
                    child: Text(
                      until == null
                          ? l10n.proActiveTitle
                          : '${l10n.proActiveTitle} · '
                                '${l10n.proActiveUntil(context.fmt.dayMonth(until))}',
                      style: context.text.labelLarge?.copyWith(
                        color: ProColors.onGold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: Motion.normal),
          ],
        ],
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppCard(
      child: Column(
        children: [
          _Benefit(
            icon: Icons.rocket_launch_rounded,
            title: l10n.proBoostTitle,
            body: l10n.proBoostBody,
          ),
          Divider(height: Gap.xxl, color: context.palette.border),
          _Benefit(
            icon: Icons.workspace_premium_rounded,
            title: l10n.proBadgeTitle,
            body: l10n.proBadgeBody,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.06);
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.amber50,
            borderRadius: Radii.mdAll,
            border: Border.all(color: AppColors.amber200),
          ),
          child: Icon(icon, color: AppColors.amber700, size: 22),
        ),
        HGap.lg,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleSmall),
              VGap.xs,
              Text(
                body,
                style: context.text.bodySmall?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The driver's own row as a passenger will meet it — their name, their photo,
/// the badge — so the benefit is something they can see, not take on trust.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.select<SessionBloc, ({String name, String? photo})>(
      (bloc) => (
        name: bloc.state.user?.fullName ?? '',
        photo: bloc.state.user?.photoUrl,
      ),
    );
    final rating = context.select<SessionBloc, double>(
      (bloc) => bloc.state.user?.stats.ratingFor(UserMode.driver) ?? 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.proPreviewCaption,
          style: context.text.labelLarge?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        VGap.md,
        AppCard(
          child: Row(
            children: [
              AppAvatar(
                name: user.name,
                photoUrl: user.photo,
                size: Sizes.avatarSm + 6,
              ),
              HGap.md,
              Flexible(
                child: Text(
                  context.fmt.shortName(user.name),
                  style: context.text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              HGap.sm,
              const ProBadge(),
              if (rating > 0) ...[
                HGap.sm,
                RatingLabel(rating: rating, compact: true),
              ],
              const Spacer(),
              StatusChip(
                label: '#1',
                tone: ChipTone.accent,
                icon: Icons.rocket_launch_rounded,
                dense: true,
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.06);
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.textSecondary),
          HGap.md,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                VGap.xs,
                Text(
                  body,
                  style: context.text.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The bottom of the screen: the trial button, or the way to the documents
/// that unlock it. Nothing at all once PRO is on or the trial is spent — the
/// header and the notice already say so, and a dead button would only invite
/// taps.
class _Action extends StatelessWidget {
  const _Action({
    required this.profile,
    required this.pro,
    required this.isStarting,
  });

  final DriverProfile profile;
  final ProStatus pro;
  final bool isStarting;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (pro.isActive || !pro.trialAvailable) return const SizedBox.shrink();

    // The server only starts the trial for an approved driver: before that
    // the driver could not publish, and the trial days would run out on
    // rides that do not exist.
    final unlocked = profile.status.isApproved;

    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.md,
              Gap.page,
              Gap.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unlocked)
                  _GoldButton(
                    label: l10n.proStartTrial(pro.trialDays),
                    isLoading: isStarting,
                    onPressed: () => context.read<DriverProfileBloc>().add(
                      const DriverProTrialStarted(),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: Sizes.buttonHeight,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(Routes.documents),
                      icon: const Icon(Icons.badge_outlined),
                      label: Text(l10n.proToDocuments),
                    ),
                  ),
                VGap.sm,
                Text(
                  unlocked ? l10n.proTrialNote : l10n.proLockedBody,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(
                    color: context.palette.textTertiary,
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

/// A full-width button in PRO gold, which the stock buttons do not come in.
class _GoldButton extends StatelessWidget {
  const _GoldButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !isLoading,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: Radii.mdAll,
        child: Ink(
          height: Sizes.buttonHeight,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: ProColors.gradient),
            borderRadius: Radii.mdAll,
            boxShadow: [
              BoxShadow(
                color: AppColors.amber500.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: Radii.mdAll,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: ProColors.onGold,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: ProColors.onGold,
                        ),
                        HGap.sm,
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleMedium?.copyWith(
                              color: ProColors.onGold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
