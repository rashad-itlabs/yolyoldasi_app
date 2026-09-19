import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../error/failure.dart';
import '../extensions/context_extensions.dart';
import '../theme/app_dimens.dart';
import '../utils/failure_message.dart';
import 'app_button.dart';

/// Friendly empty state with an illustration slot and an optional call to
/// action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Gap.xxxl,
          vertical: compact ? Gap.xxl : Gap.huge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 64 : 88,
              height: compact ? 64 : 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.primaryContainer.withValues(alpha: 0.55),
              ),
              child: Icon(
                icon,
                size: compact ? 30 : 40,
                color: context.colors.primary,
              ),
            ),
            VGap.xl,
            Text(
              title,
              textAlign: TextAlign.center,
              style: compact
                  ? context.text.titleMedium
                  : context.text.titleLarge,
            ),
            if (message != null) ...[
              VGap.sm,
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              VGap.xl,
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
                size: AppButtonSize.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state that reads a [Failure] and only offers "retry" when retrying
/// could actually help.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.failure,
    this.message,
    this.onRetry,
    this.compact = false,
  });

  final Failure? failure;
  final String? message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = message ?? failure?.message(l10n) ?? l10n.errUnknown;
    final canRetry = onRetry != null && (failure?.isRetryable ?? true);

    return EmptyState(
      title: l10n.errorTitle,
      message: text,
      icon: failure?.code == FailureCode.network
          ? Icons.wifi_off_rounded
          : Icons.error_outline_rounded,
      actionLabel: canRetry ? l10n.retry : null,
      onAction: canRetry ? onRetry : null,
      compact: compact,
    );
  }
}

/// Centered spinner sized for full-page use.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}

/// Grey block that shimmers — the building block of every skeleton.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = Radii.smAll,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.shimmerBase,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// Wraps skeleton children in the shimmer sweep.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Shimmer.fromColors(
      baseColor: palette.shimmerBase,
      highlightColor: palette.shimmerHighlight,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// Placeholder shaped like a ride card, shown while search results load.
class RideCardSkeleton extends StatelessWidget {
  const RideCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: context.palette.surfaceElevated,
          borderRadius: Radii.lgAll,
          border: Border.all(color: context.palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkeletonBox(width: 54, height: 16),
                HGap.md,
                const Expanded(child: SkeletonBox(height: 16)),
                HGap.md,
                const SkeletonBox(width: 60, height: 20),
              ],
            ),
            VGap.lg,
            const SkeletonBox(width: 180, height: 12),
            VGap.sm,
            const SkeletonBox(width: 120, height: 12),
            VGap.lg,
            Row(
              children: [
                const SkeletonBox(
                  width: 40,
                  height: 40,
                  borderRadius: Radii.pillAll,
                ),
                HGap.md,
                const Expanded(child: SkeletonBox(height: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A stack of [RideCardSkeleton]s for list placeholders.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 4, this.shrinkWrap = false});

  final int count;

  /// Set when this sits inside another scrollable, which cannot give it a
  /// bounded height.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(Gap.page),
      itemCount: count,
      shrinkWrap: shrinkWrap,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, _) => VGap.md,
      itemBuilder: (_, _) => const RideCardSkeleton(),
    );
  }
}
