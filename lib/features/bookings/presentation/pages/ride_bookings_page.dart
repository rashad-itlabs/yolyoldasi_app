import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../rides/domain/repositories/ride_repository.dart';
import '../../../rides/presentation/bloc/ride_detail/ride_detail_bloc.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';
import '../bloc/bookings_list/bookings_list_bloc.dart';
import '../widgets/booking_card.dart';

/// The passenger list for one of the driver's own rides, with the action that
/// closes the trip out.
///
/// There is no `GET /rides/{id}/bookings` in the API, so this reads
/// `/bookings/incoming` and narrows it to this ride — see
/// [BookingsListState.rideId]. "Load more" therefore pages through all
/// incoming bookings, not just this ride's.
class RideBookingsPage extends StatelessWidget {
  const RideBookingsPage({super.key, required this.rideId});

  final int rideId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<BookingsListBloc>(
          create: (context) => BookingsListBloc(
            bookings: context.read<BookingRepository>(),
            scope: BookingScope.incoming,
            rideId: rideId,
          )..add(const BookingsListRequested()),
        ),
        BlocProvider<RideDetailBloc>(
          create: (context) =>
              RideDetailBloc(rides: context.read<RideRepository>())
                ..add(RideDetailRequested(rideId)),
        ),
      ],
      child: const _RideBookingsView(),
    );
  }
}

class _RideBookingsView extends StatelessWidget {
  const _RideBookingsView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppScaffold(
      title: l10n.bookingRequests,
      body: MultiBlocListener(
        listeners: [
          BlocListener<BookingsListBloc, BookingsListState>(
            listenWhen: (previous, current) =>
                previous.actionStatus != current.actionStatus,
            listener: (context, state) {
              final failure = state.failure;
              if (state.actionStatus.isFailure && failure != null) {
                AppFeedback.error(context, failure.message(l10n));
              } else if (state.actionStatus.isSuccess) {
                AppFeedback.success(context, l10n.bookingConfirmedMsg);
              }
            },
          ),
          BlocListener<RideDetailBloc, RideDetailState>(
            listenWhen: (previous, current) =>
                previous.outcome != current.outcome && current.outcome != null,
            listener: (context, state) {
              AppFeedback.success(context, l10n.tripCompleted);
              // Completing the ride completes its confirmed bookings
              // (API.md §9), so the list is re-read rather than patched.
              context.read<BookingsListBloc>().add(
                const BookingsListRequested(refresh: true),
              );
            },
          ),
        ],
        child: const _Body(),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

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

        final bookings = state.bookings;
        if (bookings.isEmpty) {
          return EmptyState(
            icon: Icons.inbox_rounded,
            title: l10n.noRequestsYet,
            message: l10n.noRequestsYetBody,
          );
        }

        final active = bookings.where((b) => b.status.isActive).toList();
        final decided = bookings.where((b) => !b.status.isActive).toList();

        return Column(
          children: [
            const _RideSummary(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.lg,
                  Gap.page,
                  Gap.xxxl,
                ),
                children: [
                  for (final booking in active) ...[
                    BookingCard(
                      booking: booking,
                      asDriver: true,
                      onTap: () =>
                          context.push(Routes.bookingDetail(booking.id)),
                      actions: booking.canDriverDecide
                          ? _Decision(
                              booking: booking,
                              isBusy: state.isBusy(booking.id),
                            )
                          : null,
                    ),
                    VGap.md,
                  ],
                  if (decided.isNotEmpty) ...[
                    VGap.md,
                    SectionHeader(title: l10n.history),
                    for (final booking in decided) ...[
                      Opacity(
                        opacity: 0.7,
                        child: BookingCard(
                          booking: booking,
                          asDriver: true,
                          onTap: () =>
                              context.push(Routes.bookingDetail(booking.id)),
                        ),
                      ),
                      VGap.md,
                    ],
                  ],
                  if (state.hasMore)
                    AppButton.ghost(
                      label: l10n.loadMore,
                      onPressed: () =>
                          bloc.add(const BookingsListMoreRequested()),
                    ),
                ],
              ),
            ),
            const _CompleteBar(),
          ],
        );
      },
    );
  }
}

/// Seats and departure for the ride these bookings belong to.
class _RideSummary extends StatelessWidget {
  const _RideSummary();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RideDetailBloc, RideDetailState>(
      builder: (context, state) {
        final ride = state.ride;
        if (ride == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, 0),
          child: AppCard(
            color: context.palette.surfaceSunken,
            elevated: false,
            padding: const EdgeInsets.all(Gap.md),
            child: Row(
              children: [
                Icon(
                  Icons.event_seat_outlined,
                  size: 18,
                  color: context.palette.textSecondary,
                ),
                HGap.md,
                Expanded(
                  child: Text(
                    '${context.l10n.seatsBooked}: '
                    '${ride.bookedSeats}/${ride.totalSeats}',
                    style: context.text.bodyMedium,
                  ),
                ),
                Text(
                  context.fmt.dayDotTime(ride.departureAt),
                  style: context.text.labelMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// `POST /rides/{id}/complete`, offered once departure has passed.
class _CompleteBar extends StatelessWidget {
  const _CompleteBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RideDetailBloc, RideDetailState>(
      builder: (context, state) {
        if (!state.canComplete) return const SizedBox.shrink();

        return BottomActionBar(
          child: AppButton(
            label: context.l10n.markCompleted,
            icon: Icons.flag_rounded,
            isLoading: state.actionStatus.isInProgress,
            onPressed: () =>
                context.read<RideDetailBloc>().add(const RideDetailCompleted()),
          ),
        );
      },
    );
  }
}

class _Decision extends StatelessWidget {
  const _Decision({required this.booking, required this.isBusy});

  final Booking booking;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<BookingsListBloc>();

    return Row(
      children: [
        Expanded(
          child: AppButton.secondary(
            label: l10n.reject,
            size: AppButtonSize.compact,
            onPressed: isBusy
                ? null
                : () => bloc.add(BookingRejected(booking.id)),
          ),
        ),
        HGap.md,
        Expanded(
          flex: 2,
          child: AppButton(
            label: l10n.confirmBooking,
            size: AppButtonSize.compact,
            isLoading: isBusy,
            onPressed: () => bloc.add(BookingConfirmed(booking.id)),
          ),
        ),
      ],
    );
  }
}
