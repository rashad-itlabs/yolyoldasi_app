import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_dimens.dart';

enum AppButtonVariant { primary, secondary, tonal, ghost, danger }

enum AppButtonSize { regular, compact }

/// The app's single button.
///
/// Wrapping Material's buttons keeps three things consistent everywhere: the
/// loading state (which locks the size so the layout cannot jump), the icon
/// spacing, and the disabled colours.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.regular,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = true,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.regular,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.tonal({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.regular,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.tonal;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.compact,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.regular,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;

  /// Whether the button stretches to the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = context.colors;
    final enabled = onPressed != null && !isLoading;

    final height = size == AppButtonSize.regular
        ? Sizes.buttonHeight
        : Sizes.buttonHeightCompact;

    final (background, foreground, border) = switch (variant) {
      AppButtonVariant.primary => (colors.primary, colors.onPrimary, null),
      AppButtonVariant.secondary => (
        Colors.transparent,
        palette.textPrimary,
        palette.borderStrong,
      ),
      AppButtonVariant.tonal => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
        null,
      ),
      AppButtonVariant.ghost => (Colors.transparent, colors.primary, null),
      AppButtonVariant.danger => (palette.danger, palette.onDanger, null),
    };

    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? (variant == AppButtonVariant.secondary ||
                      variant == AppButtonVariant.ghost
                  ? Colors.transparent
                  : palette.border)
            : background,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? palette.textTertiary
            : foreground,
      ),
      overlayColor: WidgetStatePropertyAll(foreground.withValues(alpha: 0.08)),
      side: border == null
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.disabled)
                    ? palette.border
                    : border,
              ),
            ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: Radii.mdAll),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: size == AppButtonSize.regular ? Gap.xxl : Gap.lg,
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        size == AppButtonSize.regular
            ? context.text.labelLarge
            : context.text.labelMedium,
      ),
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: WidgetStatePropertyAll(
        Size(expand ? double.infinity : 0, height),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      animationDuration: Motion.fast,
    );

    final content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              // Keeps contrast on the filled variants.
              color:
                  variant == AppButtonVariant.primary ||
                      variant == AppButtonVariant.danger
                  ? foreground
                  : colors.primary,
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), HGap.sm],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              if (trailingIcon != null) ...[
                HGap.sm,
                Icon(trailingIcon, size: 20),
              ],
            ],
          );

    final button = TextButton(
      onPressed: enabled ? onPressed : null,
      style: style,
      child: content,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Circular icon button used in app bars and on image overlays.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.filled = false,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// Gives the button its own surface — needed over photos and gradients.
  final bool filled;

  /// Shows a count bubble; `0` hides it.
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget button = IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      style: filled
          ? IconButton.styleFrom(
              backgroundColor: palette.surfaceElevated,
              foregroundColor: palette.textPrimary,
              shape: const CircleBorder(),
            )
          : null,
    );

    if (badgeCount > 0) {
      button = Badge.count(
        count: badgeCount,
        backgroundColor: palette.danger,
        textColor: palette.onDanger,
        offset: const Offset(-4, 4),
        child: button,
      );
    }
    return button;
  }
}
