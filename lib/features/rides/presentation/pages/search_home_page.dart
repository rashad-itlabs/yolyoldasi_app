import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/route_timeline.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/domain/repositories/booking_repository.dart';
import '../../../bookings/presentation/bloc/bookings_list/bookings_list_bloc.dart';
import '../../../shell/presentation/bloc/badges/badges_bloc.dart';
import '../../domain/entities/recent_search.dart';
import '../../domain/repositories/ride_repository.dart';
import '../bloc/recent_searches/recent_searches_bloc.dart';
import '../bloc/ride_browse/ride_browse_bloc.dart';
import '../bloc/ride_search/ride_search_bloc.dart';
import '../widgets/ride_card.dart';
import '../widgets/search_form_card.dart';

/// The passenger home: search first, then shortcuts back into trips the user
/// already has.
class SearchHomePage extends StatelessWidget {
  const SearchHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // The "next trip" card is the only consumer of this list, so it gets
        // its own short-lived bloc rather than sharing the bookings tab's.
        BlocProvider<BookingsListBloc>(
          create: (context) =>
              BookingsListBloc(bookings: context.read<BookingRepository>())
                ..add(const BookingsListFilterChanged(BookingStatus.confirmed)),
        ),
        // Scoped to this screen as well: the browse list is always the same
        // query, so there is nothing to keep alive between visits.
        BlocProvider<RideBrowseBloc>(
          create: (context) =>
              RideBrowseBloc(rides: context.read<RideRepository>())
                ..add(const RideBrowseRequested()),
        ),
      ],
      child: const _SearchHomeView(),
    );
  }
}

class _SearchHomeView extends StatefulWidget {
  const _SearchHomeView();

  @override
  State<_SearchHomeView> createState() => _SearchHomeViewState();
}

class _SearchHomeViewState extends State<_SearchHomeView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    context.read<RecentSearchesBloc>().add(const RecentSearchesRequested());
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Pages in the next 20 active rides a screen before the list runs out.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 600) {
      context.read<RideBrowseBloc>().add(const RideBrowseMoreRequested());
    }
  }

  Future<void> _refresh() async {
    context.read<RecentSearchesBloc>().add(const RecentSearchesRequested());
    context.read<BookingsListBloc>().add(
      const BookingsListRequested(refresh: true),
    );
    context.read<RideBrowseBloc>().add(
      const RideBrowseRequested(refresh: true),
    );
    context.read<BadgesBloc>().add(const BadgesRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;

    // A record so one `select` covers both and the header still only rebuilds
    // when the identity actually changes.
    final user = context.select<SessionBloc, ({String? name, String? photo})>(
      (bloc) =>
          (name: bloc.state.user?.fullName, photo: bloc.state.user?.photoUrl),
    );
    final unread = context.select<BadgesBloc, int>(
      (bloc) => bloc.state.unreadNotifications,
    );
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The strip behind the status bar is the hero's own deep end, at rest
      // and scrolled alike, so the clock and the battery are white either way.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              // This screen has no app bar, so without something pinned here
              // the ride cards scroll up underneath the status bar and the
              // clock ends up sitting on top of them.
              if (topInset > 0)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StatusBarScrim(
                    height: topInset,
                    color: context.palette.passengerHero.first,
                  ),
                ),

              // ----------------------------------------------------- header
              SliverToBoxAdapter(
                child: _Hero(
                  name: user.name,
                  photoUrl: user.photo,
                  greeting: user.name == null || user.name!.isEmpty
                      ? l10n.appName
                      : l10n.greeting(fmt.shortName(user.name)),
                  unread: unread,
                ),
              ),

              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  Gap.page + context.columnInset,
                  Gap.xxl,
                  Gap.page + context.columnInset,
                  0,
                ),
                // Publishing belongs to driver mode, and the mode is fixed at
                // sign-in, so there is no "offer a ride" shortcut here.
                sliver: SliverList.list(
                  children: const [_NextTripCard(), _RecentSearches()],
                ),
              ),

              const _ActiveRides(),
            ],
          ),
        ),
      ),
    );
  }
}

