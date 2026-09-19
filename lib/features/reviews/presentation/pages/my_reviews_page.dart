import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/route_timeline.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/domain/repositories/booking_repository.dart';
import '../../../bookings/presentation/bloc/bookings_list/bookings_list_bloc.dart';
import '../../../profile/domain/entities/user_enums.dart';
import '../../../profile/domain/repositories/user_repository.dart';
import '../../../profile/presentation/bloc/public_profile/public_profile_bloc.dart';
import '../../domain/repositories/review_repository.dart';
import '../widgets/review_list.dart';

/// The signed-in user's own reviews, plus the trips still waiting to be rated.
///
/// The reviews come from `GET /users/{me}/reviews` — the same endpoint another
/// person's profile uses. There is no "pending reviews" endpoint, so the strip
/// at the top is derived from completed bookings that still owe one.
class MyReviewsPage extends StatelessWidget {
  const MyReviewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.select<SessionBloc, int?>(
      (bloc) => bloc.state.userId,
    );
    if (userId == null) return const LoadingState();

    return MultiBlocProvider(
      providers: [
        BlocProvider<PublicProfileBloc>(
          create: (context) => PublicProfileBloc(
            users: context.read<UserRepository>(),
            reviews: context.read<ReviewRepository>(),
          )..add(PublicProfileRequested(userId)),
        ),
        BlocProvider<BookingsListBloc>(
          create: (context) =>
              BookingsListBloc(bookings: context.read<BookingRepository>())
                ..add(const BookingsListFilterChanged(BookingStatus.completed)),
        ),
      ],
      child: const _MyReviewsView(),
    );
  }
}

class _MyReviewsView extends StatelessWidget {
  const _MyReviewsView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        title: l10n.reviews,
        appBarBottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.sm),
            child: TabBar(
              onTap: (index) => context.read<PublicProfileBloc>().add(
                PublicProfileRoleChanged(
                  index == 0 ? UserMode.driver : UserMode.passenger,
                ),
              ),
              tabs: [
                Tab(text: l10n.reviewsAsDriver),
                Tab(text: l10n.reviewsAsPassenger),
              ],
            ),
          ),
        ),
        body: const Column(
          children: [
            _PendingStrip(),
            Expanded(child: TabBarView(children: [ReviewList(), ReviewList()])),
          ],
        ),
      ),
    );
  }
}

/// Completed trips the user still owes a review for.
class _PendingStrip extends StatelessWidget {
  const _PendingStrip();

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;

    return BlocBuilder<BookingsListBloc, BookingsListState>(
      builder: (context, state) {
        final pending = state.bookings
            .where((booking) => booking.needsMyReview)
            .toList(growable: false);
        if (pending.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 118,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.lg,
              Gap.page,
              Gap.md,
            ),
            itemCount: pending.length,
            itemBuilder: (context, index) {
              final booking = pending[index];
              final target = booking.counterpart;

              return Padding(
                padding: const EdgeInsets.only(right: Gap.md),
                child: SizedBox(
                  width: 230,
                  child: AppCard(
                    padding: const EdgeInsets.all(Gap.md),
                    onTap: () => context.push(Routes.writeReview(booking.id)),
                    child: Row(
                      children: [
                        AppAvatar(
                          name: target?.fullName,
                          photoUrl: target?.photoUrl,
                          size: Sizes.avatarMd,
                        ),
                        HGap.md,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                fmt.shortName(target?.fullName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              RouteLabel(
                                fromCity: booking.ride.fromCity,
                                toCity: booking.ride.toCity,
                                style: context.text.bodySmall,
                                iconSize: 12,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: List.generate(
                                  5,
                                  (_) => Icon(
                                    Icons.star_outline_rounded,
                                    size: 14,
                                    color: context.palette.borderStrong,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
