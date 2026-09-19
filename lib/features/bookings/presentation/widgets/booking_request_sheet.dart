import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../rides/domain/entities/ride.dart';
import '../../domain/repositories/booking_repository.dart';
import '../bloc/booking_request/booking_request_bloc.dart';

/// Seat count + optional note, then `POST /rides/{id}/bookings`.
///
/// Returns the created booking's id when the request goes through.
class BookingRequestSheet extends StatelessWidget {
  const BookingRequestSheet({super.key, required this.ride});

  final Ride ride;

  static Future<int?> show(BuildContext context, Ride ride) {
    final bookings = context.read<BookingRepository>();
    return AppFeedback.sheet<int>(
      context,
      builder: (_) => BlocProvider<BookingRequestBloc>(
        create: (_) => BookingRequestBloc(bookings: bookings)
          ..add(
            BookingRequestStarted(
              rideId: ride.id,
              seatsAvailable: ride.seatsLeft,
              pricePerSeat: ride.pricePerSeat,
            ),
          ),
        child: BookingRequestSheet(ride: ride),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;

    return BlocConsumer<BookingRequestBloc, BookingRequestState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        final booking = state.createdBooking;
        if (state.status.isSuccess && booking != null) {
          Navigator.of(context).pop(booking.id);
          return;
        }
        // A 409 is explained inline instead — see the banner below — because
        // "try again" is the wrong advice for it (API.md §16.4).
        final failure = state.failure;
        if (state.status.isFailure &&
            failure != null &&
            !state.isDuplicateRequest) {
          AppFeedback.error(context, failure.message(l10n));
        }
      },
      builder: (context, state) {
        final bloc = context.read<BookingRequestBloc>();

        return SheetScaffold(
          title: l10n.bookingTitle,
          subtitle: ride.instantBooking
              ? l10n.instantBookingDesc
              : l10n.requestBookingDesc,
          action: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.totalPrice,
                      style: context.text.bodyMedium,
                    ),
                  ),
                  Text(
                    fmt.price(state.totalPrice),
                    style: context.text.headlineSmall?.copyWith(
                      color: context.colors.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              VGap.md,
              AppButton(
                label: ride.instantBooking ? l10n.bookNow : l10n.sendRequest,
                icon: ride.instantBooking ? Icons.bolt_rounded : null,
                onPressed: state.canSubmit
                    ? () => bloc.add(const BookingRequestSubmitted())
                    : null,
                isLoading: state.status.isBusy,
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.isDuplicateRequest) ...[
                  InfoBanner(
                    tone: BannerTone.warning,
                    title: l10n.alreadyRequestedTitle,
                    message: state.duplicateMessage(l10n),
                  ),
                  VGap.lg,
                ],

                Text(l10n.howManySeats, style: context.text.titleSmall),
                VGap.md,
                Center(
                  child: CounterStepper(
                    value: state.seats,
                    min: AppRules.minSeatsPerRide,
                    max: state.maxSelectableSeats,
                    semanticLabel: l10n.howManySeats,
                    onChanged: (value) =>
                        bloc.add(BookingRequestSeatsChanged(value)),
                  ),
                ),
                VGap.sm,
                Center(
                  child: Text(
                    '${fmt.price(ride.pricePerSeat)} · ${l10n.perSeat}',
                    style: context.text.bodySmall?.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ),
                VGap.xl,
                AppTextField(
                  label: l10n.messageToDriver,
                  hint: l10n.messageToDriverHint,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: AppRules.maxBookingMessageLength,
                  textInputAction: TextInputAction.done,
                  onChanged: (value) =>
                      bloc.add(BookingRequestMessageChanged(value)),
                ),
                VGap.md,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 15,
                      color: palette.textTertiary,
                    ),
                    HGap.sm,
                    Expanded(
                      child: Text(
                        l10n.phoneHiddenBody,
                        style: context.text.bodySmall?.copyWith(
                          color: palette.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                VGap.md,
              ],
            ),
          ),
        );
      },
    );
  }
}