/// An opaque strip pinned behind the status bar.
///
/// It is a single flat colour, and that is the whole trick: [_Hero]'s gradient
/// runs straight down and its top bloom starts at the top edge, so the header's
/// first row is exactly this colour on every screen size. The two meet with no
/// seam at rest, and once the page scrolls this is what the content passes
/// behind instead of sliding under the clock.
///
/// The header's drop shadow is this colour too, so the part of it that falls
/// across the strip composites away to nothing.
class _StatusBarScrim extends SliverPersistentHeaderDelegate {
  const _StatusBarScrim({required this.height, required this.color});

  final double height;

  /// [AppPalette.passengerHero]'s first stop — the header's top row.
  final Color color;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(color: color, child: const SizedBox.expand());

  @override
  bool shouldRebuild(_StatusBarScrim old) =>
      old.height != height || old.color != color;
}

/// The coloured block the home screen opens with: greeting, the one question
/// the app exists to answer, and the search form.
///
/// Three things keep a block this large from reading as flat paint — a
/// three-stop gradient rather than a straight ramp, two soft light blooms
/// behind the content, and a shadow tinted with the gradient's own deep end so
/// the header sits *over* the page instead of being glued to it.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.name,
    required this.photoUrl,
    required this.greeting,
    required this.unread,
  });

  final String? name;
  final String? photoUrl;
  final String greeting;
  final int unread;

  /// Both blooms bleed off a side so only their soft part shows; the header
  /// clips the rest.
  static const double _bloomTop = 230;
  static const double _bloomBottom = 280;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Vertical, not diagonal, and deliberately so: it makes the header's
        // topmost row a single flat colour, which is the one thing that lets
        // [_StatusBarScrim] above it match exactly at any screen size. The
        // asymmetry a diagonal would have given is carried by the blooms.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.passengerHero,
        ),
        // Rounded off at the bottom so the header reads as a card the page
        // sits under, rather than a block of colour cut across.
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(Radii.xxl),
        ),
        boxShadow: [
          BoxShadow(
            color: palette.passengerHero.first.withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Two blooms in different hues rather than two of the same white:
          // that is what separates an aurora from a spotlight.
          //
          // The top one sits flush with the top edge rather than over it. A
          // radial gradient is fully transparent at its boundary, so anchored
          // this way it contributes nothing to the header's first row and the
          // seam with the status bar stays invisible; it still bleeds off the
          // right.
          const Positioned(
            top: 0,
            right: -_bloomTop * 0.3,
            child: _Bloom(size: _bloomTop, opacity: 0.20),
          ),
          const Positioned(
            bottom: -_bloomBottom * 0.55,
            left: -_bloomBottom * 0.35,
            child: _Bloom(
              size: _bloomBottom,
              opacity: 0.16,
              color: Color(0xFFF08FD0),
            ),
          ),
          Padding(
            // No status-bar inset here: the pinned [_StatusBarScrim] above
            // this sliver already holds that space open.
            //
            // `columnInset` keeps the gradient full-bleed — which is the point
            // of the hero — while the greeting and the search card line up with
            // the column the rest of the app uses.
            padding: EdgeInsets.fromLTRB(
              Gap.page + context.columnInset,
              Gap.lg,
              Gap.page + context.columnInset,
              Gap.xl,
            ),
            child:
                Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Identity first, then the question, then the form: the eye
                        // gets a short row to land on before the headline.
                        Row(
                          children: [
                            AppAvatar(
                              name: name,
                              photoUrl: photoUrl,
                              size: Sizes.avatarMd,
                              borderColor: Colors.white.withValues(alpha: 0.35),
                              onTap: () => context.push(Routes.profile),
                            ),
                            HGap.md,
                            Expanded(
                              child: Text(
                                greeting,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            HGap.md,
                            _HeaderAction(
                              icon: Icons.notifications_none_rounded,
                              badge: unread,
                              onTap: () => context.push(Routes.notifications),
                            ),
                          ],
                        ),
                        VGap.xxl,
                        Text(
                          l10n.searchTitle,
                          style: context.text.displaySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        VGap.lg,
                        SearchFormCard(
                          // `GET /rides` records the search itself (API.md §9), so the
                          // chips only need re-reading once the results load.
                          onSearch: () {
                            context.read<RideSearchBloc>().add(
                              const RideSearchSubmitted(),
                            );
                            context.push(Routes.searchResults);
                          },
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(duration: Motion.normal)
                    .slideY(begin: -0.04, curve: Motion.emphasized),
          ),
        ],
      ),
    );
  }
}

/// A circle of colour fading to nothing — the light that stops the gradient
/// looking like a single coat of paint.
class _Bloom extends StatelessWidget {
  const _Bloom({
    required this.size,
    required this.opacity,
    this.color = Colors.white,
  });

  final double size;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// The passenger's next confirmed trip, if they have one.
class _NextTripCard extends StatelessWidget {
  const _NextTripCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;

    return BlocBuilder<BookingsListBloc, BookingsListState>(
      builder: (context, state) {
        if (!state.status.isSuccess) return const SizedBox.shrink();

        final upcoming =
            state.bookings.where((booking) => booking.isUpcoming).toList()
              ..sort(
                (a, b) => a.ride.departureAt.compareTo(b.ride.departureAt),
              );
        if (upcoming.isEmpty) return const SizedBox.shrink();

        final next = upcoming.first;
        final driver = next.driver;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: l10n.upcoming),
            AppCard(
              onTap: () => context.push(Routes.bookingDetail(next.id)),
              borderRadius: Radii.xlAll,
              child: Row(
                children: [
                  // Departure set apart the way a ticket sets it apart: it is
                  // the one thing the passenger opens this card to check.
                  _DepartureBlock(at: next.ride.departureAt),
                  HGap.lg,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RouteLabel(
                          fromCity: next.ride.fromCity,
                          toCity: next.ride.toCity,
                        ),
                        VGap.sm,
                        Row(
                          children: [
                            AppAvatar(
                              name: driver?.fullName ?? '',
                              photoUrl: driver?.photoUrl,
                              size: Sizes.avatarSm,
                            ),
                            HGap.sm,
                            Expanded(
                              child: Text(
                                fmt.shortName(driver?.fullName ?? ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  HGap.sm,
                  // The status chip that used to sit here always read
                  // "confirmed": the list behind this card is filtered to
                  // exactly that, so it never told the passenger anything.
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.textTertiary,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05),
            VGap.xxl,
          ],
        );
      },
    );
  }
}

/// Day over time, in a tinted block. Tabular figures so a column of these
/// would line up, and so the width does not jitter between 08:00 and 11:11.
class _DepartureBlock extends StatelessWidget {
  const _DepartureBlock({required this.at});

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fmt.dayLabel(at),
            style: context.text.labelSmall?.copyWith(
              color: colors.onPrimaryContainer,
            ),
          ),
          Text(
            fmt.time(at),
            style: context.text.titleMedium?.copyWith(
              color: colors.onPrimaryContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// `GET /me/recent-searches` — the last routes, as quick-repeat chips.
class _RecentSearches extends StatelessWidget {
  const _RecentSearches();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<RecentSearchesBloc, RecentSearchesState>(
      builder: (context, state) {
        if (!state.hasSearches) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: l10n.recentSearches,
              actionLabel: l10n.clear,
              onAction: () => context.read<RecentSearchesBloc>().add(
                const RecentSearchesCleared(),
              ),
            ),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final search in state.visible)
                  _RouteChip(
                    search: search,
                    onTap: () {
                      context.read<RideSearchBloc>().add(
                        RideSearchQueryReplaced(search.toQuery(), submit: true),
                      );
                      context.push(Routes.searchResults);
                    },
                  ),
              ],
            ),
            VGap.xxl,
          ],
        );
      },
    );
  }
}

