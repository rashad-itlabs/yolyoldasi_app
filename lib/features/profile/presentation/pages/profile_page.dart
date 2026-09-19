import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
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
/// The mode is fixed for the session — it is picked on the sign-in screen and
/// only shown here, so half the app never changes under the user mid-task.
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
                // Read-only: the pick belongs to the sign-in screen, so this
                // row says which half of the app is open, nothing more.
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
                    ),
                  ],
                ),

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
                    '${l10n.version} ${AppConfig.appVersion}',
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
