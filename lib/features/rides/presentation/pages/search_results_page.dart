import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/result.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/analytics.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/route_timeline.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../cities/domain/repositories/city_repository.dart';
import '../../../ride_requests/domain/entities/ride_request.dart';
import '../../../ride_requests/domain/repositories/ride_request_repository.dart';
import '../../../ride_requests/presentation/widgets/create_ride_request_sheet.dart';
import '../bloc/ride_search/ride_search_bloc.dart';
import '../widgets/ride_card.dart';
import '../widgets/search_filter_sheet.dart';

/// Results for the current query, with a date strip for quick day-hopping.
class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({super.key});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Pages in the next 20 results a screen before the list runs out.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 600) {
      context.read<RideSearchBloc>().add(const RideSearchMoreRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cities = context.read<CityRepository>();

    return BlocConsumer<RideSearchBloc, RideSearchState>(
      listenWhen: (previous, current) =>
          previous.status != current.status && current.status.isSuccess,
      listener: (context, state) {
        // The two numbers the funnel turns on: how often people search, and
        // how often we have nothing for them. The second is the one that
        // decides which corridor to go and find drivers in.
        final params = {
          'from_city_id': state.query.fromCityId,
          'to_city_id': state.query.toCityId,
          'seats': state.query.seats,
          'results': state.totalFound,
          'has_date': state.query.date != null,
        };

        final analytics = context.read<Analytics>();
        analytics.log(Ev.searchPerformed, params: params);
        if (state.rides.isEmpty) {
          analytics.log(Ev.searchEmpty, params: params);
        }
      },
      builder: (context, state) {
        final query = state.query;
        final bloc = context.read<RideSearchBloc>();
        final filterCount = query.activeFilterCount;
        final from = cities.byId(query.fromCityId);
        final to = cities.byId(query.toCityId);

        return AppScaffold(
          titleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (from != null && to != null)
                RouteLabel(
                  fromCity: from,
                  toCity: to,
                  style: context.text.titleMedium,
                  iconSize: 15,
                )
              else
                Text(l10n.searchRides, style: context.text.titleMedium),
              Text(
                [
                  query.date == null
                      ? l10n.anyDate
                      : context.fmt.dayLabel(query.date!),
                  l10n.seats(query.seats),
                ].join(' · '),
                style: context.text.bodySmall,
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              child: Badge.count(
                count: filterCount,
                isLabelVisible: filterCount > 0,
                backgroundColor: context.colors.primary,
                textColor: context.colors.onPrimary,
                offset: const Offset(-4, 4),
                child: IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: l10n.filters,
                  onPressed: () => SearchFilterSheet.show(context),
                ),
              ),
            ),
          ],
          appBarBottom: PreferredSize(
            preferredSize: const Size.fromHeight(74),
            child: _DateStrip(
              selected: query.date,
              onSelected: (date) => bloc.add(
                RideSearchFieldChanged(date: date, clearDate: date == null),
              ),
            ),
          ),
          body: _body(context, state, cities),
        );
      },
    );
  }

  /// Turns an empty result into a ride request.
  ///
  /// The route, date and seat count all come from what the passenger already
  /// typed into the search form — the sheet only asks how flexible the date is,
  /// which is the one thing search never had to know.
  Future<void> _postRequest(BuildContext context, RideSearchState state) async {
    final l10n = context.l10n;

    // Posting demand is a write, so it needs an account — but the visitor only
    // meets that ask after seeing the route really is empty, which is a far
    // better moment for it than the app's front door.
    if (context.read<SessionBloc>().state.user == null) {
      context.push(Routes.login);
      return;
    }

    final requests = context.read<RideRequestRepository>();
    final analytics = context.read<Analytics>();

    final draft = await CreateRideRequestSheet.show(
      context,
      initial: RideRequestDraft(
        fromCityId: state.query.fromCityId,
        toCityId: state.query.toCityId,
        wantedDate: state.query.date ?? DateTime.now(),
        seats: state.query.seats,
      ),
    );
    if (draft == null || !context.mounted) return;

    analytics.log(
      Ev.rideRequestCreated,
      params: {
        'from_city_id': draft.fromCityId,
        'to_city_id': draft.toCityId,
        'seats': draft.seats,
        'flexible_days': draft.flexibleDays,
        'origin': 'empty_search',
      },
    );

    final result = await requests.create(draft);
    if (!context.mounted) return;

    switch (result) {
      case Ok(:final value):
        AppFeedback.success(
          context,
          // Matches can exist even here: the request's ±day window is wider
          // than the exact date the search asked for.
          value.matches.isEmpty
              ? l10n.rideRequestCreatedBody
              : l10n.rideRequestMatches,
        );
        context.push(Routes.rideRequests);
      case Err(:final failure):
        AppFeedback.error(context, failure.message(l10n));
    }
  }

  Widget _body(
    BuildContext context,
    RideSearchState state,
    CityRepository cities,
  ) {
    final l10n = context.l10n;
    final palette = context.palette;
    final bloc = context.read<RideSearchBloc>();

    if (state.status.isFirstLoad) return const ListSkeleton();

    if (state.status.isFailure) {
      return ErrorState(
        failure: state.failure,
        onRetry: () => bloc.add(const RideSearchSubmitted()),
      );
    }

    final rides = state.rides;
    if (rides.isEmpty) {
      // The most important screen in the app, and until now the emptiest one.
      // A passenger who searched and found nothing had been told to "set up an
      // alert" that did not exist, and left. Two things happen here instead:
      // filters that emptied a list the server had filled offer to clear
      // themselves, and a genuinely empty route offers to become demand a
      // driver can answer.
      final isFiltered = state.query.activeFilterCount > 0;

      return EmptyState(
        icon: Icons.search_off_rounded,
        title: l10n.noRidesFound,
        // The filters applied client-side can empty a list the server filled,
        // which is worth saying — clearing them would bring rides back.
        message: state.isFilteredEmpty
            ? l10n.filtersLocalNote
            : l10n.noRidesFoundBody,
        actionLabel: isFiltered ? l10n.reset : l10n.createRideRequest,
        onAction: isFiltered
            ? () => bloc.add(const RideSearchFiltersCleared())
            // Only offered on a real route: without two cities there is
            // nothing to tell a driver.
            : (state.query.hasRoute ? () => _postRequest(context, state) : null),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => bloc.add(const RideSearchRefreshed()),
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          Gap.page,
          Gap.lg,
          Gap.page,
          Gap.xxxl,
        ),
        itemCount: rides.length + 2,
        separatorBuilder: (_, _) => VGap.md,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: Gap.xs),
              child: Text(
                l10n.tripsCount(state.totalFound),
                style: context.text.labelMedium?.copyWith(
                  color: palette.textTertiary,
                ),
              ),
            );
          }

          if (index == rides.length + 1) {
            if (!state.hasMore) return const SizedBox(height: Gap.xl);
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: Gap.lg),
              child: LoadingState(),
            );
          }

          final ride = rides[index - 1];
          return RideCard(
            ride: ride,
            onTap: () => context.push(Routes.rideDetail(ride.id)),
          ).animate().fadeIn(
            delay: Duration(milliseconds: 30 * (index - 1).clamp(0, 8)),
            duration: 280.ms,
          );
        },
      ),
    );
  }
}

