import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_dimens.dart';

enum ChipTone { neutral, brand, success, warning, danger, info, accent }

/// Small pill used for statuses, counts and badges.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = ChipTone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final ChipTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = context.colors;

    final (background, foreground) = switch (tone) {
      ChipTone.neutral => (palette.surfaceSunken, palette.textSecondary),
      ChipTone.brand => (colors.primaryContainer, colors.onPrimaryContainer),
      ChipTone.success => (
        palette.successContainer,
        palette.onSuccessContainer,
      ),
      ChipTone.warning => (
        palette.warningContainer,
        palette.onWarningContainer,
      ),
      ChipTone.danger => (palette.dangerContainer, palette.onDangerContainer),
      ChipTone.info => (palette.infoContainer, palette.onInfoContainer),
      ChipTone.accent => (
        palette.accent.withValues(alpha: 0.16),
        palette.accent,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? Gap.sm : Gap.md,
        vertical: dense ? 3 : Gap.xs + 1,
      ),
      decoration: BoxDecoration(color: background, borderRadius: Radii.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: foreground),
            const SizedBox(width: Gap.xs),
          ],
          Text(
            label,
            style: (dense ? context.text.labelSmall : context.text.labelMedium)
                ?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// Star rating readout: `★ 4.8 (47)`.
class RatingLabel extends StatelessWidget {
  const RatingLabel({
    super.key,
    required this.rating,
    this.reviewCount,
    this.compact = false,
  });

  final double rating;
  final int? reviewCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasRating = rating > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded,
          size: compact ? 14 : 16,
          color: hasRating ? palette.accent : palette.textTertiary,
        ),
        const SizedBox(width: 2),
        Text(
          context.fmt.rating(rating),
          style: (compact ? context.text.labelSmall : context.text.labelMedium)
              ?.copyWith(
                color: hasRating ? palette.textPrimary : palette.textTertiary,
              ),
        ),
        if (reviewCount != null && reviewCount! > 0) ...[
          const SizedBox(width: 3),
          Text(
            '($reviewCount)',
            style:
                (compact ? context.text.labelSmall : context.text.labelMedium)
                    ?.copyWith(color: palette.textTertiary),
          ),
        ],
      ],
    );
  }
}

/// Interactive 1–5 star picker.
class StarPicker extends StatelessWidget {
  const StarPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 40,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final star = index + 1;
        final selected = star <= value;
        return Semantics(
          button: true,
          label: '$star',
          child: IconButton(
            onPressed: () => onChanged(star),
            iconSize: size,
            padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
            constraints: const BoxConstraints(),
            icon: AnimatedScale(
              scale: selected ? 1 : 0.88,
              duration: Motion.fast,
              curve: Motion.spring,
              child: Icon(
                selected ? Icons.star_rounded : Icons.star_outline_rounded,
                color: selected ? palette.accent : palette.borderStrong,
              ),
            ),
          ),
        );
      }),
    );
  }
}
