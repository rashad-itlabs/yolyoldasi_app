import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/vehicle.dart';
import '../models/vehicle_model.dart';

/// `/vehicles` — API.md §8.
class VehicleApiService {
  const VehicleApiService(this._client);

  final ApiClient _client;

  FutureResult<List<Vehicle>> list() =>
      _client.getList(Api.vehicles, parse: VehicleModel.fromJson);

  /// The first car created also flips `has_driver_profile` to true.
  FutureResult<Vehicle> create(Vehicle vehicle) => _client.post(
    Api.vehicles,
    body: VehicleModel.toJson(vehicle),
    parse: VehicleModel.fromJson,
  );

  FutureResult<Vehicle> update(Vehicle vehicle) => _client.put(
    Api.vehicle(vehicle.id),
    body: VehicleModel.toJson(vehicle),
    parse: VehicleModel.fromJson,
  );

  /// 422 when the car is attached to a ride that is still active.
  FutureResult<void> delete(int vehicleId) =>
      _client.send('DELETE', Api.vehicle(vehicleId));
}
