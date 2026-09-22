import 'package:flutter/material.dart';

import '../../../../core/constants/dial_codes.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Picks the dialling code for the sign-in field.
///
/// Searchable by name, ISO code and dial code, because people reach for
/// whichever they happen to remember — "Türkiyə", "TR" and "+90" all land on
/// the same row.
class CountryPickerSheet extends StatefulWidget {
  const CountryPickerSheet({super.key, this.selected});

  final Country? selected;

  static Future<Country?> show(BuildContext context, {Country? selected}) {
    return AppFeedback.sheet<Country>(
      context,
      builder: (_) => CountryPickerSheet(selected: selected),
    );
  }

  @override
  State<CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<CountryPickerSheet> {
  final TextEditingController _query = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// The pinned countries first, then everything else alphabetically.
  ///
  /// Almost every account is Azerbaijani and almost every foreign one is a
  /// neighbour, so five rows at the top save most people a search. The pinning
  /// drops away as soon as they type — at that point they know what they want.
  List<Country> get _visible {
    final query = _search.trim().toLowerCase();

    if (query.isNotEmpty) {
      return Countries.all
          .where((country) => country.searchHaystack.contains(query))
          .toList(growable: false);
    }

    final pinned = [
      for (final iso in Countries.pinned) Countries.byIso(iso),
    ];
    final rest = Countries.all
        .where((country) => !Countries.pinned.contains(country.iso))
        .toList(growable: false);

    return [...pinned, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final countries = _visible;

    return SheetScaffold(
      title: l10n.countryCodeTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: AppTextField(
              controller: _query,
              hint: l10n.countrySearchHint,
              prefixIcon: Icons.search_rounded,
              autofocus: true,
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          VGap.md,
          Flexible(
            child: countries.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(Gap.xxl),
                    child: Text(
                      l10n.countryNotFound,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: countries.length,
                    itemBuilder: (context, index) {
                      final country = countries[index];
                      final isSelected = country.iso == widget.selected?.iso;

                      return ListTile(
                        leading: Text(
                          country.flag,
                          style: const TextStyle(fontSize: 26),
                        ),
                        title: Text(country.name),
                        trailing: Text(
                          country.prefix,
                          style: context.text.labelLarge?.copyWith(
                            color: isSelected
                                ? context.colors.primary
                                : context.palette.textSecondary,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        selected: isSelected,
                        onTap: () => Navigator.of(context).pop(country),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
