import '../../../../core/error/result.dart';
import '../../../../core/network/upload_file.dart';
import '../entities/driver_profile.dart';
import '../entities/user_enums.dart';
import '../entities/vehicle.dart';

/// Driver verification and the cars behind it — API.md §7 and §8.
abstract interface class DriverRepository {
  /// `GET /driver/profile`.
  FutureResult<DriverProfile> profile();

  /// `PUT /driver/profile` — the default `instant_booking` for new rides.
  FutureResult<DriverProfile> setInstantBookingDefault(bool value);

  /// `POST /driver/documents`, then a re-read of the profile so the caller gets
  /// the recomputed aggregate status back in one step.
  FutureResult<DriverProfile> uploadDocument({
    required DocumentType type,
    required UploadFile file,
    UploadFile? backFile,
  });

  FutureResult<List<Vehicle>> vehicles();

  /// `POST /vehicles`. The first car also gives the account a driver profile.
  FutureResult<Vehicle> addVehicle(Vehicle vehicle);

  FutureResult<Vehicle> updateVehicle(Vehicle vehicle);

  /// `DELETE /vehicles/{id}` — 422 while an active ride still uses the car.
  FutureResult<void> deleteVehicle(int vehicleId);
}
