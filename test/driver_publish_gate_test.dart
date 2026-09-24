import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/features/profile/data/models/driver_profile_model.dart';
import 'package:yolyoldasi/features/profile/domain/entities/user_enums.dart';

/// API.md §9: `POST /rides` and `/rides/{id}/repeat` need a car *and* all
/// four documents approved by an admin. The client mirrors that so a driver is
/// not walked through a three-step form only to be refused at the end.
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
    test('needs approved documents', () {
      final driver = DriverProfileModel.fromJson(profile(status: 'approved'));
      expect(driver.canPublishRides, isTrue);
    });

    test('a car alone is not enough', () {
      for (final status in ['not_uploaded', 'pending', 'rejected']) {
        final driver = DriverProfileModel.fromJson(profile(status: status));
        expect(
          driver.canPublishRides,
          isFalse,
          reason: 'documents $status must keep publishing locked',
        );
      }
    });

    test('no car means no publishing, even when approved', () {
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

    test('always comes with a locked publish button', () {
      final driver = DriverProfileModel.fromJson(profile(status: 'pending'));
      expect(driver.needsVerification, isTrue);
      expect(driver.canPublishRides, isFalse);
    });
  });
}
