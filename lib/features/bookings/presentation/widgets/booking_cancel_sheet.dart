import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/booking.dart';

/// The label that goes on the wire for [reason] — see [BookingCancelReason].
String cancelReasonLabel(AppStrings l10n, BookingCancelReason reason) =>
    switch (reason) {
      BookingCancelReason.planChanged => l10n.cancelReasonPlanChanged,
      BookingCancelReason.foundCheaper => l10n.cancelReasonFoundCheaper,
      BookingCancelReason.noAnswer => l10n.cancelReasonNoAnswer,
      BookingCancelReason.vehicleProblem => l10n.cancelReasonVehicleProblem,
      BookingCancelReason.rescheduled => l10n.cancelReasonRescheduled,
      BookingCancelReason.other => l10n.cancelReasonOther,
    };

/// Confirms a cancellation and collects the `reason` for
/// `POST /bookings/{id}/cancel`.
///
/// A plain yes/no dialog was not enough here for two reasons. The counterpart
/// only ever learns *why* from this field — it is the one thing they see next
/// to a booking that vanished. And API.md §10 makes the 409 on a second request
/// permanent, so cancelling closes this ride for good: the sheet says that
/// before the tap rather than after it.
class BookingCancelSheet extends StatefulWidget {
  const BookingCancelSheet({
    super.key,
    required this.asDriver,
    required this.isLate,
  });

  /// Which side is cancelling — it picks the preset list.
  final bool asDriver;

  /// Close enough to departure that the other side is left stranded.
  final bool isLate;

  /// Returns the reason to send, or `null` if the user backed out.
  ///
  /// The reason is never empty: [BookingCancelReason.other] with nothing typed
  /// falls back to its own label, so the counterpart always reads something.
  static Future<String?> show(
    BuildContext context, {
    required bool asDriver,
    required bool isLate,
  }) {
    return AppFeedback.sheet<String>(
      context,
      builder: (_) => BookingCancelSheet(asDriver: asDriver, isLate: isLate),
    );
  }

  @override
  State<BookingCancelSheet> createState() => _BookingCancelSheetState();
}

class _BookingCancelSheetState extends State<BookingCancelSheet> {
  final TextEditingController _note = TextEditingController();
  BookingCancelReason? _selected;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final reason = _selected!;
    final note = _note.text.trim();

    Navigator.of(context).pop(
      reason.isFreeText && note.isNotEmpty
          ? note
          : cancelReasonLabel(l10n, reason),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final presets = BookingCancelReason.presetsFor(asDriver: widget.asDriver);

    return SheetScaffold(
      title: l10n.cancelBooking,
      subtitle: l10n.cancelReasonQuestion,
      action: Row(
        children: [
          Expanded(
            child: AppButton.secondary(
              label: l10n.keepBooking,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          HGap.md,
          Expanded(
            flex: 2,
            child: AppButton.danger(
              label: l10n.cancelBooking,
              // Deliberately gated on a reason: the counterpart has no other
              // way of finding out what happened.
              onPressed: _selected == null ? null : _submit,
            ),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Gap.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isLate) ...[
              InfoBanner(
                tone: BannerTone.danger,
                icon: Icons.warning_amber_rounded,
                message: l10n.lateCancellationWarning,
              ),
              VGap.lg,
            ],

            for (final reason in presets) ...[
              SelectableTile(
                title: cancelReasonLabel(l10n, reason),
                selected: _selected == reason,
                onTap: () => setState(() => _selected = reason),
              ),
              VGap.md,
            ],

            if (_selected?.isFreeText ?? false) ...[
              VGap.xs,
              AppTextField(
                controller: _note,
                hint: l10n.cancelReasonHint,
                maxLines: 3,
                minLines: 2,
                maxLength: AppRules.maxCancellationReasonLength,
                textInputAction: TextInputAction.done,
                autofocus: true,
              ),
              VGap.md,
            ],

            // API.md §10: a passenger's own cancellation reopens the ride, so
            // the honest warning is about the seat, not about being locked out.
            if (!widget.asDriver) ...[
              VGap.xs,
              InfoBanner(
                tone: BannerTone.info,
                message: l10n.cancelReleasesSeat,
              ),
            ],
            VGap.md,
          ],
        ),
      ),
    );
  }
}