/// `GET /rides` with no city, no date and no filters — every active listing.
///
/// This is the answer to "show me what is out there": a passenger who has not
/// picked a route yet still sees the rides drivers have published, and pages
/// through them by scrolling. Anything whose departure has passed is dropped by
/// `RideBrowseState.rides`, so the list never carries a trip nobody can take.
class _ActiveRides extends StatelessWidget {
  const _ActiveRides();

  /// Page padding, plus whatever it takes to sit inside the content column on
  /// a tablet — this sliver list is otherwise full-bleed.
  static EdgeInsets _sidesOf(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: Gap.page + context.columnInset);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<RideBrowseBloc, RideBrowseState>(
      builder: (context, state) {
        // A backend that still demands a route answers this query with a 422.
        // There is nothing the passenger can do about that and nothing to
        // retry, so the section stays out of the way entirely instead of
        // parking an error on the home screen.
        if (state.isUnsupported) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: _sidesOf(context),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(title: l10n.allActiveRides),
              ),
            ),
            _body(context, state),
            const SliverToBoxAdapter(child: SizedBox(height: Gap.xxxl)),
          ],
        );
      },
    );
  }

  Widget _body(BuildContext context, RideBrowseState state) {
    final l10n = context.l10n;
    final bloc = context.read<RideBrowseBloc>();

    if (state.status.isFirstLoad) {
      return SliverPadding(
        padding: _sidesOf(context),
        sliver: SliverList.list(
          children: const [
            RideCardSkeleton(),
            VGap.md,
            RideCardSkeleton(),
            VGap.md,
            RideCardSkeleton(),
          ],
        ),
      );
    }

    // A failed *first* page has nothing to show behind it; a failed next page
    // is reported by the footer instead, under the rides already listed.
    if (state.status.isFailure && state.page.isEmpty) {
      return SliverToBoxAdapter(
        child: ErrorState(
          failure: state.failure,
          compact: true,
          onRetry: () => bloc.add(const RideBrowseRequested()),
        ),
      );
    }

    final rides = state.rides;
    if (rides.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.directions_car_outlined,
          title: l10n.noActiveRides,
          message: l10n.noActiveRidesBody,
          compact: true,
        ),
      );
    }

    return SliverPadding(
      padding: _sidesOf(context),
      sliver: SliverList.builder(
        itemCount: rides.length + 1,
        itemBuilder: (context, index) {
          if (index == rides.length) return _Footer(state: state);

          final ride = rides[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child:
                RideCard(
                  ride: ride,
                  onTap: () => context.push(Routes.rideDetail(ride.id)),
                ).animate().fadeIn(
                  delay: Duration(milliseconds: 30 * index.clamp(0, 8)),
                  duration: 280.ms,
                ),
          );
        },
      ),
    );
  }
}

/// The last row of the browse list: a spinner while the next page loads, or
/// the reason it did not.
class _Footer extends StatelessWidget {
  const _Footer({required this.state});

  final RideBrowseState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Gap.lg),
        child: LoadingState(),
      );
    }

    final failure = state.failure;
    if (failure != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                failure.message(context.l10n),
                style: context.text.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            HGap.sm,
            TextButton(
              onPressed: () => context.read<RideBrowseBloc>().add(
                const RideBrowseMoreRequested(),
              ),
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );

    if (badge <= 0) return button;
    return Badge.count(
      count: badge,
      backgroundColor: context.palette.accent,
      textColor: context.palette.onAccent,
      offset: const Offset(-2, 2),
      child: button,
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.search, required this.onTap});

  final RecentSearch search;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final code = context.l10n.languageCode;

    return ActionChip(
      onPressed: onTap,
      avatar: Icon(
        Icons.history_rounded,
        size: 15,
        color: context.palette.textTertiary,
      ),
      label: Text(
        '${search.fromCity.nameFor(code)} → ${search.toCity.nameFor(code)}',
      ),
    );
  }
}
