import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/analytics.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../domain/entities/user_enums.dart';
import '../bloc/driver_profile/driver_profile_bloc.dart';
import '../widgets/profile_tile.dart';

/// The account tab: identity, driver setup and settings.
///
/// Also where the user moves between the two halves of the app. The switch
/// asks first, because half the tabs change underneath them — but it is here,
/// rather than only on the sign-in screen, since the same person drives one
/// way and rides the other.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final l10n = context.l10n;
    final session = context.read<SessionBloc>();

    final confirmed = await AppFeedback.confirm(
      context,
      title: l10n.logoutConfirm,
      confirmLabel: l10n.logout,
      isDestructive: true,
    );
    if (confirmed) session.add(const SessionSignOutRequested());
  }

  /// Flips between the two halves of the app.
  ///
  /// Confirmed rather than instant because half the tabs change underneath the
  /// user, and an accidental tap on the profile screen should not do that. The
  /// driver-without-a-car case is sent to the vehicle form instead of an error:
  /// adding the first car is exactly what moves them across.
  Future<void> _switchMode(BuildContext context, UserMode current) async {
    final l10n = context.l10n;
    final session = context.read<SessionBloc>();
    final analytics = context.read<Analytics>();
    final target = current.isDriver ? UserMode.passenger : UserMode.driver;

    if (target.isDriver && !(session.state.user?.hasDriverProfile ?? false)) {
      final addCar = await AppFeedback.confirm(
        context,
        title: l10n.errDriverProfileRequired,
        confirmLabel: l10n.vehicle,
      );
      if (addCar && context.mounted) context.push(Routes.vehicle);
      return;
    }

    final confirmed = await AppFeedback.confirm(
      context,
      title: target.isDriver ? l10n.switchToDriver : l10n.switchToPassenger,
      message: target.isDriver
          ? l10n.switchModeConfirmDriver
          : l10n.switchModeConfirmPassenger,
      confirmLabel: l10n.switchMode,
    );
    if (!confirmed) return;

    analytics.log(Ev.modeSwitched, params: {'to': target.apiValue});
    session.add(SessionModeRequested(target));

    if (context.mounted) AppFeedback.success(context, l10n.switchModeDone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return BlocConsumer<SessionBloc, SessionState>(
      listenWhen: (previous, current) => previous.failure != current.failure,
      listener: (context, state) {
        final failure = state.failure;
        if (failure != null) AppFeedback.error(context, failure.message(l10n));
      },
      builder: (context, session) {
        final user = session.user;
        if (user == null) return const LoadingState();

        final mode = session.activeMode;

        // A passenger is shown nothing about driving — vehicle and documents
        // belong to the other half of the app. The one exception is someone
        // who picked driver at sign-in and has no car yet: adding that first
        // car is exactly what moves them across, so they still need the way
        // in (see `SessionBloc._applyPendingMode`).
        final showsDriverSection =
            mode.isDriver || (session.pendingMode?.isDriver ?? false);

        return AppScaffold(
          title: l10n.profile,
          showBackButton: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settings,
              onPressed: () => context.push(Routes.settings),
            ),
            HGap.sm,
          ],
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<SessionBloc>().add(const SessionRefreshed());
              // Read even for a passenger: the avatar's verified tick comes
              // from it, and a driver pick waiting on a car needs it fresh.
              context.read<DriverProfileBloc>().add(
                const DriverProfileRequested(force: true),
              );
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.lg,
                Gap.page,
                Gap.xxxl,
              ),
              children: [
                // -------------------------------------------------- identity
                AppCard(
                  onTap: () => context.push(Routes.editProfile),
                  child: Row(
                    children: [
                      BlocBuilder<DriverProfileBloc, DriverProfileState>(
                        buildWhen: (previous, current) =>
                            previous.profile?.status != current.profile?.status,
                        builder: (context, driver) => AppAvatar(
                          name: user.fullName,
                          photoUrl: user.photoUrl,
                          size: Sizes.avatarLg,
                          isVerified:
                              driver.profile?.status.isApproved ?? false,
                        ),
                      ),
                      HGap.lg,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.fullName, style: context.text.titleLarge),
                            VGap.xs,
                            Text(
                              PhoneNumbers.format(user.phone),
                              style: context.text.bodySmall?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            VGap.sm,
                            Row(
                              children: [
                                RatingLabel(
                                  rating: user.stats.ratingFor(mode),
                                  reviewCount: user.stats.reviewCountFor(mode),
                                  compact: true,
                                ),
                                HGap.md,
                                Text(
                                  l10n.tripsCount(user.stats.totalTrips),
                                  style: context.text.labelSmall?.copyWith(
                                    color: palette.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: palette.textTertiary,
                      ),
                    ],
                  ),
                ),

                // ---------------------------------------------- active mode
                // Switchable from here, not only at sign-in. The same person
                // drives out on Friday and rides back on Monday, and asking
                // them to sign out and redo the OTP to say so was costing us
                // half of what each account is worth — as well as hiding the
                // driver half of the app from every passenger who owns a car.
                VGap.xl,
                ProfileSection(
                  children: [
                    ProfileTile(
                      icon: mode.isDriver
                          ? Icons.directions_car_outlined
                          : Icons.person_outline_rounded,
                      label: l10n.activeMode,
                      value: mode.isDriver
                          ? l10n.driverMode
                          : l10n.passengerMode,
                      onTap: () => _switchMode(context, mode),
                    ),
                  ],
                ),

                // A passenger who already has a car is the cheapest driver
                // there is: they trust the product because they have used it.
                // Shown only once they have trips behind them, so it reads as
                // an offer rather than a nag on an empty account.
                if (!mode.isDriver && user.stats.passengerTripCount >= 2) ...[
                  VGap.lg,
                  _BecomeDriverCard(
                    onTap: () => _switchMode(context, UserMode.driver),
                  ),
                ],

                // -------------------------------------------------- driver
                if (showsDriverSection) ...[VGap.xxl, const _DriverSection()],

                // ------------------------------------------------ activity
                VGap.xl,
                ProfileSection(
                  children: [
                    ProfileTile(
                      icon: Icons.star_outline_rounded,
                      label: l10n.reviews,
                      value: l10n.reviewsCount(
                        user.stats.driverReviewCount +
                            user.stats.passengerReviewCount,
                      ),
                      onTap: () => context.push(Routes.myReviews),
                    ),
                    ProfileTile(
                      icon: Icons.notifications_none_rounded,
                      label: l10n.notifications,
                      onTap: () => context.push(Routes.notifications),
                    ),
                    // Driver and passenger see different halves of the same
                    // marketplace: what people are asking for on the routes
                    // this driver runs, or what this passenger is still
                    // waiting on. A stable address for both — the home screen
                    // card is discovery, this is where you go back to look.
                    ProfileTile(
                      icon: Icons.campaign_outlined,
                      label: mode.isDriver
                          ? l10n.incomingRideRequests
                          : l10n.myRideRequests,
                      onTap: () => context.push(
                        mode.isDriver
                            ? Routes.rideRequestsIncoming
                            : Routes.rideRequests,
                      ),
                    ),
                    // The cheapest growth channel we have: an existing user
                    // vouching for the product to someone they know.
                    ProfileTile(
                      icon: Icons.card_giftcard_rounded,
                      label: l10n.referral,
                      onTap: () => context.push(Routes.referral),
                    ),
                    ProfileTile(
                      icon: Icons.settings_outlined,
                      label: l10n.settings,
                      onTap: () => context.push(Routes.settings),
                    ),
                  ],
                ),

                VGap.xl,
                ProfileSection(
                  children: [
                    ProfileTile(
                      icon: Icons.logout_rounded,
                      label: l10n.logout,
                      isDestructive: true,
                      onTap: () => _logout(context),
                    ),
                  ],
                ),

                VGap.xxl,
                Center(
                  child: Text(
                    '${l10n.version} '
                    '${context.read<AppDependencies>().version.display}',
                    style: context.text.labelSmall?.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Vehicle and documents, both driven by `GET /driver/profile`.
class _DriverSection extends StatelessWidget {
  const _DriverSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<DriverProfileBloc, DriverProfileState>(
      builder: (context, state) {
        final profile = state.profile;
        final docStatus = profile?.status ?? VerificationStatus.notUploaded;
        final vehicle = profile?.vehicle;

        return ProfileSection(
          title: l10n.driverMode.toUpperCase(),
          children: [
            ProfileTile(
              icon: Icons.directions_car_filled_outlined,
              label: l10n.vehicle,
              value: vehicle?.displayName ?? l10n.noVehicle,
              onTap: () => context.push(Routes.vehicle),
            ),
            ProfileTile(
              icon: Icons.badge_outlined,
              label: l10n.documents,
              badge: StatusChip(
                label: switch (docStatus) {
                  VerificationStatus.approved => l10n.docStatusApproved,
                  VerificationStatus.pending => l10n.docStatusPending,
                  VerificationStatus.rejected => l10n.docStatusRejected,
                  VerificationStatus.notUploaded => l10n.documentsApprovedCount(
                    profile?.uploadedDocumentCount ?? 0,
                    DocumentType.values.length,
                  ),
                },
                tone: switch (docStatus) {
                  VerificationStatus.approved => ChipTone.success,
                  VerificationStatus.pending => ChipTone.warning,
                  VerificationStatus.rejected => ChipTone.danger,
                  VerificationStatus.notUploaded => ChipTone.neutral,
                },
                dense: true,
              ),
              onTap: () => context.push(Routes.documents),
            ),
          ],
        );
      },
    );
  }
}

/// Nudges a passenger with a few trips behind them towards the driver side.
///
/// Placed here rather than on the search screen deliberately: it should read as
/// an offer to someone who already trusts the product, not as a banner in the
/// way of what they came to do. The wording leads with the money, because that
/// is the honest reason — the trip is happening anyway, the seats are empty
/// anyway, and we take no commission on filling them.
class _BecomeDriverCard extends StatelessWidget {
  const _BecomeDriverCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: Sizes.avatarSm + 8,
            height: Sizes.avatarSm + 8,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(
              Icons.directions_car_filled_outlined,
              color: context.colors.primary,
              size: 22,
            ),
          ),
          HGap.lg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.becomeDriverTitle, style: context.text.titleSmall),
                VGap.xs,
                Text(
                  l10n.becomeDriverBody,
                  style: context.text.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: palette.textTertiary),
        ],
      ),
    );
  }
}
