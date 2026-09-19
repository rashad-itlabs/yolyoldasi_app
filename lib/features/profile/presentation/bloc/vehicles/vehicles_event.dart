part of 'vehicles_bloc.dart';

sealed class VehiclesEvent extends Equatable {
  const VehiclesEvent();

  @override
  List<Object?> get props => const [];
}

class VehiclesRequested extends VehiclesEvent {
  const VehiclesRequested({this.force = false});

  final bool force;

  @override
  List<Object?> get props => [force];
}

/// Opens the form on a blank car, or on an existing one to edit.
class VehicleEditStarted extends VehiclesEvent {
  const VehicleEditStarted([this.vehicle]);

  final Vehicle? vehicle;

  @override
  List<Object?> get props => [vehicle];
}

class VehicleFieldChanged extends VehiclesEvent {
  const VehicleFieldChanged({
    this.brand,
    this.model,
    this.colorKey,
    this.plate,
    this.year,
    this.seats,
  });

  final String? brand;
  final String? model;

  /// A key from [VehicleColors]; the Azerbaijani name is what reaches the API.
  final String? colorKey;

  final String? plate;
  final int? year;
  final int? seats;

  @override
  List<Object?> get props => [brand, model, colorKey, plate, year, seats];
}

/// `POST /vehicles` or `PUT /vehicles/{id}`, depending on the draft.
class VehicleSubmitted extends VehiclesEvent {
  const VehicleSubmitted();
}

/// `DELETE /vehicles/{id}` — 422 while an active ride still uses the car.
class VehicleDeleted extends VehiclesEvent {
  const VehicleDeleted(this.vehicleId);

  final int vehicleId;

  @override
  List<Object?> get props => [vehicleId];
}

class VehiclesFailureCleared extends VehiclesEvent {
  const VehiclesFailureCleared();
}
