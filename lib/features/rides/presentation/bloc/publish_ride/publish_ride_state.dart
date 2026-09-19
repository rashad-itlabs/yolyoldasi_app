part of 'publish_ride_bloc.dart';

/// The publish form's steps, in order.
///
/// Three rather than four: each screen stays a handful of decisions, which
/// matters on a phone at the roadside.
enum PublishStep {
  route,
  schedule,
  details;

  PublishStep? get next {
    final index = PublishStep.values.indexOf(this) + 1;
    return index < PublishStep.values.length ? PublishStep.values[index] : null;
  }

  PublishStep? get previous {
    final index = PublishStep.values.indexOf(this) - 1;
    return index >= 0 ? PublishStep.values[index] : null;
  }

  int get number => PublishStep.values.indexOf(this) + 1;
  static int get count => PublishStep.values.length;
}

class PublishRideState extends Equatable {
  const PublishRideState({
    this.draft = const RideDraft(),
    this.step = PublishStep.route,
    this.rideId,
    this.loadStatus = DataStatus.initial,
    this.submitStatus = ActionStatus.idle,
    this.publishedRide,
    this.failure,
  });

  final RideDraft draft;
  final PublishStep step;

  /// Set when editing an existing ride.
  final int? rideId;

  /// Only used while loading the ride being edited.
  final DataStatus loadStatus;

  final ActionStatus submitStatus;

  /// The ride the API returned, for the page to navigate to.
  final Ride? publishedRide;

  final Failure? failure;

  bool get isEditing => rideId != null;

  /// API.md §9 lists what an edit may change: the route and the car are not on
  /// it, so those steps are read-only when editing.
  bool get canEditRoute => !isEditing;

  bool get canContinue => switch (step) {
    PublishStep.route => draft.isRouteValid && draft.isVehicleValid,
    PublishStep.schedule => draft.isScheduleValid,
    // The last step submits, so it needs the whole draft to be valid.
    PublishStep.details => draft.isComplete,
  };

  bool get isLastStep => step == PublishStep.details;

  bool get canSubmit => draft.isComplete && !submitStatus.isBusy;

  String? errorFor(String field) {
    final current = failure;
    return current is ValidationFailure ? current.messageFor(field) : null;
  }

  PublishRideState copyWith({
    RideDraft? draft,
    PublishStep? step,
    int? Function()? rideId,
    DataStatus? loadStatus,
    ActionStatus? submitStatus,
    Ride? Function()? publishedRide,
    Failure? Function()? failure,
  }) {
    return PublishRideState(
      draft: draft ?? this.draft,
      step: step ?? this.step,
      rideId: rideId != null ? rideId() : this.rideId,
      loadStatus: loadStatus ?? this.loadStatus,
      submitStatus: submitStatus ?? this.submitStatus,
      publishedRide: publishedRide != null
          ? publishedRide()
          : this.publishedRide,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    draft,
    step,
    rideId,
    loadStatus,
    submitStatus,
    publishedRide,
    failure,
  ];
}
