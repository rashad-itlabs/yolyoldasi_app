import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../domain/entities/ride_query.dart';
import '../bloc/ride_search/ride_search_bloc.dart';

/// Sort, price ceiling and departure-window filters.
///
/// Only `sort` is a `GET /rides` parameter. The price ceiling and the time
/// bands narrow the results already loaded, because the API has no equivalent
/// — the note at the bottom of the sheet says so, rather than letting the
/// numbers look wrong.
class SearchFilterSheet extends StatelessWidget {
  const SearchFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    final bloc = context.read<RideSearchBloc>();
    return AppFeedback.sheet<void>(
      context,
      builder: (_) => BlocProvider<RideSearchBloc>.value(
        value: bloc,
        child: const SearchFilterSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;

    return BlocBuilder<RideSearchBloc, RideSearchState>(
      buildWhen: (previous, current) => previous.query != current.query,
      builder: (context, state) {
        final bloc = context.read<RideSearchBloc>();
        final query = state.query;
        final maxPrice = query.maxPrice ?? AppRules.maxPricePerSeat;

        return SheetScaffold(
          title: l10n.filters,
          action: Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: l10n.reset,
                  onPressed: () => bloc.add(const RideSearchFiltersCleared()),
                ),
              ),
              HGap.md,
              Expanded(
                flex: 2,
                child: AppButton(
                  label: l10n.apply,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.sortBy, style: context.text.titleSmall),
                VGap.md,
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    for (final option in RideSortOption.values)
                      ChoiceChip(
                        selected: query.sort == option,
                        onSelected: (_) =>
                            bloc.add(RideSearchFiltersChanged(sort: option)),
                        label: Text(switch (option) {
                          RideSortOption.earliest => l10n.sortEarliest,
                          RideSortOption.cheapest => l10n.sortCheapest,
                        }),
                      ),
                  ],
                ),

                VGap.xxl,
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.priceRange,
                        style: context.text.titleSmall,
                      ),
                    ),
                    Text(
                      '≤ ${fmt.price(maxPrice)}',
                      style: context.text.labelMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: maxPrice.clamp(
                    AppRules.minPricePerSeat,
                    AppRules.maxPricePerSeat,
                  ),
                  min: AppRules.minPricePerSeat,
                  max: AppRules.maxPricePerSeat,
                  divisions: 50,
                  onChanged: (value) {
                    // At the top of the range the filter excludes nothing, so
                    // drop it rather than leaving a badge on the filter icon.
                    final atMax = value >= AppRules.maxPricePerSeat;
                    bloc.add(
                      RideSearchFiltersChanged(
                        maxPrice: atMax ? null : value.roundToDouble(),
                        clearMaxPrice: atMax,
                      ),
                    );
                  },
                ),

                VGap.lg,
                Text(l10n.timeOfDay, style: context.text.titleSmall),
                VGap.md,
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    for (final band in TimeOfDayBand.values)
                      FilterChip(
                        selected: query.bands.contains(band),
                        onSelected: (_) => bloc.add(
                          RideSearchFiltersChanged(
                            bands: query.bands.contains(band)
                                ? ({...query.bands}..remove(band))
                                : {...query.bands, band},
                          ),
                        ),
                        avatar: Icon(switch (band) {
                          TimeOfDayBand.morning => Icons.wb_twilight_rounded,
                          TimeOfDayBand.afternoon => Icons.light_mode_rounded,
                          TimeOfDayBand.evening => Icons.wb_sunny_outlined,
                          TimeOfDayBand.night => Icons.nights_stay_outlined,
                        }, size: 15),
                        label: Text(switch (band) {
                          TimeOfDayBand.morning => l10n.morning,
                          TimeOfDayBand.afternoon => l10n.afternoon,
                          TimeOfDayBand.evening => l10n.evening,
                          TimeOfDayBand.night => l10n.night,
                        }),
                      ),
                  ],
                ),

                if (query.hasRefinements) ...[
                  VGap.lg,
                  InfoBanner(
                    tone: BannerTone.info,
                    message: l10n.filtersLocalNote,
                  ),
                ],
                VGap.md,
              ],
            ),
          ),
        );
      },
    );
  }
}