/// Horizontal week strip. Tapping a day narrows the search to it; tapping the
/// selected day again clears the date filter.
class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.selected, required this.onSelected});

  final DateTime? selected;
  final ValueChanged<DateTime?> onSelected;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final palette = context.palette;
    final today = DateTime.now();

    return SizedBox(
      height: 74,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = DateTime(today.year, today.month, today.day + index);
          final isSelected =
              selected != null &&
              selected!.year == date.year &&
              selected!.month == date.month &&
              selected!.day == date.day;

          return Padding(
            padding: const EdgeInsets.only(right: Gap.sm),
            child: GestureDetector(
              onTap: () => onSelected(isSelected ? null : date),
              child: AnimatedContainer(
                duration: Motion.fast,
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.colors.primary
                      : palette.surfaceElevated,
                  borderRadius: Radii.mdAll,
                  border: Border.all(
                    color: isSelected ? context.colors.primary : palette.border,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      fmt.weekdayShort(date),
                      style: context.text.labelSmall?.copyWith(
                        color: isSelected
                            ? context.colors.onPrimary.withValues(alpha: 0.85)
                            : palette.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${date.day}',
                      style: context.text.titleMedium?.copyWith(
                        color: isSelected
                            ? context.colors.onPrimary
                            : palette.textPrimary,
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
  }
}
