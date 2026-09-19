import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../cities/domain/repositories/city_repository.dart';
import '../bloc/ride_search/ride_search_bloc.dart';
import 'city_picker_sheet.dart';

/// The from / to / date / seats form.
///
/// Rendered as a raised card that overlaps the home header, so the primary
/// action of the app is always the first thing in reach.
class SearchFormCard extends StatelessWidget {
  const SearchFormCard({super.key, required this.onSearch});

  final VoidCallback onSearch;

  /// `GET /rides` takes a plain `YYYY-MM-DD`, with no upper bound on how far
  /// ahead a search may look — the picker allows a year, which is well past
  /// any realistic listing.
  Future<void> _pickDate(BuildContext context, DateTime? current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: context.l10n.selectDate,
    );
    if (picked == null || !context.mounted) return;
    context.read<RideSearchBloc>().add(RideSearchFieldChanged(date: picked));
  }

  Future<void> _pickSeats(BuildContext context, int current) async {
    final l10n = context.l10n;
    final bloc = context.read<RideSearchBloc>();

    await AppFeedback.sheet<void>(
      context,
      builder: (sheetContext) => BlocProvider<RideSearchBloc>.value(
        value: bloc,
        child: BlocBuilder<RideSearchBloc, RideSearchState>(
          builder: (context, state) => SheetScaffold(
            title: l10n.passengersCount,
            action: AppButton(
              label: l10n.done,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xl),
              child: Center(
                child: CounterStepper(
                  value: state.query.seats,
                  min: AppRules.minSeatsPerRide,
                  max: AppRules.maxSeatsPerRide,
                  semanticLabel: l10n.passengersCount,
                  onChanged: (value) =>
                      bloc.add(RideSearchFieldChanged(seats: value)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;
    final code = l10n.languageCode;
    final cities = context.read<CityRepository>();

    return BlocBuilder<RideSearchBloc, RideSearchState>(
      buildWhen: (previous, current) => previous.query != current.query,
      builder: (context, state) {
        final query = state.query;
        final bloc = context.read<RideSearchBloc>();

        // Names come from the cached city list; `null` only while `/cities`
        // has not answered yet, which the picker itself handles.
        String? cityName(int? id) => cities.byId(id)?.nameFor(code);

        return _Floating(
          child: AppCard(
            // The card's own border reads as grime against the coloured
            // header, and its stock shadow disappears into it — so the shape
            // is carried by [_Floating] instead.
            elevated: false,
            borderColor: Colors.transparent,
            borderRadius: Radii.xlAll,
            padding: const EdgeInsets.all(Gap.xs),
            child: Column(
              children: [
                // ---------------------------------------------------- from / to
                Stack(
                  children: [
                    Column(
                      children: [
                        _FieldRow(
                          icon: Icons.trip_origin_rounded,
                          iconColor: context.colors.primary,
                          label: l10n.fromCity,
                          value: cityName(query.fromCityId),
                          onTap: () async {
                            final city = await CityPickerSheet.show(
                              context,
                              title: l10n.fromCity,
                              excludeCityId: query.toCityId,
                              selectedCityId: query.fromCityId,
                            );
                            if (city != null) {
                              bloc.add(
                                RideSearchFieldChanged(fromCityId: city.id),
                              );
                            }
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: Gap.giant),
                          child: Divider(height: 1, color: palette.border),
                        ),
                        _FieldRow(
                          icon: Icons.place_rounded,
                          iconColor: context.colors.primary,
                          label: l10n.toCity,
                          value: cityName(query.toCityId),
                          onTap: () async {
                            final city = await CityPickerSheet.show(
                              context,
                              title: l10n.toCity,
                              excludeCityId: query.fromCityId,
                              selectedCityId: query.toCityId,
                            );
                            if (city != null) {
                              bloc.add(
                                RideSearchFieldChanged(toCityId: city.id),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    // Swap sits on the divider between the two fields.
                    Positioned(
                      right: Gap.md,
                      top: 8,
                      child: Material(
                        color: palette.surfaceElevated,
                        shape: CircleBorder(
                          side: BorderSide(color: palette.border),
                        ),
                        child: InkWell(
                          onTap: () => bloc.add(const RideSearchRouteSwapped()),
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(Gap.sm),
                            child: Icon(
                              Icons.swap_vert_rounded,
                              size: 20,
                              color: context.colors.primary,
                              semanticLabel: l10n.swapCities,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                Divider(height: 1, color: palette.border),

                // ------------------------------------------------- date / seats
                Row(
                  children: [
                    Expanded(
                      child: _FieldRow(
                        icon: Icons.calendar_today_rounded,
                        label: l10n.date,
                        value: query.date == null
                            ? l10n.anyDate
                            : fmt.dayLabel(query.date!),
                        isMuted: query.date == null,
                        onTap: () => _pickDate(context, query.date),
                        onClear: query.date == null
                            ? null
                            : () => bloc.add(
                                const RideSearchFieldChanged(clearDate: true),
                              ),
                      ),
                    ),
                    Container(width: 1, height: 36, color: palette.border),
                    Expanded(
                      child: _FieldRow(
                        icon: Icons.person_outline_rounded,
                        label: l10n.passengersCount,
                        value: l10n.seats(query.seats),
                        onTap: () => _pickSeats(context, query.seats),
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: AppButton(
                    label: l10n.searchRides,
                    icon: Icons.search_rounded,
                    // Both cities are required by `GET /rides`; without them
                    // the API answers 422, so the button stays disabled.
                    onPressed: query.hasRoute ? onSearch : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Lifts the search card off the coloured header it sits on.
///
/// A neutral card shadow is invisible against a saturated background, so this
/// one is darker and thrown further — enough for the card to read as floating
/// rather than pasted on.
class _Floating extends StatelessWidget {
  const _Floating({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Radii.xlAll,
        boxShadow: [
          BoxShadow(
            color: context.palette.overlay.withValues(alpha: 0.20),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.isMuted = false,
    this.onClear,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool isMuted;
  final VoidCallback? onClear;

  /// Defaults to tertiary. The route rows pass the brand colour: they are the
  /// two fields `GET /rides` actually requires, so they lead the card.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasValue = value != null && value!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? palette.textTertiary),
            HGap.md,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.text.labelSmall?.copyWith(
                      color: palette.textTertiary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    hasValue ? value! : '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      color: hasValue && !isMuted
                          ? palette.textPrimary
                          : palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: onClear,
                color: palette.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
