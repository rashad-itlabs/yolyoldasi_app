import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/features/profile/data/models/driver_profile_model.dart';
import 'package:yolyoldasi/features/profile/domain/entities/user_enums.dart';

/// API.md §9: `POST /rides` answers 422 only when there is no driver profile,
/// or when the vehicle belongs to somebody else. Document approval is *not*
/// among its requirements.
///
/// The client once also demanded `status == approved`, which made publishing
/// impossible for every driver — nothing in the product approves documents.
void main() {
  Map<String, dynamic> profile({
    required String status,
    bool withVehicle = true,
  }) => {
    'status': status,
    if (withVehicle) 'vehicle': {'id': 3, 'brand': 'Toyota', 'model': 'Prius'},
    'documents': const [],
  };

  group('canPublishRides', () {
    test('a car is enough, whatever the documents say', () {
      for (final status in [
        'not_uploaded',
        'pending',
        'rejected',
        'approved',
      ]) {
        final driver = DriverProfileModel.fromJson(profile(status: status));
        expect(
          driver.canPublishRides,
          isTrue,
          reason: 'a driver with a car must be able to publish ($status)',
        );
      }
    });

    test('no car means no publishing', () {
      // The first car is what creates the driver profile (API.md §8), so this
      // is the one case the API really does refuse.
      final driver = DriverProfileModel.fromJson(
        profile(status: 'approved', withVehicle: false),
      );
      expect(driver.canPublishRides, isFalse);
    });
  });

  group('needsVerification', () {
    test('is true until every document is approved', () {
      for (final status in ['not_uploaded', 'pending', 'rejected']) {
        expect(
          DriverProfileModel.fromJson(
            profile(status: status),
          ).needsVerification,
          isTrue,
        );
      }
    });

    test('is false once approved', () {
      final driver = DriverProfileModel.fromJson(profile(status: 'approved'));
      expect(driver.needsVerification, isFalse);
      expect(driver.status, VerificationStatus.approved);
    });

    test('never blocks publishing', () {
      // The banner and the button answer different questions; a driver can be
      // both unverified and able to publish.
      final driver = DriverProfileModel.fromJson(profile(status: 'pending'));
      expect(driver.needsVerification, isTrue);
      expect(driver.canPublishRides, isTrue);
    });
  });
}
