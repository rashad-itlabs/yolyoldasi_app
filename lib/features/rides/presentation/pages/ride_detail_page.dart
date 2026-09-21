import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/analytics.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/route_timeline.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../bookings/presentation/widgets/booking_request_sheet.dart';
import '../../../profile/domain/entities/user_enums.dart';
import '../../domain/entities/ride.dart';
import '../../domain/repositories/ride_repository.dart';
import '../bloc/ride_detail/ride_detail_bloc.dart';

/// Everything a passenger needs before committing to a seat.
class RideDetailPage extends StatelessWidget {
  const RideDetailPage({super.key, required this.rideId});

  final int rideId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RideDetailBloc>(
      create: (context) =>
          RideDetailBloc(rides: context.read<RideRepository>())
            ..add(RideDetailRequested(rideId)),
      child: const _RideDetailView(),
    );
  }
}

class _RideDetailView extends StatelessWidget {
  const _RideDetailView();

  /// Hands the ride to whatever the phone can share with.
  ///
  /// The text carries the route, the time and the price so the message reads
  /// on its own in a group chat — a bare link is scrolled past.
  Future<void> _shareRide(BuildContext context, Ride ride) async {
    final l10n = context.l10n;
    final fmt = context.fmt;

    context.read<Analytics>().log(
      Ev.rideShared,
      params: {'ride_id': ride.id, 'is_mine': ride.isMine},
    );

    final text =
        '${ride.fromCity.name} → ${ride.toCity.name}\n'
        '${fmt.dayLabelWithTime(ride.departureAt)} · '
        '${fmt.price(ride.pricePerSeat)} ${l10n.perSeat}\n'
        '${ride.shareUrl}';

    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocConsumer<RideDetailBloc, RideDetailState>(
      listenWhen: (previous, current) =>
          previous.outcome != current.outcome ||
          (current.actionStatus.isFailure &&
              previous.actionStatus != current.actionStatus),
      listener: (context, state) {
        if (state.outcome != null) {
          AppFeedback.success(
            context,
            state.outcome == RideDetailOutcome.cancelled
                ? l10n.rideCancelled
                : l10n.rideCompleted,
          );
          return;
        }
        final failure = state.failure;
        if (failure != null) AppFeedback.error(context, failure.message(l10n));
      },
      builder: (context, state) {
        final bloc = context.read<RideDetailBloc>();

        return AppScaffold(
          title: l10n.rideDetails,
          actions: [
            // The cheapest distribution the product has. Intercity rides are
            // still arranged in WhatsApp and Telegram groups, and until now a
            // driver had nothing to paste into one.
            if (state.ride?.shareUrl != null)
              IconButton(
                icon: const Icon(Icons.ios_share_rounded),
                tooltip: l10n.shareRide,
                onPressed: () => _shareRide(context, state.ride!),
              ),
            if (state.canEdit)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.edit,
                onPressed: () => context.push(Routes.rideEdit(state.ride!.id)),
              ),
            if (state.isMine) _OwnerMenu(state: state),
          ],
          body: switch (state) {
            RideDetailState(status: final s) when s.isFirstLoad =>
              const LoadingState(),
            RideDetailState(ride: null) => ErrorState(
              failure: state.failure,
              onRetry: () => bloc.add(RideDetailRequested(state.rideId ?? 0)),
            ),
            _ => _Body(ride: state.ride!),
          },
          bottomBar: state.ride == null ? null : _RideActionBar(state: state),
        );
      },
    );
  }
}

/// Cancel / hide, folded into an overflow menu so the app bar stays calm.
class _OwnerMenu extends StatelessWidget {
  const _OwnerMenu({required this.state});

  final RideDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ride = state.ride;
    if (ride == null) return const SizedBox.shrink();

