import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/domain/repositories/booking_repository.dart';
import '../../../bookings/presentation/bloc/bookings_list/bookings_list_bloc.dart';
import '../../../reviews/domain/repositories/review_repository.dart';
import '../../../reviews/presentation/widgets/review_list.dart';
import '../../domain/repositories/user_repository.dart';
import '../bloc/public_profile/public_profile_bloc.dart';
import '../widgets/report_sheet.dart';

/// Somebody else's profile — what a passenger checks before booking.
///
/// `GET /users/{id}` plus their reviews. The API exposes no driver profile for
/// other people, so verification and vehicle details are not shown here; the
/// ride card carries the car that matters.
class PublicProfilePage extends StatelessWidget {
  const PublicProfilePage({super.key, required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionBloc>().state;
    final asDriver = session.isDriverMode;
    final isSignedIn = session.user != null;

    return MultiBlocProvider(
      providers: [
        BlocProvider<PublicProfileBloc>(
          create: (context) => PublicProfileBloc(
            users: context.read<UserRepository>(),
            reviews: context.read<ReviewRepository>(),
          )..add(PublicProfileRequested(userId)),
        ),
        // Completed trips with anybody, so the page can tell whether this
        // particular person is still owed a review. The scope follows the side
        // the viewer is on: a passenger's own bookings, a driver's incoming
        // ones.
        //
        // The bloc is always provided — the view below reads it — but it is
        // only asked to load for a signed-in viewer. This page is reachable
        // without an account now (API.md §18), and `GET /bookings` is not:
        // firing it anyway would spend a guaranteed 401 on every guest visit
        // to a driver's profile, for a list that can only ever be empty for
        // them.
        BlocProvider<BookingsListBloc>(
          create: (context) {
            final bloc = BookingsListBloc(
              bookings: context.read<BookingRepository>(),
              scope: asDriver ? BookingScope.incoming : BookingScope.mine,
            );

            if (isSignedIn) {
              bloc.add(
                const BookingsListFilterChanged(BookingStatus.completed),
              );
            }

            return bloc;
          },
        ),
      ],
      child: _PublicProfileView(userId: userId),
    );
  }
}

class _PublicProfileView extends StatelessWidget {
  const _PublicProfileView({required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final myId = context.select<SessionBloc, int?>((bloc) => bloc.state.userId);

    return AppScaffold(
      title: l10n.profile,
      actions: [
        if (myId != null && myId != userId)
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: l10n.reportUser,
            onPressed: () => ReportSheet.show(context, targetUserId: userId),
          ),
        HGap.sm,
      ],
      body: BlocBuilder<PublicProfileBloc, PublicProfileState>(
        builder: (context, state) {
          if (state.status.isFirstLoad) return const LoadingState();

          final user = state.user;
          if (user == null) {
            return ErrorState(
              failure: state.failure,
              message: state.failure == null ? l10n.errNotFound : null,
              onRetry: () => context.read<PublicProfileBloc>().add(
                PublicProfileRequested(userId),
              ),
            );
          }

          // One list rather than a tab bar over two: the split by role was a
          // filter on `GET /users/{id}/reviews`, and on somebody else's
          // profile the question is "what are they like", not "in which
          // seat". Without a role parameter the endpoint returns both.
          return ListView(
            padding: const EdgeInsets.only(bottom: Gap.xxxl),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.lg,
                  Gap.page,
                  0,
                ),
                child: Column(
                  children: [
                    AppAvatar(
                      name: user.fullName,
                      photoUrl: user.photoUrl,
                      size: Sizes.avatarXl,
                      isVerified: user.hasDriverProfile,
                    ),
                    VGap.lg,
                    Text(
                      fmt.shortName(user.fullName),
                      style: context.text.headlineSmall,
                    ),
                    VGap.sm,
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.sm,
                      alignment: WrapAlignment.center,
                      children: [
                        if (user.hasDriverProfile)
                          StatusChip(
                            // "Sürücü", not "Sürücü rejimi": a mode is
                            // something you switch yourself, and this is
                            // somebody else's profile.
                            label: l10n.driver,
                            tone: ChipTone.success,
                            icon: Icons.directions_car_filled,
                            dense: true,
                          ),
                        // Accounts are created against a verified phone
                        // number server-side (`phone_verified_at`).
                        StatusChip(
                          label: l10n.phoneVerified,
                          tone: ChipTone.brand,
                          icon: Icons.phone_android_rounded,
                          dense: true,
                        ),
                        if (user.age != null)
                          StatusChip(label: '${user.age}', dense: true),
                        if (user.city != null)
                          StatusChip(
                            label: user.city!.nameFor(l10n.languageCode),
                            icon: Icons.location_city_rounded,
                            dense: true,
                          ),
                      ],
                    ),
                    VGap.lg,
                    Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            value: fmt.rating(user.stats.overallRating),
                            label: l10n.rating,
                            icon: Icons.star_rounded,
                            highlight: true,
                          ),
                        ),
                        HGap.md,
                        Expanded(
                          child: _StatBox(
                            value: '${user.stats.totalTrips}',
                            label: l10n.completedTrips,
                            icon: Icons.route_rounded,
                          ),
                        ),
                        HGap.md,
                        Expanded(
                          child: _StatBox(
                            value:
                                '${user.stats.driverReviewCount + user.stats.passengerReviewCount}',
                            label: l10n.reviews,
                            icon: Icons.rate_review_outlined,
                          ),
                        ),
                      ],
                    ),
                    _ReviewCta(userId: userId),
                  ],
                ),
              ),
              const ReviewList(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "Rate the trip", but only when there is a trip to rate.
///
/// `POST /bookings/{id}/reviews` hangs off a booking, not off a person —
/// API.md §12 has the server work out who is reviewing whom from the booking
/// itself. So this looks for a completed trip with this person that still owes
/// the viewer's review, and carries that booking's id. No trip together, or
/// one already rated, and there is nothing to show.
class _ReviewCta extends StatelessWidget {
  const _ReviewCta({required this.userId});

  final int userId;

  /// Neither the stars on this page nor the button itself are the user's own
  /// state — both come from the API, and writing a review changes both. So the
  /// two reads behind them are repeated once the review screen closes, rather
  /// than leaving the profile quoting the rating it had a minute ago.
  Future<void> _rate(BuildContext context, int bookingId) async {
    final profile = context.read<PublicProfileBloc>();
    final bookings = context.read<BookingsListBloc>();

    await context.push(Routes.writeReview(bookingId));

    profile.add(PublicProfileRequested(userId));
    bookings.add(const BookingsListRequested(refresh: true));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookingsListBloc, BookingsListState>(
      builder: (context, state) {
        final owed = state.bookings
            .where(
              (booking) =>
                  booking.counterpart?.id == userId && booking.needsMyReview,
            )
            .toList(growable: false);
        if (owed.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: Gap.xl),
          child: AppButton.tonal(
            label: context.l10n.rateTrip,
            icon: Icons.star_rounded,
            onPressed: () => _rate(context, owed.first.id),
          ),
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.icon,
    this.highlight = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: Gap.md),
      elevated: false,
      color: palette.surfaceSunken,
      child: Column(
        children: [
          Icon(
            icon,
            size: 18,
            color: highlight ? palette.accent : palette.textSecondary,
          ),
          VGap.xs,
          Text(
            value,
            style: context.text.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
