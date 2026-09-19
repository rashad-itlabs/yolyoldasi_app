import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/route_timeline.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../bookings/domain/repositories/booking_repository.dart';
import '../../domain/repositories/review_repository.dart';
import '../bloc/write_review/write_review_bloc.dart';

/// Star + comment for one completed booking — `POST /bookings/{id}/reviews`.
///
/// The API works out who is reviewing whom from the booking, so neither the
/// target nor the role is sent (API.md §12).
class WriteReviewPage extends StatelessWidget {
  const WriteReviewPage({super.key, required this.bookingId});

  final int bookingId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WriteReviewBloc>(
      create: (context) => WriteReviewBloc(
        reviews: context.read<ReviewRepository>(),
        bookings: context.read<BookingRepository>(),
      )..add(WriteReviewStarted(bookingId)),
      child: const _WriteReviewView(),
    );
  }
}

class _WriteReviewView extends StatefulWidget {
  const _WriteReviewView();

  @override
  State<_WriteReviewView> createState() => _WriteReviewViewState();
}

class _WriteReviewViewState extends State<_WriteReviewView> {
  final TextEditingController _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;

    return BlocConsumer<WriteReviewBloc, WriteReviewState>(
      listenWhen: (previous, current) =>
          previous.submitStatus != current.submitStatus,
      listener: (context, state) {
        if (state.submitStatus.isSuccess) {
          HapticFeedback.mediumImpact();
          AppFeedback.success(context, l10n.reviewSubmitted);
          Navigator.of(context).maybePop();
          return;
        }
        final failure = state.failure;
        if (state.submitStatus.isFailure &&
            failure != null &&
            !state.isDuplicate) {
          AppFeedback.error(context, failure.message(l10n));
        }
      },
      builder: (context, state) {
        final bloc = context.read<WriteReviewBloc>();

        if (state.status.isFirstLoad) {
          return AppScaffold(title: l10n.rateTrip, body: const LoadingState());
        }

        final booking = state.booking;
        if (booking == null) {
          return AppScaffold(
            title: l10n.rateTrip,
            body: ErrorState(failure: state.failure),
          );
        }

        final other = state.target;

        return DismissKeyboard(
          child: AppScaffold(
            title: l10n.rateTrip,
            body: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.xl,
                Gap.page,
                Gap.xxl,
              ),
              children: [
                if (state.isDuplicate || state.alreadyReviewed) ...[
                  InfoBanner(
                    tone: BannerTone.info,
                    message: l10n.alreadyReviewedBody,
                  ),
                  VGap.lg,
                ] else if (!state.isReviewable) ...[
                  // Only a `completed` booking can be reviewed, and only for a
                  // fortnight afterwards.
                  InfoBanner(
                    tone: BannerTone.warning,
                    message: l10n.errBookingNotCancellable,
                  ),
                  VGap.lg,
                ],

                Center(
                  child: Column(
                    children: [
                      AppAvatar(
                        name: other?.fullName,
                        photoUrl: other?.photoUrl,
                        size: Sizes.avatarXl,
                        isVerified: other?.hasDriverProfile ?? false,
                      ),
                      VGap.lg,
                      Text(
                        fmt.shortName(other?.fullName),
                        style: context.text.headlineSmall,
                      ),
                      VGap.xs,
                      RouteLabel(
                        fromCity: booking.ride.fromCity,
                        toCity: booking.ride.toCity,
                        style: context.text.bodyMedium,
                        iconSize: 14,
                      ),
                      VGap.xs,
                      Text(
                        fmt.fullDate(booking.ride.departureAt),
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),

                VGap.xxxl,
                Text(
                  l10n.yourRating,
                  textAlign: TextAlign.center,
                  style: context.text.titleSmall,
                ),
                VGap.md,
                StarPicker(
                  value: state.draft.rating,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    bloc.add(WriteReviewRatingChanged(value));
                  },
                ),
                VGap.sm,
                SizedBox(
                  height: 22,
                  child: Center(
                    child: Text(
                      fmt.ratingWord(state.draft.rating),
                      style: context.text.labelLarge?.copyWith(
                        color: palette.accent,
                      ),
                    ),
                  ),
                ),

                VGap.xxl,
                AppTextField(
                  controller: _comment,
                  label: l10n.writeComment,
                  hint: l10n.writeCommentHint,
                  maxLines: 5,
                  minLines: 3,
                  maxLength: AppRules.maxReviewLength,
                  showCounter: true,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (value) =>
                      bloc.add(WriteReviewCommentChanged(value)),
                ),
              ],
            ),
            bottomBar: BottomActionBar(
              child: AppButton(
                label: l10n.submitReview,
                isLoading: state.submitStatus.isBusy,
                onPressed: state.canSubmit
                    ? () => bloc.add(const WriteReviewSubmitted())
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