    return PopupMenuButton<VoidCallback>(
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        if (state.canToggleVisibility)
          PopupMenuItem(
            value: () => context.read<RideDetailBloc>().add(
              RideDetailStatusToggled(
                ride.status.isActive ? RideStatus.inactive : RideStatus.active,
              ),
            ),
            child: Text(
              ride.status.isActive ? l10n.rideInactive : l10n.rideActive,
            ),
          ),
        if (state.canComplete)
          PopupMenuItem(
            value: () =>
                context.read<RideDetailBloc>().add(const RideDetailCompleted()),
            child: Text(l10n.rideCompleted),
          ),
        if (state.canCancel)
          PopupMenuItem(
            value: () => _confirmCancel(context),
            child: Text(
              l10n.cancelRide,
              style: TextStyle(color: context.palette.danger),
            ),
          ),
      ],
    );
  }

  /// Cancelling also cancels every pending and confirmed booking and notifies
  /// the passengers (API.md §9), so it is always confirmed first.
  Future<void> _confirmCancel(BuildContext context) async {
    final l10n = context.l10n;
    final bloc = context.read<RideDetailBloc>();

    final confirmed = await AppFeedback.confirm(
      context,
      title: l10n.cancelRide,
      message: l10n.cancelRideConfirm,
      confirmLabel: l10n.cancelRide,
      isDestructive: true,
    );
    if (confirmed) bloc.add(const RideDetailCancelled());
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;
    final vehicle = ride.vehicle;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.xxxl),
      children: [
        // -------------------------------------------------------------- when
        Row(
          children: [
            Expanded(
              child: Text(
                fmt.dayLabelWithTime(ride.departureAt),
                style: context.text.headlineSmall,
              ),
            ),
            if (!ride.status.isActive)
              StatusChip(
                label: switch (ride.status) {
                  RideStatus.inactive => l10n.rideInactive,
                  RideStatus.completed => l10n.rideCompleted,
                  RideStatus.cancelled => l10n.rideCancelled,
                  RideStatus.active => l10n.rideActive,
                },
                tone: ride.status == RideStatus.cancelled
                    ? ChipTone.danger
                    : ChipTone.neutral,
              ),
          ],
        ),
        VGap.xl,

        // ------------------------------------------------------------- route
        AppCard(
          child: RouteTimeline(
            fromCity: ride.fromCity,
            toCity: ride.toCity,
            departureAt: ride.departureAt,
            arrivalAt: ride.estimatedArrival,
            pickupPoint: ride.pickupPoint.isEmpty ? null : ride.pickupPoint,
            dropoffPoint: ride.dropoffPoint.isEmpty ? null : ride.dropoffPoint,
          ),
        ),
        VGap.md,

        // ------------------------------------------------------------- facts
        Row(
          children: [
            Expanded(
              child: _FactTile(
                icon: Icons.event_seat_outlined,
                label: l10n.seatsAvailable,
                value: '${ride.seatsLeft}/${ride.totalSeats}',
              ),
            ),
            HGap.md,
            Expanded(
              child: _FactTile(
                icon: Icons.payments_outlined,
                label: l10n.pricePerSeat,
                value: fmt.price(ride.pricePerSeat),
                highlight: true,
              ),
            ),
          ],
        ),
        VGap.md,
        Row(
          children: [
            if (ride.distanceKm != null) ...[
              Expanded(
                child: _FactTile(
                  icon: Icons.straighten_rounded,
                  label: l10n.routeStep,
                  value: '≈ ${ride.distanceKm!.round()} km',
                ),
              ),
              HGap.md,
            ],
            Expanded(
              child: _FactTile(
                icon: ride.instantBooking
                    ? Icons.bolt_rounded
                    : Icons.how_to_reg_outlined,
                label: l10n.bookingTitle,
                value: ride.instantBooking
                    ? l10n.instantBooking
                    : l10n.requestBooking,
              ),
            ),
          ],
        ),

        // A condition, not a decoration: a passenger it excludes must find out
        // here rather than from a 422 after tapping the booking button.
        if (ride.womenOnly) ...[
          VGap.md,
          InfoBanner(tone: BannerTone.info, message: l10n.womenOnlyHint),
        ],

        // -------------------------------------------------------------- note
        if (ride.note.isNotEmpty) ...[
          VGap.xxl,
          SectionHeader(title: l10n.rideNote),
          AppCard(
            color: palette.surfaceSunken,
            elevated: false,
            child: Text(ride.note, style: context.text.bodyLarge),
          ),
        ],

        // ------------------------------------------------------------ driver
        VGap.xxl,
        SectionHeader(title: l10n.driver),
        AppCard(
          onTap: () => context.push(Routes.publicProfile(ride.driver.id)),
          child: Column(
            children: [
              Row(
                children: [
                  AppAvatar(
                    name: ride.driver.fullName,
                    photoUrl: ride.driver.photoUrl,
                    size: Sizes.avatarLg,
                    isVerified: ride.driver.hasDriverProfile,
                  ),
                  HGap.lg,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fmt.shortName(ride.driver.fullName),
                          style: context.text.titleMedium,
                        ),
                        VGap.xs,
                        RatingLabel(
                          rating: ride.driver.ratingFor(UserMode.driver),
                          reviewCount: ride.driver.reviewCountFor(
                            UserMode.driver,
                          ),
                        ),
                        if (ride.driver.tripCountFor(UserMode.driver) > 0) ...[
                          VGap.xs,
                          Text(
                            l10n.tripsCount(
                              ride.driver.tripCountFor(UserMode.driver),
                            ),
                            style: context.text.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.textTertiary,
                  ),
                ],
              ),
              if (vehicle != null) ...[
                VGap.lg,
                Divider(height: 1, color: palette.border),
                VGap.lg,
                Row(
                  children: [
                    Icon(
                      Icons.directions_car_filled_outlined,
                      size: 20,
                      color: palette.textSecondary,
                    ),
                    HGap.md,
                    Expanded(
                      child: Text(
                        vehicle.summary,
                        style: context.text.bodyLarge,
                      ),
                    ),
                    VehicleColorDot(colorValue: vehicle.color),
                    // API.md §9: the plate comes back only for the driver
                    // themselves, so its absence is expected, not a gap.
                    if (vehicle.plate != null) ...[
                      HGap.sm,
                      Text(
                        vehicle.plate!,
                        style: context.text.labelMedium?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (ride.isMine && vehicle.plate != null) ...[
                  VGap.sm,
                  Text(
                    l10n.plateVisibleToYou,
                    style: context.text.labelSmall?.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),

        VGap.xl,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, size: 15, color: palette.textTertiary),
            HGap.sm,
            Expanded(
              child: Text(
                l10n.phoneHiddenBody,
                style: context.text.bodySmall?.copyWith(
                  color: palette.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(Gap.md),
      elevated: false,
      color: palette.surfaceSunken,
      child: Row(
        children: [
          Icon(icon, size: 18, color: palette.textSecondary),
          HGap.md,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    color: palette.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    color: highlight
                        ? context.colors.primary
                        : palette.textPrimary,
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

/// Bottom bar whose contents depend on who is looking.
///
/// There is no "do I already have a booking on this ride" field on the ride
/// object, so the passenger's own state is not second-guessed here: the 409
/// from `POST /rides/{id}/bookings` is what reports a duplicate, and the
/// request sheet explains it.
class _RideActionBar extends StatelessWidget {
  const _RideActionBar({required this.state});

  final RideDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final ride = state.ride!;

    if (state.isMine) {
      return BottomActionBar(
        child: AppButton(
          label: l10n.bookingRequests,
          icon: Icons.people_alt_outlined,
          onPressed: () => context.push(Routes.rideBookings(ride.id)),
        ),
      );
    }

    // The driver's women-only condition is checked against *this* viewer, so
    // the button is shut before the tap rather than after a 422. The server
    // still has the final say (API.md §21) — this only keeps the passenger out
    // of a dead end.
    final viewerGender = context.select<SessionBloc, Gender?>(
      (bloc) => bloc.state.user?.gender,
    );

    // A guest got this far because browsing is open (API.md §18). Booking is
    // not, so the bar asks for an account at the moment they reach for it —
    // which is the only moment the ask is easy to say yes to.
    final isGuest = context.select<SessionBloc, bool>(
      (bloc) => bloc.state.user == null,
    );
    if (isGuest) {
      return BottomActionBar(
        child: AppButton(
          label: l10n.signInToBook,
          icon: Icons.login_rounded,
          onPressed: () => context.push(Routes.login),
        ),
      );
    }

    final canBook = ride.isBookableBy(viewerGender);
    final blockedByWomenOnly = ride.isBookable && !canBook;

    return BottomActionBar(
      caption: Row(
        children: [
          Expanded(
            child: Text(
              blockedByWomenOnly
                  ? l10n.womenOnlyBlocked
                  : canBook
                  ? l10n.seatsLeft(ride.seatsLeft)
                  : ride.isFull
                  ? l10n.rideFull
                  : l10n.errRideNotBookable,
              style: context.text.bodyMedium,
            ),
          ),
          Text(
            fmt.price(ride.pricePerSeat),
            style: context.text.titleMedium?.copyWith(
              color: context.colors.primary,
            ),
          ),
        ],
      ),
      child: AppButton(
        label: ride.instantBooking ? l10n.bookNow : l10n.bookSeat,
        icon: ride.instantBooking ? Icons.bolt_rounded : null,
        onPressed: canBook
            ? () async {
                final bookingId = await BookingRequestSheet.show(context, ride);
                if (bookingId == null || !context.mounted) return;
                AppFeedback.success(context, l10n.bookingSent);
                // The seat count has changed; re-read so the bar is honest if
                // the user comes back.
                context.read<RideDetailBloc>().add(
                  RideDetailRequested(ride.id),
                );
                context.push(Routes.bookingDetail(bookingId));
              }
            : null,
      ),
    );
  }
}
