import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../profile/presentation/bloc/public_profile/public_profile_bloc.dart';
import '../../domain/entities/review.dart';

/// Average, star histogram and the reviews themselves.
///
/// Reads [PublicProfileBloc], which owns both the profile and the reviews for
/// the role currently selected — `GET /users/{id}/reviews?role=` (API.md §12).
class ReviewList extends StatelessWidget {
  const ReviewList({super.key, this.shrinkWrap = false, this.physics});

  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<PublicProfileBloc, PublicProfileState>(
      builder: (context, state) {
        if (state.reviewsStatus.isFirstLoad && !state.hasReviews) {
          return ListSkeleton(count: 2, shrinkWrap: shrinkWrap);
        }

        final items = state.reviews.items;
        if (items.isEmpty) {
          // A read that failed is not a person without reviews — saying "no
          // reviews yet" would be a lie, and would swallow the retry.
          final userId = state.userId;
          if (state.reviewsStatus.isFailure && userId != null) {
            return ErrorState(
              failure: state.failure,
              compact: true,
              onRetry: () => context.read<PublicProfileBloc>().add(
                PublicProfileRequested(userId),
              ),
            );
          }
          return EmptyState(
            icon: Icons.star_outline_rounded,
            title: l10n.noReviews,
            message: l10n.noReviewsBody,
            compact: true,
          );
        }

        final summary = state.summary;

        return ListView(
          shrinkWrap: shrinkWrap,
          physics: physics,
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.lg,
            Gap.page,
            Gap.xxxl,
          ),
          children: [
            if (summary.count > 0) ...[_SummaryCard(summary: summary), VGap.xl],
            for (final review in items) ...[
              _ReviewTile(review: review),
              VGap.md,
            ],
            if (state.reviews.hasMore)
              Center(
                child: TextButton(
                  onPressed: () => context.read<PublicProfileBloc>().add(
                    const PublicProfileMoreReviewsRequested(),
                  ),
                  child: Text(l10n.loadMore),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              Text(
                summary.average.toStringAsFixed(1),
                style: context.text.displaySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final filled = index < summary.average.round();
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 14,
                    color: filled ? palette.accent : palette.borderStrong,
                  );
                }),
              ),
              VGap.xs,
              Text(
                context.l10n.reviewsCount(summary.count),
                style: context.text.labelSmall?.copyWith(
                  color: palette.textTertiary,
                ),
              ),
            ],
          ),
          HGap.xl,
          Expanded(
            child: Column(
              children: [
                for (var stars = 5; stars >= 1; stars--)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 10,
                          child: Text(
                            '$stars',
                            style: context.text.labelSmall?.copyWith(
                              color: palette.textTertiary,
                            ),
                          ),
                        ),
                        HGap.sm,
                        Expanded(
                          child: ClipRRect(
                            borderRadius: Radii.pillAll,
                            child: LinearProgressIndicator(
                              value: summary.fractionOf(stars),
                              minHeight: 6,
                              backgroundColor: palette.border,
                              valueColor: AlwaysStoppedAnimation(
                                palette.accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final palette = context.palette;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                name: review.author?.fullName,
                photoUrl: review.author?.photoUrl,
                size: Sizes.avatarSm + 4,
              ),
              HGap.md,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fmt.shortName(review.author?.fullName),
                      style: context.text.titleSmall,
                    ),
                    Text(
                      fmt.relative(review.createdAt),
                      style: context.text.labelSmall?.copyWith(
                        color: palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final filled = index < review.rating;
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 15,
                    color: filled ? palette.accent : palette.borderStrong,
                  );
                }),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            VGap.md,
            Text(review.comment, style: context.text.bodyLarge),
          ],
        ],
      ),
    );
  }
}
