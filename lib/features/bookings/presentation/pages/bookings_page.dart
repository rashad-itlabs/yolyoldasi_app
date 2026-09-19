import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../rides/presentation/ride_search_navigation.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';
import '../bloc/bookings_list/bookings_list_bloc.dart';
import '../widgets/booking_cancel_sheet.dart';
import '../widgets/booking_card.dart';

/// "My bookings" for a passenger, "Requests" for a driver — same screen over
/// the two collections in API.md §10 (`GET /bookings` versus
/// `GET /bookings/incoming`).
///
/// The active mode only picks which one opens first. Someone who drives is
/// also a passenger, and their own confirmed seat is not something they should
/// have to flip the whole app over to find, so the two are a switch away.
class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final asDriver = context.select<SessionBloc, bool>(
      (bloc) => bloc.state.isDriverMode,
    );

    return BlocProvider<BookingsListBloc>(
      // Keyed on the mode so flipping sides reopens the collection that mode
      // leads with, rather than leaving the previous list on screen.
      key: ValueKey(asDriver),
      create: (context) => BookingsListBloc(
        bookings: context.read<BookingRepository>(),
        scope: asDriver ? BookingScope.incoming : BookingScope.mine,
      )..add(const BookingsListRequested()),
      child: const _BookingsView(),
    );
  }
}

class _BookingsView extends StatefulWidget {
  const _BookingsView();

  @override
  State<_BookingsView> createState() => _BookingsViewState();
}

