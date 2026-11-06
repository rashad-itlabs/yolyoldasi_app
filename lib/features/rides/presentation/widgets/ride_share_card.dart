import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../domain/entities/ride.dart';

/// A ride as a picture, for the places that only take pictures — an Instagram
/// post above all.
///
/// The size, the theme and the text scale are all fixed. This leaves the phone,
/// so it has to come out the same whatever the sender's dark mode or font size
/// happens to be.
///
/// It shows what a stranger needs and nothing more: no driver, no plate, no
/// seat count. A post stays up for months and the seat count would not.
class RideShareCard extends StatelessWidget {
  const RideShareCard({super.key, required this.ride});

  final Ride ride;

  /// Laid out at this size and rendered at [pixelRatio], which gives 1080×1350:
  /// the 4:5 portrait that takes the most room in the Instagram feed.
  static const Size size = Size(360, 450);
  static const double pixelRatio = 3;

  static const Color _ink = Colors.white;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final text = AppTheme.light.textTheme;
    final code = l10n.languageCode;
    final shareUrl = ride.shareUrl;

    return MediaQuery.withNoTextScaling(
      child: Theme(
        data: AppTheme.light,
        child: SizedBox.fromSize(
          size: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppPalette.light.heroGradient,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Gap.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          color: _ink,
                          borderRadius: Radii.smAll,
                        ),
                        child: BrandMark(size: 36, showTile: false),
                      ),
                      HGap.md,
                      Text(
                        l10n.appName,
                        style: text.titleLarge?.copyWith(color: _ink),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _Route(
                    from: ride.fromCity.nameFor(code),
                    to: ride.toCity.nameFor(code),
                  ),
                  VGap.xl,
                  Text(
                    // Absolute on purpose: "Sabah" would be wrong by tomorrow,
                    // and the post will still be there.
                    fmt.dayMonthWithTime(ride.departureAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.headlineSmall?.copyWith(color: _ink),
                  ),
                  // A condition, not a decoration: a passenger it excludes
                  // should not have to open the app to find out.
                  if (ride.womenOnly) ...[
                    VGap.sm,
                    Text(
                      l10n.womenOnlyRide,
                      style: text.titleMedium?.copyWith(
                        color: AppColors.amber200,
                      ),
                    ),
                  ],
                  const Spacer(),
                  _PriceTag(
                    price: fmt.price(ride.pricePerSeat),
                    unit: l10n.perSeat,
                  ),
                  if (shareUrl != null) ...[
                    VGap.lg,
                    // Instagram does not make a link in a post tappable, so the
                    // address is printed where it can at least be read.
                    Text(
                      shareUrl.replaceFirst(RegExp(r'^https?://'), ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(color: _ink),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The two cities with the logo's ring-and-dot route running between them.
class _Route extends StatelessWidget {
  const _Route({required this.from, required this.to});

  final String from;
  final String to;

  static const double _cityHeight = 48;
  static const double _stopSize = 14;
  static const double _lineGap = (_cityHeight - _stopSize) / 2;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _cityHeight * 2 + Gap.lg,
      child: Row(
        children: [
          Column(
            children: [
              const SizedBox(height: _lineGap),
              Container(
                width: _stopSize,
                height: _stopSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: RideShareCard._ink, width: 3),
                ),
              ),
              const Expanded(
                child: SizedBox(
                  width: 3,
                  child: ColoredBox(color: RideShareCard._ink),
                ),
              ),
              const SizedBox(
                width: _stopSize,
                height: _stopSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.amber400,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(height: _lineGap),
            ],
          ),
          HGap.lg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _City(name: from, height: _cityHeight),
                _City(name: to, height: _cityHeight),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One line that shrinks to fit: the server can return a city the local table
/// has never heard of, and a clipped name would make the whole image useless.
class _City extends StatelessWidget {
  const _City({required this.name, required this.height});

  final String name;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          name,
          maxLines: 1,
          style: AppTheme.light.textTheme.displayLarge?.copyWith(
            color: RideShareCard._ink,
          ),
        ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  const _PriceTag({required this.price, required this.unit});

  final String price;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final text = AppTheme.light.textTheme;
    final ink = AppPalette.light.onAccent;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.amber400,
          borderRadius: Radii.mdAll,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(price, style: text.headlineLarge?.copyWith(color: ink)),
              HGap.sm,
              Text(unit, style: text.titleSmall?.copyWith(color: ink)),
            ],
          ),
        ),
      ),
    );
  }
}
