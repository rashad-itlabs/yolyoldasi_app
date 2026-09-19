import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_dimens.dart';

/// The app icon mark: a rounded tile carrying a stylised route between two
/// stops. Drawn rather than shipped as an asset so it scales and re-colours
/// with the theme.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 64,
    this.showTile = true,
    this.alignment = Alignment.centerLeft,
  });

  final double size;

  /// Draw the gradient tile behind the glyph.
  final bool showTile;

  /// Where the mark sits when the parent forces it wider than [size].
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final glyph = CustomPaint(
      size: Size.square(size),
      painter: _RouteGlyphPainter(
        lineColor: showTile ? Colors.white : context.colors.primary,
        accentColor: showTile ? palette.accent : palette.accent,
      ),
    );

    final mark = showTile
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette.heroGradient,
              ),
            ),
            child: glyph,
          )
        : SizedBox.square(dimension: size, child: glyph);

    // A `ListView` hands its children a tight width, which would stretch the
    // tile into a rectangle. `Align` keeps the mark square under any
    // constraints and shrink-wraps when they are loose (inside a Row).
    return Align(
      alignment: alignment,
      widthFactor: 1,
      heightFactor: 1,
      child: mark,
    );
  }
}

class _RouteGlyphPainter extends CustomPainter {
  const _RouteGlyphPainter({
    required this.lineColor,
    required this.accentColor,
  });

  final Color lineColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.28, h * 0.72)
      ..cubicTo(w * 0.28, h * 0.46, w * 0.72, h * 0.56, w * 0.72, h * 0.30);

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.075
        ..strokeCap = StrokeCap.round,
    );

    // Origin dot (hollow) and destination pin (filled accent).
    canvas.drawCircle(
      Offset(w * 0.28, h * 0.72),
      w * 0.085,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06,
    );
    canvas.drawCircle(
      Offset(w * 0.72, h * 0.30),
      w * 0.105,
      Paint()..color = accentColor,
    );
  }

  @override
  bool shouldRepaint(_RouteGlyphPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.accentColor != accentColor;
}

/// Wordmark: the glyph beside the app name.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 36, this.showTagline = false});

  final double size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: size),
            HGap.md,
            Text(
              context.l10n.appName,
              style: context.text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
        if (showTagline) ...[
          VGap.sm,
          Text(
            context.l10n.appTagline,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium,
          ),
        ],
      ],
    );
  }
}

/// Abstract scene used on the onboarding pages.
///
/// Three variants keyed by [index], all built from the same primitives so the
/// set feels like one illustration family.
///
/// The size is driven by the *height* available rather than the width, so a
/// short screen shrinks the art instead of pushing the copy off the page.
class OnboardingArt extends StatelessWidget {
  const OnboardingArt({super.key, required this.index, this.maxHeight = 260});

  final int index;
  final double maxHeight;

  static const double _aspectRatio = 1.25;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = context.colors;

    final height = math.min(
      math.min(maxHeight, context.screenHeight * 0.3),
      context.screenWidth * 0.72 / _aspectRatio,
    );

    return SizedBox(
      height: height,
      width: height * _aspectRatio,
      child: CustomPaint(
        painter: _OnboardingPainter(
          index: index,
          primary: colors.primary,
          soft: colors.primaryContainer,
          accent: palette.accent,
          surface: palette.surfaceElevated,
          outline: palette.border,
        ),
      ),
    );
  }
}

class _OnboardingPainter extends CustomPainter {
  const _OnboardingPainter({
    required this.index,
    required this.primary,
    required this.soft,
    required this.accent,
    required this.surface,
    required this.outline,
  });

  final int index;
  final Color primary;
  final Color soft;
  final Color accent;
  final Color surface;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // Shared backdrop: a soft disc with an orbiting ring.
    canvas.drawCircle(
      center,
      h * 0.42,
      Paint()..color = soft.withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      center,
      h * 0.48,
      Paint()
        ..color = primary.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    switch (index) {
      case 0:
        _paintRoute(canvas, size);
      case 1:
        _paintSplit(canvas, size);
      default:
        _paintShield(canvas, size);
    }
  }

  /// Page 1 — a winding route with stops along it.
  void _paintRoute(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.22, h * 0.74)
      ..cubicTo(w * 0.36, h * 0.74, w * 0.34, h * 0.42, w * 0.50, h * 0.42)
      ..cubicTo(w * 0.66, h * 0.42, w * 0.64, h * 0.26, w * 0.78, h * 0.26);

    canvas.drawPath(
      path,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.035
        ..strokeCap = StrokeCap.round,
    );

    _stop(canvas, Offset(w * 0.22, h * 0.74), h * 0.05, filled: false);
    _stop(
      canvas,
      Offset(w * 0.50, h * 0.42),
      h * 0.036,
      filled: true,
      color: accent,
    );
    _stop(canvas, Offset(w * 0.78, h * 0.26), h * 0.05, filled: true);
  }

  /// Page 2 — two halves of a coin, the shared cost.
  void _paintSplit(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = h * 0.2;

    canvas.drawCircle(Offset(w * 0.40, h * 0.5), r, Paint()..color = primary);
    canvas.drawCircle(Offset(w * 0.62, h * 0.5), r, Paint()..color = accent);
    canvas.drawCircle(
      Offset(w * 0.62, h * 0.5),
      r,
      Paint()
        ..color = surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.02,
    );

    // A seat row underneath.
    for (var i = 0; i < 4; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * (0.30 + i * 0.11), h * 0.76, w * 0.075, h * 0.075),
        Radius.circular(h * 0.02),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = i < 3 ? primary.withValues(alpha: 0.35) : outline,
      );
    }
  }

  /// Page 3 — a shield with a check, for trust and verification.
  void _paintShield(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.5, h * 0.26)
      ..lineTo(w * 0.68, h * 0.36)
      ..lineTo(w * 0.68, h * 0.56)
      ..cubicTo(w * 0.68, h * 0.68, w * 0.60, h * 0.74, w * 0.5, h * 0.78)
      ..cubicTo(w * 0.40, h * 0.74, w * 0.32, h * 0.68, w * 0.32, h * 0.56)
      ..lineTo(w * 0.32, h * 0.36)
      ..close();

    canvas.drawPath(path, Paint()..color = primary);

    final check = Path()
      ..moveTo(w * 0.43, h * 0.52)
      ..lineTo(w * 0.48, h * 0.58)
      ..lineTo(w * 0.58, h * 0.44);
    canvas.drawPath(
      check,
      Paint()
        ..color = surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.035
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Small stars for the mutual-rating idea.
    for (var i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + (i - 1) * 0.55;
      final offset = Offset(
        w * 0.5 + math.cos(angle) * w * 0.30,
        h * 0.52 + math.sin(angle) * h * 0.36,
      );
      canvas.drawCircle(offset, h * 0.022, Paint()..color = accent);
    }
  }

  void _stop(
    Canvas canvas,
    Offset center,
    double radius, {
    required bool filled,
    Color? color,
  }) {
    final paint = Paint()..color = color ?? primary;
    if (filled) {
      canvas.drawCircle(center, radius, paint);
      canvas.drawCircle(center, radius * 0.42, Paint()..color = surface);
    } else {
      canvas.drawCircle(center, radius, Paint()..color = surface);
      canvas.drawCircle(
        center,
        radius,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(_OnboardingPainter oldDelegate) =>
      oldDelegate.index != index || oldDelegate.primary != primary;
}