class _BookingsViewState extends State<_BookingsView> {
  bool _wasVisible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // go_router keeps every shell branch mounted and wraps the inactive ones
    // in a disabled `TickerMode`, so this is how a tab learns it is back on
    // screen. Without it the list stays whatever was loaded the first time the
    // tab was opened, and a booking confirmed since then never turns up.
    final visible = TickerMode.of(context);
    if (visible && !_wasVisible) {
      context.read<BookingsListBloc>().add(
        const BookingsListRequested(refresh: true),
      );
    }
    _wasVisible = visible;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Both collections are worth reaching for anyone who drives; a passenger
    // with no car has nothing to switch to.
    final canSwitch = context.select<SessionBloc, bool>(
      (bloc) => bloc.state.hasDriverProfile,
    );
    final scope = context.select<BookingsListBloc, BookingScope>(
      (bloc) => bloc.state.scope,
    );
    final asDriver = scope.isIncoming;

    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        title: asDriver ? l10n.bookingRequests : l10n.myBookings,
        showBackButton: false,
        appBarBottom: PreferredSize(
          preferredSize: Size.fromHeight(canSwitch ? 104 : 50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canSwitch) ...[
                  AppSegmented<BookingScope>(
                    value: scope,
                    options: [
                      (
                        value: BookingScope.mine,
                        label: l10n.navBookings,
                        icon: null,
                      ),
                      (
                        value: BookingScope.incoming,
                        label: l10n.navRequests,
                        icon: null,
                      ),
                    ],
                    onChanged: (next) => context.read<BookingsListBloc>().add(
                      BookingsListScopeChanged(next),
                    ),
                  ),
                  VGap.sm,
                ],
                TabBar(
                  tabs: [
                    Tab(text: l10n.upcoming),
                    Tab(text: l10n.history),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: BlocListener<BookingsListBloc, BookingsListState>(
          listenWhen: (previous, current) =>
              previous.actionStatus != current.actionStatus,
          listener: (context, state) {
            final failure = state.failure;
            if (state.actionStatus.isFailure && failure != null) {
              AppFeedback.error(context, failure.message(l10n));
              return;
            }
            // A cancelled card leaves this tab for the history one, so without
            // a word the row would simply disappear. Keyed on the action, since
            // block and unblock leave the status untouched.
            if (state.actionStatus.isSuccess) {
              AppFeedback.success(context, switch (state.lastAction) {
                BookingAction.confirm => l10n.bookingConfirmedMsg,
                BookingAction.reject => l10n.bookingRejectedMsg,
                BookingAction.block => l10n.passengerBlockedMsg,
                BookingAction.unblock => l10n.passengerUnblockedMsg,
                _ => l10n.bookingCancelled,
              });
            }
          },
          child: TabBarView(
            children: [
              _BookingList(asDriver: asDriver, upcoming: true),
              _BookingList(asDriver: asDriver, upcoming: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({required this.asDriver, required this.upcoming});

  final bool asDriver;
  final bool upcoming;

  /// The row under a card, if that booking is waiting on the user for anything.
  Widget? _actionsFor(Booking booking, BookingsListState state) {
    if (booking.canDriverDecide) {
      return _DriverDecisionRow(
        booking: booking,
        isBusy: state.isBusy(booking.id),
      );
    }
    // A completed trip owes a review from both sides, and the history tab is
    // where the user goes looking for it — asking them to open the booking to
    // find the same button is how a review never gets written.
    if (booking.needsMyReview) return _RateRow(bookingId: booking.id);

    // A passenger who cancels can come back by default, so the driver's answer
    // belongs on the card they see it on — not two screens away.
    if (asDriver &&
        (booking.canBlockPassenger || booking.canUnblockPassenger)) {
      return _BlockPassengerRow(
        booking: booking,
        isBusy: state.isBusy(booking.id),
      );
    }

    if (!asDriver) {
      // Plans change, and a cheaper ride turns up. Making the passenger open
      // the booking first only delays a cancellation the driver would rather
      // hear about early, while the seat can still be resold.
      if (booking.canCancel) {
        return _PassengerCancelRow(
          booking: booking,
          isBusy: state.isBusy(booking.id),
        );
      }
      // They cancelled and the ride still has room — the seat is one tap away
      // again (API.md §10).
      if (booking.canRebookSameRide) {
        return _RebookRow(booking: booking);
      }
      // The driver decided, so this ride will not take a second request. The
      // card offers the same route instead.
      if (booking.needsAnotherRide) {
        return _FindAnotherRideRow(booking: booking);
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<BookingsListBloc, BookingsListState>(
      builder: (context, state) {
        final bloc = context.read<BookingsListBloc>();

        if (state.status.isFirstLoad) return const ListSkeleton(count: 3);
        if (state.status.isFailure) {
          return ErrorState(
            failure: state.failure,
            onRetry: () => bloc.add(const BookingsListRequested()),
          );
        }

        // `GET /bookings` has no "upcoming" filter, so the split between the
        // two tabs is made here, over what has been loaded.
        final visible = state.bookings
            .where((booking) {
              final isUpcoming =
                  booking.status.isActive &&
                  !booking.ride.departureAt.isBefore(
                    DateTime.now().subtract(const Duration(hours: 6)),
                  );
              return upcoming ? isUpcoming : !isUpcoming;
            })
            .toList(growable: false);

        if (visible.isEmpty) {
          return EmptyState(
            icon: asDriver
                ? Icons.inbox_rounded
                : Icons.confirmation_number_outlined,
            title: asDriver ? l10n.noRequestsYet : l10n.noBookingsYet,
            message: upcoming
                ? (asDriver ? l10n.noRequestsYetBody : l10n.noBookingsYetBody)
                : null,
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              bloc.add(const BookingsListRequested(refresh: true)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.lg,
              Gap.page,
              Gap.xxxl,
            ),
            itemCount: visible.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => VGap.md,
            itemBuilder: (context, index) {
              if (index == visible.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.lg),
                  child: AppButton.ghost(
                    label: l10n.loadMore,
                    onPressed: () =>
                        bloc.add(const BookingsListMoreRequested()),
                  ),
                );
              }

              final booking = visible[index];
              return BookingCard(
                booking: booking,
                asDriver: asDriver,
                onTap: () => context.push(Routes.bookingDetail(booking.id)),
                actions: _actionsFor(booking, state),
              );
            },
          ),
        );
      },
    );
  }
}

/// "Rate the trip" on a completed booking the user still owes a review for.
class _RateRow extends StatelessWidget {
  const _RateRow({required this.bookingId});

  final int bookingId;

  @override
  Widget build(BuildContext context) {
    return AppButton.tonal(
      label: context.l10n.rateTrip,
      icon: Icons.star_rounded,
      size: AppButtonSize.compact,
      onPressed: () => context.push(Routes.writeReview(bookingId)),
    );
  }
}

/// "Cancel booking" on an upcoming booking the passenger still holds.
class _PassengerCancelRow extends StatelessWidget {
  const _PassengerCancelRow({required this.booking, required this.isBusy});

  final Booking booking;
  final bool isBusy;

  Future<void> _cancel(BuildContext context) async {
    final bloc = context.read<BookingsListBloc>();

    final reason = await BookingCancelSheet.show(
      context,
      asDriver: false,
      isLate: booking.isLateCancellation,
    );
    if (reason == null) return;

    bloc.add(BookingCancelled(booking.id, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    return AppButton.secondary(
      label: context.l10n.cancelBooking,
      size: AppButtonSize.compact,
      isLoading: isBusy,
      onPressed: () => _cancel(context),
    );
  }
}

/// The driver's answer to a cancellation: shut this ride to that passenger, or
/// let them back in.
class _BlockPassengerRow extends StatelessWidget {
  const _BlockPassengerRow({required this.booking, required this.isBusy});

  final Booking booking;
  final bool isBusy;

  Future<void> _block(BuildContext context) async {
    final l10n = context.l10n;
    final bloc = context.read<BookingsListBloc>();

    final confirmed = await AppFeedback.confirm(
      context,
      title: l10n.blockPassenger,
      message: l10n.blockPassengerConfirm,
      confirmLabel: l10n.blockPassenger,
      cancelLabel: l10n.close,
      isDestructive: true,
    );
    if (!confirmed) return;

    bloc.add(BookingPassengerBlockChanged(booking.id, blocked: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (!booking.passengerBlocked) {
      return AppButton.secondary(
        label: l10n.blockPassenger,
        icon: Icons.block_rounded,
        size: AppButtonSize.compact,
        isLoading: isBusy,
        onPressed: () => _block(context),
      );
    }

    return Row(
      children: [
        Icon(
          Icons.block_rounded,
          size: 16,
          color: context.palette.textTertiary,
        ),
        HGap.sm,
        Expanded(
          child: Text(l10n.passengerBlocked, style: context.text.bodySmall),
        ),
        HGap.md,
        AppButton.ghost(
          label: l10n.unblockPassenger,
          isLoading: isBusy,
          onPressed: () => context.read<BookingsListBloc>().add(
            BookingPassengerBlockChanged(booking.id, blocked: false),
          ),
        ),
      ],
    );
  }
}

/// Back into a ride the passenger cancelled themselves.
///
/// It opens the ride rather than the request sheet: the seat count carried by
/// the booking is a snapshot, and `GET /rides/{id}` is what settles whether
/// there is still room.
class _RebookRow extends StatelessWidget {
  const _RebookRow({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return AppButton.tonal(
      label: context.l10n.rebookSameRide,
      icon: Icons.replay_rounded,
      size: AppButtonSize.compact,
      onPressed: () => context.push(Routes.rideDetail(booking.ride.id)),
    );
  }
}

/// The way on from a booking that fell through — the same route, cheapest
/// first. See [searchSameRoute].
class _FindAnotherRideRow extends StatelessWidget {
  const _FindAnotherRideRow({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return AppButton.tonal(
      label: context.l10n.findAnotherRide,
      icon: Icons.travel_explore_rounded,
      size: AppButtonSize.compact,
      onPressed: () =>
          searchSameRoute(context, booking.ride, seats: booking.seats),
    );
  }
}

/// Accept / decline buttons on a pending request.
class _DriverDecisionRow extends StatelessWidget {
  const _DriverDecisionRow({required this.booking, required this.isBusy});

  final Booking booking;
  final bool isBusy;

  Future<void> _decide(BuildContext context, {required bool accept}) async {
    final l10n = context.l10n;
    final bloc = context.read<BookingsListBloc>();

    if (!accept) {
      final confirmed = await AppFeedback.confirm(
        context,
        title: l10n.rejectBooking,
        message: l10n.cancelBookingConfirm,
        confirmLabel: l10n.reject,
        isDestructive: true,
      );
      if (!confirmed) return;
    }

    bloc.add(
      accept ? BookingConfirmed(booking.id) : BookingRejected(booking.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: AppButton.secondary(
            label: l10n.reject,
            size: AppButtonSize.compact,
            onPressed: isBusy ? null : () => _decide(context, accept: false),
          ),
        ),
        HGap.md,
        Expanded(
          flex: 2,
          child: AppButton(
            label: l10n.confirmBooking,
            size: AppButtonSize.compact,
            isLoading: isBusy,
            onPressed: () => _decide(context, accept: true),
          ),
        ),
      ],
    );
  }
}
