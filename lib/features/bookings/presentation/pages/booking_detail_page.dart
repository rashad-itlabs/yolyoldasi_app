import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/route_timeline.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../profile/domain/entities/user_enums.dart';
import '../../../rides/presentation/ride_search_navigation.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';
import '../bloc/booking_detail/booking_detail_bloc.dart';
import '../widgets/booking_cancel_sheet.dart';
import '../widgets/booking_card.dart';

/// Everything about one booking, plus the actions available to whichever side
/// is looking at it.
class BookingDetailPage extends StatelessWidget {
  const BookingDetailPage({super.key, required this.bookingId});

  final int bookingId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BookingDetailBloc>(
      create: (context) =>
          BookingDetailBloc(bookings: context.read<BookingRepository>())
            ..add(BookingDetailRequested(bookingId)),
      child: const _BookingDetailView(),
    );
  }
}

class _BookingDetailView extends StatelessWidget {
  const _BookingDetailView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocConsumer<BookingDetailBloc, BookingDetailState>(
      listenWhen: (previous, current) =>
          previous.actionStatus != current.actionStatus ||
          previous.booking?.status != current.booking?.status,
      listener: (context, state) {
        final failure = state.failure;
        if (state.actionStatus.isFailure && failure != null) {
          AppFeedback.error(context, failure.message(l10n));
          return;
        }
        if (state.actionStatus.isSuccess) {
          // Keyed on the action, not the status: blocking and unblocking leave
          // the booking `cancelled_by_passenger` either way.
          AppFeedback.success(context, switch (state.lastAction) {
            BookingAction.confirm => l10n.bookingConfirmedMsg,
            BookingAction.reject => l10n.bookingRejectedMsg,
            BookingAction.block => l10n.passengerBlockedMsg,
            BookingAction.unblock => l10n.passengerUnblockedMsg,
            _ => l10n.bookingCancelled,
          });
        }
      },
      builder: (context, state) {
        final bloc = context.read<BookingDetailBloc>();

        return AppScaffold(
          title: l10n.bookingTitle,
          body: switch (state) {
            BookingDetailState(status: final s) when s.isFirstLoad =>
              const LoadingState(),
            BookingDetailState(booking: null) => ErrorState(
              failure: state.failure,
              onRetry: () =>
                  bloc.add(BookingDetailRequested(state.bookingId ?? 0)),
            ),
            _ => _Body(state: state),
          },
          bottomBar: state.booking == null ? null : _Actions(state: state),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final BookingDetailState state;

  Future<void> _call(BuildContext context, String phone) async {
    final uri = PhoneNumbers.dialUri(phone);
    if (!await launchUrl(uri)) {
      if (!context.mounted) return;
      AppFeedback.error(context, context.l10n.cannotCall);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;

    final booking = state.booking!;
    final isDriver = state.isDriver;
    final chip = bookingStatusChip(context, booking.status);
    final other = booking.counterpart;
    final otherRole = isDriver ? UserMode.passenger : UserMode.driver;

    // API.md §10: `contact_phone` is present only once the booking is
    // confirmed or completed, so its absence is the lock, not a missing field.
    final phone = booking.contactPhone;
    final canContact = booking.status.unlocksContact;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.xxxl),
      children: [
        // ------------------------------------------------------------ status
        AppCard(
          color: palette.surfaceSunken,
          elevated: false,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.bookingTitle, style: context.text.bodySmall),
                    VGap.xs,
                    Text(
                      l10n.seats(booking.seats),
                      style: context.text.titleMedium,
                    ),
                  ],
                ),
              ),
              StatusChip(label: chip.label, tone: chip.tone),
            ],
          ),
        ),
        VGap.md,

        // ------------------------------------------------------------- route
        AppCard(
          onTap: () => context.push(Routes.rideDetail(booking.ride.id)),
          child: Column(
            children: [
              RouteTimeline(
                fromCity: booking.ride.fromCity,
                toCity: booking.ride.toCity,
                departureAt: booking.ride.departureAt,
                pickupPoint: booking.ride.pickupPoint.isEmpty
                    ? null
                    : booking.ride.pickupPoint,
              ),
              VGap.lg,
              Divider(height: 1, color: palette.border),
              VGap.lg,
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.totalPrice,
                      style: context.text.bodyMedium,
                    ),
                  ),
                  Text(
                    fmt.price(booking.totalPrice),
                    style: context.text.titleMedium?.copyWith(
                      color: context.colors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ------------------------------------------------------------ person
        VGap.xxl,
        SectionHeader(title: isDriver ? l10n.passenger : l10n.driver),
        AppCard(
          onTap: other == null
              ? null
              : () => context.push(Routes.publicProfile(other.id)),
          child: Column(
            children: [
              Row(
                children: [
                  AppAvatar(
                    name: other?.fullName ?? '',
                    photoUrl: other?.photoUrl,
                    size: Sizes.avatarMd + 6,
                    isVerified: other?.hasDriverProfile ?? false,
                  ),
                  HGap.lg,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fmt.shortName(other?.fullName ?? ''),
                          style: context.text.titleMedium,
                        ),
                        VGap.xs,
                        RatingLabel(
                          rating: other?.ratingFor(otherRole) ?? 0,
                          reviewCount: other?.reviewCountFor(otherRole) ?? 0,
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
              VGap.lg,
              Divider(height: 1, color: palette.border),
              VGap.lg,
              Row(
                children: [
                  Icon(
                    canContact
                        ? Icons.phone_rounded
                        : Icons.lock_outline_rounded,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                  HGap.md,
                  Expanded(
                    child: Text(
                      phone == null
                          ? PhoneNumbers.masked('')
                          : PhoneNumbers.format(phone),
                      style: context.text.bodyLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (phone != null)
                    IconButton(
                      icon: const Icon(Icons.call_rounded),
                      color: context.colors.primary,
                      onPressed: () => _call(context, phone),
                    ),
                ],
              ),
              if (!canContact) ...[
                VGap.sm,
                Text(
                  l10n.phoneHiddenBody,
                  style: context.text.bodySmall?.copyWith(
                    color: palette.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),

        if (booking.message.isNotEmpty) ...[
          VGap.xxl,
          SectionHeader(title: l10n.messageToDriver),
          AppCard(
            color: palette.surfaceSunken,
            elevated: false,
            child: Text(booking.message, style: context.text.bodyLarge),
          ),
        ],

        if (booking.cancellationReason != null &&
            booking.cancellationReason!.isNotEmpty) ...[
          VGap.xxl,
          InfoBanner(
            tone: BannerTone.danger,
            // The same field carries both, so the heading follows the status
            // rather than always reading "declined".
            title: booking.status.isCancelled
                ? l10n.cancellationReasonTitle
                : l10n.rejectionReason,
            message: booking.cancellationReason!,
          ),
        ],

        // The driver's own copy of the veto, so it is visible from the booking
        // they used it on rather than only from the button that set it.
        if (isDriver && booking.passengerBlocked) ...[
          VGap.xxl,
          InfoBanner(
            tone: BannerTone.warning,
            icon: Icons.block_rounded,
            title: l10n.passengerBlocked,
            message: l10n.passengerBlockedBody,
          ),
        ],

        // Where the passenger stands now that the seat is gone: back in, if
        // they were the one who walked away, and out if the driver decided —
        // or if the seat simply went (API.md §10).
        if (booking.canRebookSameRide) ...[
          VGap.xxl,
          InfoBanner(
            tone: BannerTone.info,
            icon: Icons.replay_rounded,
            title: l10n.rebookSameRide,
            message: l10n.rebookSameRideBody,
          ),
        ] else if (booking.needsAnotherRide) ...[
          VGap.xxl,
          InfoBanner(
            tone: BannerTone.info,
            icon: booking.isClosedByDriver
                ? Icons.do_not_disturb_on_outlined
                : Icons.travel_explore_rounded,
            title: booking.isClosedByDriver
                ? l10n.rideClosedToYou
                : l10n.seatTakenAlready,
            message: booking.isClosedByDriver
                ? l10n.rideClosedToYouBody
                : l10n.seatTakenAlreadyBody,
          ),
        ],
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.state});

  final BookingDetailState state;

  Future<void> _cancel(BuildContext context) async {
    final booking = state.booking!;
    final bloc = context.read<BookingDetailBloc>();

    final reason = await BookingCancelSheet.show(
      context,
      asDriver: state.isDriver,
      isLate: booking.isLateCancellation,
    );
    if (reason == null) return;

    bloc.add(BookingDetailCancelled(reason: reason));
  }

  Future<void> _block(BuildContext context) async {
    final l10n = context.l10n;
    final bloc = context.read<BookingDetailBloc>();

    final confirmed = await AppFeedback.confirm(
      context,
      title: l10n.blockPassenger,
      message: l10n.blockPassengerConfirm,
      confirmLabel: l10n.blockPassenger,
      cancelLabel: l10n.close,
      isDestructive: true,
    );
    if (confirmed) bloc.add(const BookingDetailPassengerBlocked());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<BookingDetailBloc>();
    final booking = state.booking!;
    final busy = state.actionStatus.isInProgress;

    if (state.canDecide) {
      return BottomActionBar(
        secondary: AppButton.secondary(
          label: l10n.reject,
          onPressed: busy
              ? null
              : () => bloc.add(const BookingDetailRejected()),
        ),
        child: AppButton(
          label: l10n.confirmBooking,
          isLoading: busy,
          onPressed: () => bloc.add(const BookingDetailConfirmed()),
        ),
      );
    }

    if (state.needsReview) {
      return BottomActionBar(
        child: AppButton(
          label: l10n.rateTrip,
          icon: Icons.star_rounded,
          onPressed: () => context.push(Routes.writeReview(booking.id)),
        ),
      );
    }

    // The thread opens with the booking, so it is reachable before the driver
    // has decided (API.md §10) — the composer inside is what locks.
    final conversationId = state.conversationId;
    final chatButton = conversationId == null
        ? null
        : AppButton.tonal(
            label: l10n.sendMessage,
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: () => context.push(Routes.conversation(conversationId)),
          );

    // The driver's answer to a cancellation. It sits here rather than in the
    // body because it is a decision, and because the passenger's side of this
    // same screen is where the effect shows up.
    if (state.canBlockPassenger || state.canUnblockPassenger) {
      final blocked = booking.passengerBlocked;
      return BottomActionBar(
        secondary: chatButton,
        child: blocked
            ? AppButton.secondary(
                label: l10n.unblockPassenger,
                icon: Icons.lock_open_rounded,
                isLoading: busy,
                onPressed: () =>
                    bloc.add(const BookingDetailPassengerUnblocked()),
              )
            : AppButton.secondary(
                label: l10n.blockPassenger,
                icon: Icons.block_rounded,
                onPressed: busy ? null : () => _block(context),
              ),
      );
    }

    // Their own cancellation, and the ride still has room: the way back is the
    // ride screen rather than the sheet, because the seat count embedded here
    // is a snapshot and `GET /rides/{id}` is what settles it.
    if (booking.canRebookSameRide) {
      return BottomActionBar(
        secondary: AppButton.secondary(
          label: l10n.findAnotherRide,
          onPressed: () =>
              searchSameRoute(context, booking.ride, seats: booking.seats),
        ),
        child: AppButton(
          label: l10n.rebookSameRide,
          icon: Icons.replay_rounded,
          onPressed: () => context.push(Routes.rideDetail(booking.ride.id)),
        ),
      );
    }

    // The driver decided, with the departure still ahead: this ride is closed
    // to the passenger, so the bar becomes the way on to the alternatives
    // rather than an empty strip.
    if (booking.needsAnotherRide) {
      return BottomActionBar(
        // The thread is locked by now, but it is still where the two sides
        // agreed anything, so it stays reachable — just not as the main action.
        secondary: conversationId == null
            ? null
            : AppButton.secondary(
                label: l10n.sendMessage,
                onPressed: () =>
                    context.push(Routes.conversation(conversationId)),
              ),
        child: AppButton(
          label: l10n.findAnotherRide,
          icon: Icons.travel_explore_rounded,
          onPressed: () =>
              searchSameRoute(context, booking.ride, seats: booking.seats),
        ),
      );
    }

    if (!state.canCancel) {
      return chatButton == null
          ? const SizedBox.shrink()
          : BottomActionBar(child: chatButton);
    }

    return BottomActionBar(
      secondary: chatButton == null
          ? null
          : AppButton.secondary(
              label: l10n.cancelBooking,
              onPressed: busy ? null : () => _cancel(context),
            ),
      child:
          chatButton ??
          AppButton.secondary(
            label: l10n.cancelBooking,
            onPressed: busy ? null : () => _cancel(context),
          ),
    );
  }
}
