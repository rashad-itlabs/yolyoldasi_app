import '../../../../core/error/result.dart';
import '../../../../core/network/upload_file.dart';
import '../../domain/entities/driver_profile.dart';
import '../../domain/entities/user_enums.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/repositories/driver_repository.dart';
import '../services/driver_api_service.dart';
import '../services/vehicle_api_service.dart';

class DriverRepositoryImpl implements DriverRepository {
  const DriverRepositoryImpl({
    required DriverApiService driver,
    required VehicleApiService vehicles,
  }) : _driver = driver,
       _vehicles = vehicles;

  final DriverApiService _driver;
  final VehicleApiService _vehicles;

  @override
  FutureResult<DriverProfile> profile() => _driver.profile();

  @override
  FutureResult<DriverProfile> setInstantBookingDefault(bool value) =>
      _driver.setInstantBookingDefault(value);

  @override
  FutureResult<DriverProfile> uploadDocument({
    required DocumentType type,
    required UploadFile file,
    UploadFile? backFile,
  }) async {
    final uploaded = await _driver.uploadDocument(
      type: type,
      file: file,
      // Sending a back side for a one-sided document is a 422, so it is dropped
      // here rather than relying on every caller to remember the rule.
      backFile: type.requiresBackSide ? backFile : null,
    );
    if (uploaded case Err(:final failure)) return Err(failure);

    // The upload changed the document's status and, with it, the profile's
    // aggregate status — re-read rather than guessing at the new value.
    return _driver.profile();
  }

  @override
  FutureResult<List<Vehicle>> vehicles() => _vehicles.list();

  @override
  FutureResult<Vehicle> addVehicle(Vehicle vehicle) =>
      _vehicles.create(vehicle);

  @override
  FutureResult<Vehicle> updateVehicle(Vehicle vehicle) =>
      _vehicles.update(vehicle);

  @override
  FutureResult<void> deleteVehicle(int vehicleId) =>
      _vehicles.delete(vehicleId);
}
