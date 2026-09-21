import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../domain/entities/ride.dart';
import '../../../domain/entities/ride_draft.dart';
import '../../../domain/repositories/ride_repository.dart';

part 'publish_ride_event.dart';
part 'publish_ride_state.dart';

/// `POST /rides` and `PUT /rides/{id}` — the multi-step publish form.
class PublishRideBloc extends Bloc<PublishRideEvent, PublishRideState> {
  PublishRideBloc({required RideRepository rides})
    : _rides = rides,
      super(const PublishRideState()) {
    on<PublishRideStarted>(_onStarted);
    on<PublishRideFieldChanged>(_onFieldChanged);
    on<PublishRideRouteSwapped>(_onRouteSwapped);
    on<PublishRideStepChanged>(_onStepChanged);
    on<PublishRideSubmitted>(_onSubmitted);
    on<PublishRideFailureCleared>(_onFailureCleared);
  }

  final RideRepository _rides;

  Future<void> _onStarted(
    PublishRideStarted event,
    Emitter<PublishRideState> emit,
  ) async {
    final rideId = event.rideId;
    if (rideId == null) {
      final prefill = event.prefill;

      emit(
        PublishRideState(
          draft: RideDraft(
            vehicleId: event.vehicleId,
            instantBooking: event.instantBookingDefault,
            fromCityId: prefill?.fromCityId,
            toCityId: prefill?.toCityId,
            date: prefill?.date,
          ),
          // Straight to the schedule step when the route came with the
          // request: re-confirming a route the driver just tapped on is a
          // step that only costs them patience.
          step: prefill == null ? PublishStep.route : PublishStep.schedule,
          loadStatus: DataStatus.success,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        rideId: () => rideId,
        loadStatus: DataStatus.loading,
        failure: () => null,
      ),
    );

    final result = await _rides.byId(rideId);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            draft: RideDraft.fromRide(value),
            loadStatus: DataStatus.success,
            // Route and car cannot change on an edit, so the form opens on the
            // first step that can.
            step: PublishStep.schedule,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            loadStatus: DataStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }

  void _onFieldChanged(
    PublishRideFieldChanged event,
    Emitter<PublishRideState> emit,
  ) {
    emit(
      state.copyWith(
        draft: state.draft.copyWith(
          vehicleId: event.vehicleId == null ? null : () => event.vehicleId,
          fromCityId: event.fromCityId == null ? null : () => event.fromCityId,
          toCityId: event.toCityId == null ? null : () => event.toCityId,
          date: event.date == null ? null : () => event.date,
          timeOfDayMinutes: event.timeOfDayMinutes == null
              ? null
              : () => event.timeOfDayMinutes,
          totalSeats: event.totalSeats,
          pricePerSeat: event.pricePerSeat == null
              ? null
              : () => event.pricePerSeat,
          note: event.note,
          pickupPoint: event.pickupPoint,
          dropoffPoint: event.dropoffPoint,
          instantBooking: event.instantBooking,
          womenOnly: event.womenOnly,
          repeatWeeks: event.repeatWeeks,
        ),
        failure: () => null,
      ),
    );
  }

  void _onRouteSwapped(
    PublishRideRouteSwapped event,
    Emitter<PublishRideState> emit,
  ) {
    if (!state.canEditRoute) return;
    emit(state.copyWith(draft: state.draft.swapped()));
  }

  void _onStepChanged(
    PublishRideStepChanged event,
    Emitter<PublishRideState> emit,
  ) {
    emit(state.copyWith(step: event.step, failure: () => null));
  }

  Future<void> _onSubmitted(
    PublishRideSubmitted event,
    Emitter<PublishRideState> emit,
  ) async {
    if (!state.canSubmit) return;

    emit(
      state.copyWith(
        submitStatus: ActionStatus.inProgress,
        publishedRide: () => null,
        failure: () => null,
      ),
    );

    final rideId = state.rideId;
    final result = rideId == null
        ? await _rides.publish(state.draft)
        : await _rides.update(rideId, state.draft);

    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            submitStatus: ActionStatus.success,
            publishedRide: () => value,
          ),
        );
      case Err(:final failure):
        // Common 422s here: no driver profile, somebody else's car, or
        // `total_seats` dropped below `booked_seats` on an edit. All of them
        // arrive as prose in `message`, which the error banner shows verbatim.
        emit(
          state.copyWith(
            submitStatus: ActionStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }

  void _onFailureCleared(
    PublishRideFailureCleared event,
    Emitter<PublishRideState> emit,
  ) {
    emit(state.copyWith(failure: () => null, submitStatus: ActionStatus.idle));
  }
}
