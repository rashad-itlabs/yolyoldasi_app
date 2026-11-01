import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The PRO tier's gold, in one place.
///
/// Built from the amber accent the palette already reserves for highlights,
/// so PRO reads as part of the same brand rather than a bolted-on colour.
/// Identical in both themes: gold on a dark page is still gold, and the
/// badge is a fixed mark, not a surface that should follow the theme.
abstract final class ProColors {
  static const List<Color> gradient = [AppColors.amber400, AppColors.amber500];

  /// A deeper run for large areas — the PRO screen's header.
  static const List<Color> heroGradient = [
    AppColors.amber400,
    AppColors.amber500,
    AppColors.amber700,
  ];

  /// Text and icons on gold. Dark brown rather than white: white on amber
  /// fails contrast at badge sizes.
  static const Color onGold = Color(0xFF3A2A00);
}

/// The gold "PRO" mark next to a driver's name.
///
/// Shown only where the server said the driver is PRO
/// ([PublicUser.showsProBadge]). [large] adds a crown and is for headers —
/// the profile card and the PRO screen; the compact form sits in a line of
/// text on ride cards.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key, this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final height = large ? 22.0 : 16.0;

    return Semantics(
      label: 'PRO',
      excludeSemantics: true,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: large ? 8 : 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: ProColors.gradient,
          ),
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.amber500.withValues(alpha: 0.35),
              blurRadius: large ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (large) ...[
              const Icon(
                Icons.workspace_premium_rounded,
                size: 14,
                color: ProColors.onGold,
              ),
              const SizedBox(width: 3),
            ],
            Text(
              'PRO',
              style: TextStyle(
                fontSize: large ? 11.5 : 9.5,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: ProColors.onGold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
