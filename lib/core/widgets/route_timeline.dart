import 'package:flutter/material.dart';

import '../../features/cities/domain/entities/city.dart';
import '../../features/profile/domain/entities/vehicle.dart';
import '../extensions/context_extensions.dart';
import '../theme/app_dimens.dart';

/// Vertical origin → destination timeline with times on the left.
///
/// The visual backbone of ride cards and the ride detail page.
class RouteTimeline extends StatelessWidget {
  const RouteTimeline({
    super.key,
    required this.fromCity,
    required this.toCity,
    required this.departureAt,
    this.arrivalAt,
    this.pickupPoint,
    this.dropoffPoint,
    this.compact = false,
  });

  final City fromCity;
  final City toCity;
  final DateTime departureAt;
  final DateTime? arrivalAt;
  final String? pickupPoint;
  final String? dropoffPoint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;
    final colors = context.colors;

    // `null` when either city is missing from the local coordinate table, in
    // which case the arrival estimate is simply left out.
    final duration = City.estimatedDrive(fromCity, toCity);

    // The time column is fixed-width so the two city names line up under each
    // other — but the width has to follow the type, not a constant. At 14pt,
    // 46pt fits "16:48"; on a tablet, where the theme scales type up, or for a
    // reader who has turned system text up, the same 46pt splits the clock
    // across two lines as "16:4 / 8".
    //
    // 3.3 ems is that same 46pt expressed in a unit that travels: the digits
    // are tabular, so the ratio holds at every size.
    final timeStyle = context.text.titleSmall;
    final timeWidth =
        MediaQuery.textScalerOf(context).scale(timeStyle?.fontSize ?? 14) * 3.3;

    Widget stop({
      required String time,
      required String city,
      required String? detail,
      required bool isOrigin,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: timeWidth,
            child: Text(
              time,
              style: timeStyle?.copyWith(
                color: isOrigin ? palette.textPrimary : palette.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          HGap.md,
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOrigin ? colors.primary : palette.surfaceElevated,
                border: Border.all(
                  color: isOrigin ? colors.primary : palette.borderStrong,
                  width: 2.2,
                ),
              ),
            ),
          ),
          HGap.md,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city,
                  style: context.text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    final connectorHeight = compact ? 18.0 : 26.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stop(
          time: fmt.time(departureAt),
          city: fromCity.nameFor(l10n.languageCode),
          detail: pickupPoint,
          isOrigin: true,
        ),
        // Dashed connector with the estimated drive time beside it.
        SizedBox(
          height: connectorHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: timeWidth + Gap.md + 5),
              SizedBox(
                width: 1.6,
                child: CustomPaint(
                  painter: _DashedLinePainter(color: palette.borderStrong),
                ),
              ),
              const SizedBox(width: Gap.md + 5 - 1.6),
              if (duration != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    fmt.duration(duration),
                    style: context.text.labelSmall?.copyWith(
                      color: palette.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        stop(
          time: fmt.time(
            arrivalAt ??
                (duration == null ? departureAt : departureAt.add(duration)),
          ),
          city: toCity.nameFor(l10n.languageCode),
          detail: dropoffPoint,
          isOrigin: false,
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;

    const dash = 3.0;
    const gap = 4.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + dash).clamp(0, size.height)),
        paint,
      );
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// One-line `Bakı → Gəncə` label.
class RouteLabel extends StatelessWidget {
  const RouteLabel({
    super.key,
    required this.fromCity,
    required this.toCity,
    this.style,
    this.iconSize = 16,
  });

  final City fromCity;
  final City toCity;
  final TextStyle? style;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final code = context.l10n.languageCode;
    final from = fromCity.nameFor(code);
    final to = toCity.nameFor(code);
    final textStyle = style ?? context.text.titleMedium;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            from,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: iconSize,
            color: context.palette.textTertiary,
          ),
        ),
        Flexible(
          child: Text(
            to,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Coloured dot matching the vehicle's stored colour.
///
/// The API stores `color` as free text (API.md §8), so the value is matched
/// back to a swatch by name; anything unrecognised falls back to the neutral
/// "other" swatch rather than disappearing.
class VehicleColorDot extends StatelessWidget {
  const VehicleColorDot({super.key, required this.colorValue, this.size = 10});

  final String? colorValue;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(VehicleColors.swatchForValue(colorValue)),
        border: Border.all(color: context.palette.borderStrong, width: 0.8),
      ),
    );
  }
}
