import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../domain/entities/app_update.dart';

/// The soft half of the update gate: a newer release exists, this one still
/// works.
///
/// A sheet rather than a route, because that is the difference the user is
/// being told about — the forced screen cannot be dismissed and this one is
/// nothing but dismissible. "Sonra" is remembered per release, so the choice
/// is honoured until there is genuinely something new to ask about.
class OptionalUpdateSheet extends StatelessWidget {
  const OptionalUpdateSheet({super.key, required this.update});

  final AppUpdate update;

  /// Resolves to true when the user chose to update, false when they put it
  /// off, and null when they dismissed the sheet by dragging or tapping away
  /// — which counts as "later" to the caller, since it is the same answer.
  ///
  /// Opening the store is the caller's job, not this sheet's. A snackbar
  /// raised from inside a modal route renders *behind* it, so the one case
  /// that needs to be reported — a store link that will not open — could not
  /// be reported from here.
  static Future<bool?> show(BuildContext context, AppUpdate update) {
    return AppFeedback.sheet<bool>(
      context,
      builder: (_) => OptionalUpdateSheet(update: update),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final version = update.latestVersion;

    return SheetScaffold(
      title: l10n.updateOptionalTitle,
      subtitle: version == null ? null : l10n.updateNewVersion(version),
      action: Row(
        children: [
          Expanded(
            child: AppButton.secondary(
              label: l10n.updateLater,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ),
          HGap.md,
          Expanded(
            flex: 2,
            child: AppButton(
              label: l10n.updateNow,
              icon: Icons.download_rounded,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.page),
        child: Text(
          update.message ?? l10n.updateOptionalBody,
          style: context.text.bodyMedium,
        ),
      ),
    );
  }
}
