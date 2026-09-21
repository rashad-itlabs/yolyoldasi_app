import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/result.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/analytics.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../profile/domain/entities/user_enums.dart';
import '../../../profile/presentation/bloc/driver_profile/driver_profile_bloc.dart';
import '../../../shell/presentation/bloc/badges/badges_bloc.dart';
import '../../domain/entities/ride.dart';
import '../../domain/repositories/ride_repository.dart';
import '../bloc/my_rides/my_rides_bloc.dart';
import '../widgets/demand_strip.dart';
import '../widgets/ride_card.dart';

/// The driver home: their own listings, split into upcoming and past.
class MyRidesPage extends StatelessWidget {
  const MyRidesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MyRidesBloc>(
      create: (context) =>
          MyRidesBloc(rides: context.read<RideRepository>())
            ..add(const MyRidesRequested()),
      child: const _MyRidesView(),
    );
  }
}

class _MyRidesView extends StatelessWidget {
  const _MyRidesView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canPublish = context.select<DriverProfileBloc, bool>(
      (bloc) => bloc.state.canPublishRides,
    );
    final unread = context.select<BadgesBloc, int>(
      (bloc) => bloc.state.unreadNotifications,
    );

    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        title: l10n.myRides,
        showBackButton: false,
        actions: [
          Badge.count(
            count: unread,
            isLabelVisible: unread > 0,
            offset: const Offset(-4, 4),
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              tooltip: l10n.notifications,
              onPressed: () => context.push(Routes.notifications),
            ),
          ),
          HGap.sm,
        ],
        appBarBottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.sm),
            child: TabBar(
              tabs: [
                Tab(text: l10n.activeRides),
                Tab(text: l10n.pastRides),
              ],
            ),
          ),
        ),
        floatingActionButton: canPublish
            ? FloatingActionButton.extended(
                onPressed: () => context.push(Routes.publishRide),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.publishRideShort),
              )
            : null,
        body: BlocListener<MyRidesBloc, MyRidesState>(
          listenWhen: (previous, current) =>
              previous.actionStatus != current.actionStatus,
          listener: (context, state) {
            final failure = state.failure;
            if (state.actionStatus.isFailure && failure != null) {
              AppFeedback.error(context, failure.message(l10n));
            }
          },
          child: Column(
            children: [
              const _DriverStatusBanner(),
              const DemandStrip(),
              const Expanded(
                child: TabBarView(
                  children: [
                    _RidesList(includePast: false),
                    _RidesList(includePast: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tells the driver what is still outstanding: a car (which blocks publishing
/// outright) or document verification (which does not — see
/// [DriverProfile.canPublishRides]).
class _DriverStatusBanner extends StatelessWidget {
  const _DriverStatusBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<DriverProfileBloc, DriverProfileState>(
      builder: (context, state) {
        final profile = state.profile;
        if (profile == null) return const SizedBox.shrink();

        // Having no car at all is a different fix from having documents under
        // review, so the banner says which one is missing.
        if (!profile.hasVehicle) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, 0),
            child: InfoBanner(
              tone: BannerTone.warning,
              title: l10n.vehicleInfo,
              message: l10n.noVehicle,
              icon: Icons.directions_car_outlined,
              action: AppButton.ghost(
                label: l10n.saveVehicle,
                onPressed: () => context.push(Routes.vehicle),
              ),
            ),
          );
        }

        // Everything below is advisory: the driver can already publish.
        if (!profile.needsVerification) return const SizedBox.shrink();

        final (tone, title, message) = switch (profile.status) {
          VerificationStatus.pending => (
            BannerTone.info,
            l10n.verificationPending,
            l10n.verificationPendingBody,
          ),
          VerificationStatus.rejected => (
            BannerTone.danger,
            l10n.verificationRejected,
            l10n.verificationRejectedBody,
          ),
          _ => (
            BannerTone.warning,
            l10n.documentsTitle,
            l10n.documentsSubtitle,
          ),
        };

        return Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, 0),
          child: InfoBanner(
            tone: tone,
            title: title,
            message: message,
            icon: profile.status == VerificationStatus.pending
                ? Icons.hourglass_top_rounded
                : Icons.assignment_outlined,
            action: AppButton.ghost(
              label: profile.status == VerificationStatus.pending
                  ? l10n.documents
                  : l10n.uploadDocument,
              onPressed: () => context.push(Routes.documents),
            ),
          ),
        );
      },
    );
  }
}

class _RidesList extends StatelessWidget {
  const _RidesList({required this.includePast});

  final bool includePast;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<MyRidesBloc, MyRidesState>(
      builder: (context, state) {
        final bloc = context.read<MyRidesBloc>();

        if (state.status.isFirstLoad) return const ListSkeleton(count: 3);
        if (state.status.isFailure) {
          return ErrorState(
            failure: state.failure,
            onRetry: () => bloc.add(const MyRidesRequested()),
          );
        }

        // `GET /rides/mine` takes a single `status`, which cannot express
        // "upcoming versus past", so the split is made over what is loaded.
        final visible = state.rides
            .where((ride) {
              final isPast = ride.status.isFinished || ride.hasDeparted;
              return includePast ? isPast : !isPast;
            })
            .toList(growable: false);

        if (visible.isEmpty) {
          return EmptyState(
            icon: Icons.directions_car_outlined,
            title: l10n.noRidesYet,
            message: includePast ? null : l10n.noRidesYetBody,
            actionLabel: includePast ? null : l10n.publishRideShort,
            onAction: includePast
                ? null
                : () => context.push(Routes.publishRide),
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              bloc.add(const MyRidesRequested(refresh: true)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.lg,
              Gap.page,
              Gap.giant + Gap.xxl,
            ),
            itemCount: visible.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => VGap.md,
            itemBuilder: (context, index) {
              if (index == visible.length) {
                return AppButton.ghost(
                  label: l10n.loadMore,
                  onPressed: () => bloc.add(const MyRidesMoreRequested()),
                );
              }

              final ride = visible[index];
              return RideCard(
                ride: ride,
                showDriver: false,
                onTap: () => context.push(Routes.rideDetail(ride.id)),
                trailing: _RideActions(
                  ride: ride,
                  isBusy: state.isBusy(ride.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _RideActions extends StatelessWidget {
  const _RideActions({required this.ride, required this.isBusy});

  final Ride ride;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        StatusChip(
          label: switch (ride.status) {
            RideStatus.active => l10n.rideActive,
            RideStatus.inactive => l10n.rideInactive,
            RideStatus.completed => l10n.rideCompleted,
            RideStatus.cancelled => l10n.rideCancelled,
          },
          tone: switch (ride.status) {
            RideStatus.active => ChipTone.success,
            RideStatus.cancelled => ChipTone.danger,
            _ => ChipTone.neutral,
          },
          dense: true,
        ),
        const Spacer(),
        Text(
          '${ride.bookedSeats}/${ride.totalSeats}',
          style: context.text.labelMedium?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        if (isBusy)
          const Padding(
            padding: EdgeInsets.all(Gap.sm),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            visualDensity: VisualDensity.compact,
            onPressed: () => _manage(context),
          ),
      ],
    );
  }

  /// Re-publishes this ride on a date the driver picks.
  ///
  /// Nothing else is asked for: route, price, seats and conditions come from
  /// the original. The whole point is that the second listing costs two taps
  /// rather than the three-step form again.
  Future<void> _repeat(BuildContext context) async {
    final l10n = context.l10n;
    final rides = context.read<RideRepository>();
    final analytics = context.read<Analytics>();
    final bloc = context.read<MyRidesBloc>();
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      helpText: l10n.repeatRideTitle,
      // A week on from the original is the common case, and never in the past.
      initialDate: ride.departureAt.isAfter(now)
          ? ride.departureAt.add(const Duration(days: 7))
          : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;

    // The time of day is kept from the original: someone repeating a run does
    // it at the hour they always do.
    final departure = DateTime(
      date.year,
      date.month,
      date.day,
      ride.departureAt.hour,
      ride.departureAt.minute,
    );

    analytics.log(
      Ev.rideRepeated,
      params: {
        'ride_id': ride.id,
        'from_city_id': ride.fromCity.id,
        'to_city_id': ride.toCity.id,
      },
    );

    final result = await rides.repeat(ride.id, departure);
    if (!context.mounted) return;

    switch (result) {
      case Ok():
        AppFeedback.success(context, l10n.repeatCreated);
        bloc.add(const MyRidesRequested(refresh: true));
      case Err(:final failure):
        AppFeedback.error(context, failure.message(l10n));
    }
  }

  Future<void> _manage(BuildContext context) async {
    final l10n = context.l10n;
    final bloc = context.read<MyRidesBloc>();

    await AppFeedback.sheet<void>(
      context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ride.status.isEditable)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.editRide),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push(Routes.rideEdit(ride.id));
                },
              ),
            // Available on finished rides too — in fact especially there. The
            // weekly run is the one worth repeating, and by the time the
            // driver thinks of it the last one is already in the past tab.
            ListTile(
              leading: const Icon(Icons.repeat_rounded),
              title: Text(l10n.repeatRide),
              subtitle: Text(l10n.repeatRideBody),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _repeat(context);
              },
            ),
            if (ride.status.isActive || ride.status == RideStatus.inactive)
              ListTile(
                leading: Icon(
                  ride.status.isActive
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                title: Text(
                  ride.status.isActive
                      ? l10n.deactivateRide
                      : l10n.activateRide,
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  bloc.add(
                    MyRideStatusToggled(
                      rideId: ride.id,
                      status: ride.status.isActive
                          ? RideStatus.inactive
                          : RideStatus.active,
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: Text(l10n.bookingRequests),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(Routes.rideBookings(ride.id));
              },
            ),
            if (ride.canBeCompleted)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.markCompleted),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  bloc.add(MyRideCompleted(ride.id));
                },
              ),
            if (!ride.status.isFinished)
              ListTile(
                leading: Icon(
                  Icons.cancel_outlined,
                  color: context.palette.danger,
                ),
                title: Text(
                  l10n.cancelRide,
                  style: TextStyle(color: context.palette.danger),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final confirmed = await AppFeedback.confirm(
                    context,
                    title: l10n.cancelRide,
                    message: l10n.cancelRideConfirm,
                    confirmLabel: l10n.cancelRide,
                    isDestructive: true,
                  );
                  if (confirmed) bloc.add(MyRideCancelled(ride.id));
                },
              ),
            VGap.md,
          ],
        ),
      ),
    );
  }
}
