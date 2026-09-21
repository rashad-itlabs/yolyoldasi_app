import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/ride_request.dart';

/// One passenger's request, on both sides of the marketplace.
///
/// The same card serves the passenger's own list and the driver's incoming
/// list — only [showPassenger] differs — because it is the same fact either
/// way: someone wants a seat on this route on this date. Splitting it in two
/// would let the two sides drift apart in wording.
class RideRequestCard extends StatelessWidget {
  const RideRequestCard({
    super.key,
    required this.request,
    this.onTap,
    this.trailing,
    this.showPassenger = true,
  });

  final RideRequest request;
  final VoidCallback? onTap;

  /// Driver actions, or the passenger's own close button.
  final Widget? trailing;

  /// Hidden on the passenger's own list, where it would just be themselves.
  final bool showPassenger;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;
    final passenger = request.passenger;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----------------------------------------------------- date + seats
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
            child: Row(
              children: [
                Icon(
                  Icons.event_rounded,
                  size: 16,
                  color: palette.textTertiary,
                ),
                HGap.sm,
                Expanded(
                  child: Text(
                    fmt.dayLabel(request.wantedDate),
                    style: context.text.labelMedium?.copyWith(
                      color: palette.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // The window matters as much as the date: a driver going a day
                // later is still a match, and the card should say so before
                // they decide the request is not for them.
                if (request.isFlexible) ...[
                  StatusChip(
                    label: l10n.flexibleDaysLabel(request.flexibleDays),
                    tone: ChipTone.info,
                    dense: true,
                  ),
                  HGap.sm,
                ],
                Text(
                  l10n.seats(request.seats),
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.primary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.border),

          // ------------------------------------------------------------ route
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Row(
              children: [
                Icon(
                  Icons.alt_route_rounded,
                  size: 18,
                  color: context.colors.primary,
                ),
                HGap.md,
                Expanded(
                  child: Text(
                    '${request.fromCity.name} → ${request.toCity.name}',
                    style: context.text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          if (request.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
              child: Text(
                request.note,
                style: context.text.bodySmall?.copyWith(
                  color: palette.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // -------------------------------------------------------- passenger
          if (showPassenger && passenger != null) ...[
            Divider(height: 1, color: palette.border),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Row(
                children: [
                  AppAvatar(
                    name: passenger.fullName,
                    photoUrl: passenger.photoUrl,
                    size: Sizes.avatarSm + 6,
                  ),
                  HGap.md,
                  Expanded(
                    child: Text(
                      passenger.displayName,
                      style: context.text.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (passenger.stats.passengerReviewCount > 0)
                    RatingLabel(
                      rating: passenger.stats.passengerRating,
                      reviewCount: passenger.stats.passengerReviewCount,
                      compact: true,
                    ),
                ],
              ),
            ),
          ],

          if (trailing != null) ...[
            Divider(height: 1, color: palette.border),
            Padding(padding: const EdgeInsets.all(Gap.lg), child: trailing),
          ],
        ],
      ),
    );
  }
}
