import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/result.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/route_demand.dart';
import '../../domain/repositories/demand_repository.dart';
import '../bloc/publish_ride/publish_ride_bloc.dart';

/// "43 people searched Baku → Sheki this week. Do you drive it?"
///
/// The single most useful thing to put in front of a driver, and the app has
/// had the data for it all along — every search is already recorded server
/// side. Without this, publishing is a guess; with it, publishing is answering.
///
/// Ranked by *unmet* demand rather than raw volume: Baku–Sumqayit is searched
/// constantly and already has plenty of listings, so suggesting one more there
/// would waste the driver's attention on the one route that does not need them.
class DemandStrip extends StatefulWidget {
  const DemandStrip({super.key});

  @override
  State<DemandStrip> createState() => _DemandStripState();
}

class _DemandStripState extends State<DemandStrip> {
  late final Future<Result<List<RouteDemand>>> _future = context
      .read<DemandRepository>()
      .topRoutes();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return FutureBuilder<Result<List<RouteDemand>>>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;

        // Silent on every failure path. This is a suggestion, not content the
        // driver asked for — an error message where a hint should be would be
        // worse than the hint simply not appearing.
        if (data is! Ok<List<RouteDemand>>) return const SizedBox.shrink();

        final routes = data.value
            .where((route) => route.isWorthShowing)
            .toList(growable: false);

        if (routes.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    size: 18,
                    color: context.colors.primary,
                  ),
                  HGap.sm,
                  Expanded(
                    child: Text(
                      l10n.topRoutesTitle,
                      style: context.text.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(Routes.rideRequestsIncoming),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.seeAll),
                  ),
                ],
              ),
              VGap.sm,
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: routes.length,
                  separatorBuilder: (_, _) => HGap.md,
                  itemBuilder: (context, index) =>
                      _RouteCard(demand: routes[index]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.demand});

  final RouteDemand demand;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final from = demand.fromCity;
    final to = demand.toCity;

    return SizedBox(
      width: 230,
      child: AppCard(
        onTap: from == null || to == null
            ? null
            : () => context.push(
                Routes.publishRide,
                extra: RidePrefill(fromCityId: from.id, toCityId: to.id),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${from?.name ?? '—'} → ${to?.name ?? '—'}',
              style: context.text.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            VGap.xs,
            Text(
              l10n.demandSearches(demand.searches, demand.windowDays),
              style: context.text.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // The stronger of the two signals, so it gets its own line rather
            // than being folded into the search count.
            if (demand.requests > 0) ...[
              VGap.xs,
              Text(
                l10n.demandRequests(demand.requests),
                style: context.text.labelSmall?.copyWith(
                  color: context.colors.primary,
                ),
              ),
            ],
            const Spacer(),
            AppButton(
              label: l10n.demandPublishCta,
              size: AppButtonSize.compact,
              onPressed: from == null || to == null
                  ? null
                  : () => context.push(
                      Routes.publishRide,
                      extra: RidePrefill(
                        fromCityId: from.id,
                        toCityId: to.id,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
