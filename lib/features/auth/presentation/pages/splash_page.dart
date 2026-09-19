import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/brand_mark.dart';

/// Shown while the stored token is restored and `GET /me` answers. The router
/// replaces it as soon as the session leaves `SessionStatus.booting`.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette.heroGradient,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(
                    size: 88,
                    showTile: false,
                    alignment: Alignment.center,
                  )
                  .animate()
                  .fadeIn(duration: 420.ms)
                  .scale(
                    begin: const Offset(0.85, 0.85),
                    curve: Curves.easeOutBack,
                  ),
              VGap.xxl,
              Text(
                context.l10n.appName,
                style: context.text.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ).animate().fadeIn(delay: 180.ms, duration: 400.ms),
              VGap.sm,
              Text(
                context.l10n.appTagline,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ).animate().fadeIn(delay: 320.ms, duration: 400.ms),
              VGap.huge,
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}
