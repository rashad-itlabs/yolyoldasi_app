import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../cities/domain/entities/city.dart';
import '../../../cities/presentation/bloc/cities_bloc.dart';

/// Searchable city picker, backed by `GET /cities` (API.md §6).
///
/// Matching is diacritic-insensitive across all three languages, so "gence",
/// "Gəncə" and "Гянджа" all find the same city.
class CityPickerSheet extends StatefulWidget {
  const CityPickerSheet({
    super.key,
    required this.title,
    this.excludeCityId,
    this.selectedCityId,
  });

  final String title;

  /// Hidden from the list — stops a route being set to the same city twice.
  final int? excludeCityId;
  final int? selectedCityId;

  /// Opens the sheet and returns the chosen city, or `null` if dismissed.
  ///
  /// The whole [City] comes back rather than an id, because the caller almost
  /// always needs the name to render straight away.
  static Future<City?> show(
    BuildContext context, {
    required String title,
    int? excludeCityId,
    int? selectedCityId,
  }) {
    // The sheet is opened from a new route, so it has to be handed the bloc
    // rather than inheriting it.
    final cities = context.read<CitiesBloc>();
    return AppFeedback.sheet<City>(
      context,
      builder: (_) => BlocProvider<CitiesBloc>.value(
        value: cities,
        child: CityPickerSheet(
          title: title,
          excludeCityId: excludeCityId,
          selectedCityId: selectedCityId,
        ),
      ),
    );
  }

  @override
  State<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<CityPickerSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Harmless when the list is already cached; the bloc ignores a repeat.
    context.read<CitiesBloc>().add(const CitiesRequested());
  }

  /// Re-applies the filter, and not from [initState]: the query needs the
  /// current language, and reading `Localizations` before `initState` has
  /// finished is an error.
  ///
  /// [CitiesBloc] is provided above the router, so its query survives the
  /// sheet being closed. Seeding from the (empty) controller clears whatever
  /// the last picker left behind, and re-running on a locale change keeps the
  /// typed text while matching in the new language.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _search(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String query) {
    context.read<CitiesBloc>().add(
      CitiesQueryChanged(query, languageCode: context.l10n.languageCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = l10n.languageCode;

    return SheetScaffold(
      title: widget.title,
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
      child: BlocBuilder<CitiesBloc, CitiesState>(
        builder: (context, state) {
          final results = state.visible
              .where((city) => city.id != widget.excludeCityId)
              .toList(growable: false);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                child: AppTextField(
                  controller: _controller,
                  hint: l10n.searchCity,
                  prefixIcon: Icons.search_rounded,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _search,
                  suffix: state.query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _controller.clear();
                            _search('');
                          },
                        ),
                ),
              ),
              VGap.md,
              Flexible(child: _body(context, state, results, code)),
            ],
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    CitiesState state,
    List<City> results,
    String code,
  ) {
    if (state.status.isFirstLoad) {
      return const Padding(
        padding: EdgeInsets.all(Gap.xxxl),
        child: LoadingState(),
      );
    }

    if (state.status.isFailure && state.cities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: ErrorState(
          failure: state.failure,
          compact: true,
          onRetry: () =>
              context.read<CitiesBloc>().add(const CitiesRefreshed()),
        ),
      );
    }

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Gap.xxxl),
        child: Text(
          context.l10n.noResultsTitle,
          style: context.text.bodyMedium,
        ),
      );
    }

    final palette = context.palette;
    final showPopularHeader = state.query.isEmpty;

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: Gap.lg),
      itemCount: results.length + (showPopularHeader ? 1 : 0),
      itemBuilder: (context, index) {
        if (showPopularHeader && index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.sm,
              Gap.page,
              Gap.sm,
            ),
            child: Text(
              context.l10n.popularRoutes,
              style: context.text.labelSmall?.copyWith(
                color: palette.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
          );
        }

        final city = results[index - (showPopularHeader ? 1 : 0)];
        final selected = city.id == widget.selectedCityId;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: Gap.page),
          shape: const RoundedRectangleBorder(),
          leading: Icon(
            city.isPopular ? Icons.location_city_rounded : Icons.place_outlined,
            color: selected ? context.colors.primary : palette.textTertiary,
            size: 20,
          ),
          title: Text(
            city.nameFor(code),
            style: context.text.bodyLarge?.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? context.colors.primary : palette.textPrimary,
            ),
          ),
          trailing: selected
              ? Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: context.colors.primary,
                )
              : null,
          onTap: () => Navigator.of(context).pop(city),
        );
      },
    );
  }
}
