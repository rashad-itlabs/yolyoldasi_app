import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../domain/entities/vehicle.dart';
import '../../../domain/repositories/driver_repository.dart';

part 'vehicles_event.dart';
part 'vehicles_state.dart';

/// The driver's cars — API.md §8.
///
/// Holds both the list and the add/edit form: they share a screen, and the
/// list has to update the moment a save returns.
class VehiclesBloc extends Bloc<VehiclesEvent, VehiclesState> {
  VehiclesBloc({required DriverRepository drivers})
    : _drivers = drivers,
      super(const VehiclesState()) {
    on<VehiclesRequested>(_onRequested);
    on<VehicleEditStarted>(_onEditStarted);
    on<VehicleFieldChanged>(_onFieldChanged);
    on<VehicleSubmitted>(_onSubmitted);
    on<VehicleDeleted>(_onDeleted);
    on<VehiclesFailureCleared>(_onFailureCleared);
  }

  final DriverRepository _drivers;

  Future<void> _onRequested(
    VehiclesRequested event,
    Emitter<VehiclesState> emit,
  ) async {
    if (state.status.isBusy) return;
    if (state.status.isSuccess && !event.force) return;

    final hasData = state.vehicles.isNotEmpty;
    emit(
      state.copyWith(
        status: hasData ? DataStatus.refreshing : DataStatus.loading,
        failure: () => null,
      ),
    );

    final result = await _drivers.vehicles();
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: DataStatus.success, vehicles: value));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: hasData ? DataStatus.success : DataStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }

  void _onEditStarted(VehicleEditStarted event, Emitter<VehiclesState> emit) {
    final vehicle = event.vehicle ?? Vehicle.blank;
    emit(
      state.copyWith(
        draft: () => vehicle,
        colorKey: () => VehicleColors.keyForValue(vehicle.color),
        saveStatus: ActionStatus.idle,
        savedVehicle: () => null,
        failure: () => null,
      ),
    );
  }

  void _onFieldChanged(VehicleFieldChanged event, Emitter<VehiclesState> emit) {
    final draft = state.draft;
    if (draft == null) return;

    emit(
      state.copyWith(
        draft: () => draft.copyWith(
          brand: event.brand,
          model: event.model,
          // The picker deals in keys; the wire value is the Azerbaijani name,
          // which is what the API's own examples use.
          color: event.colorKey == null
              ? null
              : () => VehicleColors.apiValueFor(event.colorKey),
          plate: event.plate == null ? null : () => event.plate,
          year: event.year == null ? null : () => event.year,
          seats: event.seats,
        ),
        colorKey: event.colorKey == null ? null : () => event.colorKey,
        failure: () => null,
      ),
    );
  }

  Future<void> _onSubmitted(
    VehicleSubmitted event,
    Emitter<VehiclesState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null || !draft.isComplete || state.saveStatus.isBusy) return;

    emit(
      state.copyWith(
        saveStatus: ActionStatus.inProgress,
        savedVehicle: () => null,
        failure: () => null,
      ),
    );

    final result = draft.isPersisted
        ? await _drivers.updateVehicle(draft)
        : await _drivers.addVehicle(draft);

    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            saveStatus: ActionStatus.success,
            savedVehicle: () => value,
            draft: () => null,
            vehicles: _merge(state.vehicles, value),
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            saveStatus: ActionStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }

  /// Replaces the edited car in place, or appends a new one, so the list does
  /// not need a second round trip after a save.
  static List<Vehicle> _merge(List<Vehicle> current, Vehicle saved) {
    final index = current.indexWhere((v) => v.id == saved.id);
    if (index == -1) return [...current, saved];
    final next = [...current];
    next[index] = saved;
    return next;
  }

  Future<void> _onDeleted(
    VehicleDeleted event,
    Emitter<VehiclesState> emit,
  ) async {
    if (state.deleteStatus.isInProgress) return;

    emit(
      state.copyWith(
        deleteStatus: ActionStatus.inProgress,
        failure: () => null,
      ),
    );

    final result = await _drivers.deleteVehicle(event.vehicleId);
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            deleteStatus: ActionStatus.success,
            vehicles: state.vehicles
                .where((v) => v.id != event.vehicleId)
                .toList(growable: false),
          ),
        );
      case Err(:final failure):
        // The usual reason is a 422: an active ride still uses this car, and
        // the driver has to cancel that first.
        emit(
          state.copyWith(
            deleteStatus: ActionStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }

  void _onFailureCleared(
    VehiclesFailureCleared event,
    Emitter<VehiclesState> emit,
  ) {
    emit(
      state.copyWith(
        failure: () => null,
        saveStatus: ActionStatus.idle,
        deleteStatus: ActionStatus.idle,
      ),
    );
  }
}
