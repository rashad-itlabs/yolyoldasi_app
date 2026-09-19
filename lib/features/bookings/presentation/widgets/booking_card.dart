import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/route_timeline.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../profile/domain/entities/user_enums.dart';
import '../../domain/entities/booking.dart';

/// Localized label and colour for a booking status.
({String label, ChipTone tone}) bookingStatusChip(
  BuildContext context,
  BookingStatus status,
) {
  final l10n = context.l10n;
  return switch (status) {
    BookingStatus.pending => (
      label: l10n.statusPending,
      tone: ChipTone.warning,
    ),
    BookingStatus.confirmed => (
      label: l10n.statusConfirmed,
      tone: ChipTone.success,
    ),
    BookingStatus.rejected => (
      label: l10n.statusRejected,
      tone: ChipTone.danger,
    ),
    BookingStatus.cancelledByPassenger => (
      label: l10n.statusCancelledByPassenger,
      tone: ChipTone.neutral,
    ),
    BookingStatus.cancelledByDriver => (
      label: l10n.statusCancelledByDriver,
      tone: ChipTone.neutral,
    ),
    BookingStatus.completed => (
      label: l10n.statusCompleted,
      tone: ChipTone.brand,
    ),
  };
}

/// One booking row. [asDriver] flips which party is shown.
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.asDriver,
    this.onTap,
    this.actions,
  });

  final Booking booking;
  final bool asDriver;
  final VoidCallback? onTap;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;
    final chip = bookingStatusChip(context, booking.status);
    // Nullable: the API omits the block when the other account is gone.
    final other = asDriver ? booking.passenger : booking.driver;
    final role = asDriver ? UserMode.passenger : UserMode.driver;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RouteLabel(
                        fromCity: booking.ride.fromCity,
                        toCity: booking.ride.toCity,
                        style: context.text.titleMedium,
                        iconSize: 15,
                      ),
                    ),
                    HGap.sm,
                    StatusChip(label: chip.label, tone: chip.tone, dense: true),
                  ],
                ),
                VGap.sm,
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: palette.textTertiary,
                    ),
                    HGap.sm,
                    Text(
                      fmt.dayDotTime(booking.ride.departureAt),
                      style: context.text.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      fmt.price(booking.totalPrice),
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.border),
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Row(
              children: [
                AppAvatar(
                  name: other?.fullName ?? '',
                  photoUrl: other?.photoUrl,
                  size: Sizes.avatarSm + 4,
                  isVerified: other?.hasDriverProfile ?? false,
                ),
                HGap.md,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fmt.shortName(other?.fullName ?? ''),
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        l10n.seats(booking.seats),
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                if ((other?.ratingFor(role) ?? 0) > 0)
                  RatingLabel(rating: other!.ratingFor(role), compact: true),
              ],
            ),
          ),
          if (booking.message.isNotEmpty && asDriver) ...[
            Divider(height: 1, color: palette.border),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 15,
                    color: palette.textTertiary,
                  ),
                  HGap.md,
                  Expanded(
                    child: Text(
                      booking.message,
                      style: context.text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (actions != null) ...[
            Divider(height: 1, color: palette.border),
            Padding(padding: const EdgeInsets.all(Gap.lg), child: actions!),
          ],
        ],
      ),
    );
  }
}
