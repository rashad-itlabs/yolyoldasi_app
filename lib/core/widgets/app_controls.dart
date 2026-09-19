import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_dimens.dart';

/// Minus / number / plus stepper for seat counts.
class CounterStepper extends StatelessWidget {
  const CounterStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 4,
    this.semanticLabel,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String? semanticLabel;

  void _step(int delta) {
    final next = (value + delta).clamp(min, max);
    if (next == value) return;
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget button(IconData icon, int delta, bool enabled) {
      return Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: enabled ? () => _step(delta) : null,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: enabled ? palette.borderStrong : palette.border,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: enabled ? palette.textPrimary : palette.textTertiary,
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: semanticLabel,
      value: '$value',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, -1, value > min),
          SizedBox(
            width: 56,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: context.text.headlineSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          button(Icons.add_rounded, 1, value < max),
        ],
      ),
    );
  }
}

/// Two-or-more option segmented control.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.expand = true,
  });

  final T value;
  final List<({T value, String label, IconData? icon})> options;
  final ValueChanged<T> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: Radii.mdAll,
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final option in options)
            Expanded(
              flex: expand ? 1 : 0,
              child: _SegmentButton(
                label: option.label,
                icon: option.icon,
                selected: option.value == value,
                onTap: () {
                  if (option.value == value) return;
                  HapticFeedback.selectionClick();
                  onChanged(option.value);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.standard,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.surfaceElevated : Colors.transparent,
          borderRadius: Radii.smAll,
          boxShadow: selected ? palette.cardShadow : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 17,
                color: selected ? context.colors.primary : palette.textTertiary,
              ),
              HGap.sm,
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(
                  color: selected ? palette.textPrimary : palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin progress bar for multi-step flows.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: Motion.normal,
              curve: Motion.emphasized,
              height: 5,
              decoration: BoxDecoration(
                color: i < current ? context.colors.primary : palette.border,
                borderRadius: Radii.pillAll,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Selectable option row with a leading icon, used for role and language
/// pickers.
class SelectableTile extends StatelessWidget {
  const SelectableTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer.withValues(alpha: 0.45)
              : palette.surfaceElevated,
          borderRadius: Radii.lgAll,
          border: Border.all(
            color: selected ? colors.primary : palette.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? colors.primary : palette.surfaceSunken,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: selected ? colors.onPrimary : palette.textSecondary,
                ),
              ),
              HGap.lg,
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  if (subtitle != null) ...[
                    VGap.xs,
                    Text(subtitle!, style: context.text.bodySmall),
                  ],
                ],
              ),
            ),
            trailing ??
                AnimatedContainer(
                  duration: Motion.fast,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.primary : Colors.transparent,
                    border: Border.all(
                      color: selected ? colors.primary : palette.borderStrong,
                      width: 1.8,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: colors.onPrimary,
                        )
                      : null,
                ),
          ],
        ),
      ),
    );
  }
}
