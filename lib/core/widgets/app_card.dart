import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_dimens.dart';
import 'pressable.dart';

/// The app's surface primitive: a bordered, softly shadowed container.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.margin,
    this.borderRadius = Radii.lgAll,
    this.color,
    this.borderColor,
    this.elevated = true,
    this.clip = Clip.antiAlias,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final Color? color;
  final Color? borderColor;

  /// Adds the soft drop shadow. Turn off for cards nested inside other cards.
  final bool elevated;

  final Clip clip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? palette.surfaceElevated,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? palette.border),
        boxShadow: elevated ? palette.cardShadow : null,
      ),
      clipBehavior: clip,
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return card;
    return Pressable(onTap: onTap, borderRadius: borderRadius, child: card);
  }
}

/// Section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: Gap.md),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium),
                if (subtitle != null) ...[
                  VGap.xs,
                  Text(subtitle!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Inline information / warning strip.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.info_outline_rounded,
    this.tone = BannerTone.info,
    this.action,
  });

  final String message;
  final String? title;
  final IconData icon;
  final BannerTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (background, foreground) = switch (tone) {
      BannerTone.info => (palette.infoContainer, palette.onInfoContainer),
      BannerTone.success => (
        palette.successContainer,
        palette.onSuccessContainer,
      ),
      BannerTone.warning => (
        palette.warningContainer,
        palette.onWarningContainer,
      ),
      BannerTone.danger => (palette.dangerContainer, palette.onDangerContainer),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(color: background, borderRadius: Radii.mdAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          HGap.md,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: context.text.titleSmall?.copyWith(color: foreground),
                  ),
                  VGap.xs,
                ],
                Text(
                  message,
                  style: context.text.bodySmall?.copyWith(color: foreground),
                ),
                if (action != null) ...[VGap.sm, action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum BannerTone { info, success, warning, danger }
