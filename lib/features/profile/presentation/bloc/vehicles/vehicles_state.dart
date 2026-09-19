part of 'vehicles_bloc.dart';

class VehiclesState extends Equatable {
  const VehiclesState({
    this.status = DataStatus.initial,
    this.vehicles = const [],
    this.draft,
    this.colorKey,
    this.saveStatus = ActionStatus.idle,
    this.deleteStatus = ActionStatus.idle,
    this.savedVehicle,
    this.failure,
  });

  final DataStatus status;
  final List<Vehicle> vehicles;

  /// The car currently being added or edited. `null` when the form is closed.
  final Vehicle? draft;

  /// The picker's selection, kept alongside [draft] because the wire value is
  /// free text and a colour the picker does not know has no key.
  final String? colorKey;

  final ActionStatus saveStatus;
  final ActionStatus deleteStatus;

  /// The car the API just returned, for the page to pop on.
  final Vehicle? savedVehicle;

  final Failure? failure;

  bool get isEmpty => status.isSuccess && vehicles.isEmpty;
  bool get isEditing => draft?.isPersisted ?? false;
  bool get canSubmit => (draft?.isComplete ?? false) && !saveStatus.isBusy;

  /// The first car, which is the one rides default to.
  Vehicle? get primary => vehicles.isEmpty ? null : vehicles.first;

  String? errorFor(String field) {
    final current = failure;
    return current is ValidationFailure ? current.messageFor(field) : null;
  }

  VehiclesState copyWith({
    DataStatus? status,
    List<Vehicle>? vehicles,
    Vehicle? Function()? draft,
    String? Function()? colorKey,
    ActionStatus? saveStatus,
    ActionStatus? deleteStatus,
    Vehicle? Function()? savedVehicle,
    Failure? Function()? failure,
  }) {
    return VehiclesState(
      status: status ?? this.status,
      vehicles: vehicles ?? this.vehicles,
      draft: draft != null ? draft() : this.draft,
      colorKey: colorKey != null ? colorKey() : this.colorKey,
      saveStatus: saveStatus ?? this.saveStatus,
      deleteStatus: deleteStatus ?? this.deleteStatus,
      savedVehicle: savedVehicle != null ? savedVehicle() : this.savedVehicle,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    vehicles,
    draft,
    colorKey,
    saveStatus,
    deleteStatus,
    savedVehicle,
    failure,
  ];
}
