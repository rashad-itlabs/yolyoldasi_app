import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/route_timeline.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../cities/domain/entities/city.dart';
import '../../../profile/domain/entities/user_enums.dart';
import '../../domain/entities/ride.dart';

/// The search-result / listing card.
///
/// Leads with the two facts a passenger scans for — when it leaves and what it
/// costs — then the route, then who is driving.
class RideCard extends StatelessWidget {
  const RideCard({
    super.key,
    required this.ride,
    this.onTap,
    this.showDriver = true,
    this.trailing,
    this.highlightSeats = true,
  });

  final Ride ride;
  final VoidCallback? onTap;

  /// Hidden on the driver's own listings, where it would just be themselves.
  final bool showDriver;

  /// Extra row appended at the bottom (driver actions, booking status, ...).
  final Widget? trailing;

  final bool highlightSeats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;

    // API.md §16.3: the server's own figure, never recomputed here.
    final seatsLeft = ride.seatsLeft;
    final isScarce = seatsLeft > 0 && seatsLeft <= 1;
    final vehicle = ride.vehicle;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --------------------------------------------------------- header
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
                    fmt.dayLabel(ride.departureAt),
                    style: context.text.labelMedium?.copyWith(
                      color: palette.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (ride.instantBooking) ...[
                  StatusChip(
                    label: l10n.instantBooking,
                    tone: ChipTone.accent,
                    icon: Icons.bolt_rounded,
                    dense: true,
                  ),
                  HGap.sm,
                ],
                Text(
                  fmt.price(ride.pricePerSeat),
                  style: context.text.titleMedium?.copyWith(
                    color: context.colors.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.border),

          // ---------------------------------------------------------- route
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: RouteTimeline(
              fromCity: ride.fromCity,
              toCity: ride.toCity,
              departureAt: ride.departureAt,
              arrivalAt: ride.estimatedArrival,
              pickupPoint: ride.pickupPoint.isEmpty ? null : ride.pickupPoint,
              compact: true,
            ),
          ),

          // --------------------------------------------------------- driver
          if (showDriver) ...[
            Divider(height: 1, color: palette.border),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Row(
                children: [
                  AppAvatar(
                    name: ride.driver.fullName,
                    photoUrl: ride.driver.photoUrl,
                    size: Sizes.avatarSm + 6,
                    // The API exposes no per-user verification flag; having a
                    // driver profile at all is the closest signal it gives.
                    isVerified: ride.driver.hasDriverProfile,
                  ),
                  HGap.md,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                fmt.shortName(ride.driver.fullName),
                                style: context.text.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            HGap.sm,
                            RatingLabel(
                              rating: ride.driver.ratingFor(UserMode.driver),
                              reviewCount: ride.driver.reviewCountFor(
                                UserMode.driver,
                              ),
                              compact: true,
                            ),
                          ],
                        ),
                        if (vehicle != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              VehicleColorDot(
                                colorValue: vehicle.color,
                                size: 8,
                              ),
                              HGap.sm,
                              Flexible(
                                child: Text(
                                  vehicle.displayName,
                                  style: context.text.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  HGap.md,
                  if (highlightSeats)
                    StatusChip(
                      label: seatsLeft == 0
                          ? l10n.rideFull
                          : l10n.seatsLeft(seatsLeft),
                      tone: seatsLeft == 0
                          ? ChipTone.neutral
                          : isScarce
                          ? ChipTone.warning
                          : ChipTone.success,
                      dense: true,
                    ),
                ],
              ),
            ),
          ],

          if (trailing != null) ...[
            Divider(height: 1, color: palette.border),
            Padding(padding: const EdgeInsets.all(Gap.lg), child: trailing!),
          ],
        ],
      ),
    );
  }
}

/// Compact one-line variant used inside booking rows and notifications.
class RideSummaryRow extends StatelessWidget {
  const RideSummaryRow({
    super.key,
    required this.fromCity,
    required this.toCity,
    required this.departureAt,
    this.trailing,
  });

  final City fromCity;
  final City toCity;
  final DateTime departureAt;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RouteLabel(
                fromCity: fromCity,
                toCity: toCity,
                style: context.text.titleSmall,
                iconSize: 14,
              ),
              const SizedBox(height: 2),
              Text(
                context.fmt.dayDotTime(departureAt),
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
        if (trailing != null) ...[HGap.md, trailing!],
      ],
    );
  }
}
