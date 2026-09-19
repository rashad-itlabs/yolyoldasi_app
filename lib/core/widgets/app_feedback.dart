import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../error/failure.dart';
import '../extensions/context_extensions.dart';
import '../theme/app_dimens.dart';
import '../utils/failure_message.dart';

/// Snackbars, dialogs and sheets, so feedback looks the same everywhere.
abstract final class AppFeedback {
  static void success(BuildContext context, String message) =>
      _show(context, message, _Tone.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, _Tone.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, _Tone.info);

  /// Shows the localized text for [failure].
  static void failure(BuildContext context, Failure failure) =>
      error(context, failure.message(context.l10n));

  static void _show(BuildContext context, String message, _Tone tone) {
    final palette = context.palette;
    final (background, foreground, icon) = switch (tone) {
      _Tone.success => (
        palette.success,
        palette.onSuccess,
        Icons.check_circle_rounded,
      ),
      _Tone.error => (palette.danger, palette.onDanger, Icons.error_rounded),
      _Tone.info => (
        context.colors.inverseSurface,
        context.colors.onInverseSurface,
        Icons.info_rounded,
      ),
    };

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(icon, color: foreground, size: 20),
              HGap.md,
              Expanded(
                child: Text(
                  message,
                  style: context.text.bodyMedium?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      );
  }

  /// Yes/no confirmation. Returns `true` only when the user confirms.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String? confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
  }) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actionsPadding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel ?? l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: isDestructive
                  ? context.palette.danger
                  : context.colors.primary,
            ),
            child: Text(confirmLabel ?? l10n.confirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Modal bottom sheet with the app's shape, drag handle and safe-area
  /// padding already applied.
  static Future<T?> sheet<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool useSafeArea = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      showDragHandle: true,
      backgroundColor: context.palette.surfaceElevated,
      constraints: const BoxConstraints(maxWidth: Sizes.maxContentWidth),
      builder: builder,
    );
  }
}

enum _Tone { success, error, info }

/// Standard body for a bottom sheet: title, optional subtitle, content and an
/// optional pinned action.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.page),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: context.keyboardHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                Gap.xs,
                padding.right,
                Gap.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.headlineSmall),
                  if (subtitle != null) ...[
                    VGap.xs,
                    Text(subtitle!, style: context.text.bodyMedium),
                  ],
                ],
              ),
            ),
            Flexible(child: child),
            if (action != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  padding.left,
                  Gap.lg,
                  padding.right,
                  padding.bottom,
                ),
                child: action!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Blocks interaction and shows a spinner over the current page — used for
/// short, unavoidable waits such as submitting a booking.
class BlockingProgress extends StatelessWidget {
  const BlockingProgress({super.key, this.message});

  final String? message;

  static Future<void> show(BuildContext context, {String? message}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: context.palette.overlay,
      builder: (_) => BlockingProgress(message: message),
    );
  }

  static void hide(BuildContext context) => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(Gap.xxl),
          decoration: BoxDecoration(
            color: context.palette.surfaceElevated,
            borderRadius: Radii.lgAll,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
              if (message != null) ...[
                VGap.lg,
                Text(message!, style: context.text.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Sticky action bar pinned to the bottom of a form page.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.child,
    this.secondary,
    this.caption,
  });

  final Widget child;
  final Widget? secondary;

  /// Small line above the button — price totals, validation hints.
  final Widget? caption;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: EdgeInsets.fromLTRB(
        Gap.page,
        Gap.lg,
        Gap.page,
        Gap.lg + context.bottomSafeArea,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (caption != null) ...[caption!, VGap.md],
          if (secondary == null)
            child
          else
            Row(
              children: [
                Expanded(child: secondary!),
                HGap.md,
                Expanded(flex: 2, child: child),
              ],
            ),
        ],
      ),
    );
  }
}
