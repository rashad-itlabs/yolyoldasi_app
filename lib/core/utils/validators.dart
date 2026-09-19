import '../constants/app_constants.dart';
import 'phone_number.dart';

/// Form validators.
///
/// Each returns a *localization key* (or `null` when valid) rather than a
/// message, so the same validator works in all three languages.
abstract final class Validators {
  static String? required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'fieldRequired' : null;

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'fieldRequired';
    return PhoneNumbers.isValid(value) ? null : 'invalidPhone';
  }

  static String? otp(String? value) {
    if (value == null || value.isEmpty) return 'fieldRequired';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length == AppRules.otpLength ? null : 'invalidOtpFormat';
  }

  static String? fullName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'fieldRequired';
    if (trimmed.length > AppRules.maxFullNameLength) return 'invalidName';
    final letters = trimmed.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
    return letters.length >= AppRules.minFullNameLength ? null : 'invalidName';
  }

  /// Azerbaijani plates: `10-AA-123`, `90-XX-999`. Dashes and case are
  /// normalised before checking, so `10aa123` is accepted too.
  ///
  /// `plate` is optional on `POST /vehicles` (API.md §8), so an empty value is
  /// valid; only a malformed one is rejected.
  static String? plate(String? value) {
    final normalized = normalizePlate(value ?? '');
    if (normalized.isEmpty) return null;
    final ok = RegExp(r'^\d{2}-[A-Z]{2}-\d{3}$').hasMatch(normalized);
    return ok ? null : 'invalidPlate';
  }

  static String normalizePlate(String input) {
    final cleaned = input.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    if (cleaned.length < 7) return cleaned;
    return '${cleaned.substring(0, 2)}-${cleaned.substring(2, 4)}-'
        '${cleaned.substring(4, 7)}';
  }

  static String? price(String? value) {
    if (value == null || value.trim().isEmpty) return 'fieldRequired';
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null) return 'invalidPrice';
    if (parsed < AppRules.minPricePerSeat ||
        parsed > AppRules.maxPricePerSeat) {
      return 'invalidPrice';
    }
    return null;
  }

  /// `year` is optional, and the API accepts 1950 – (current year + 1).
  static String? vehicleYear(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final year = int.tryParse(value.trim());
    if (year == null ||
        year < AppRules.minVehicleYear ||
        year > AppRules.maxVehicleYear) {
      return 'invalidYear';
    }
    return null;
  }

  /// `birth_year` is nullable, and the API accepts 1930 – (current year − 16).
  static String? birthYear(int? value) {
    if (value == null) return null;
    if (value < AppRules.minBirthYear || value > AppRules.maxBirthYear) {
      return 'invalidYear';
    }
    return null;
  }

  static String? maxLength(String? value, int max, String errorKey) {
    if (value == null) return null;
    return value.characters > max ? errorKey : null;
  }

  /// Route validity: both cities picked and different from each other.
  static String? route(int? fromCityId, int? toCityId) {
    if (fromCityId == null || toCityId == null) return 'fieldRequired';
    return fromCityId == toCityId ? 'sameCityError' : null;
  }

  /// `departure_at` only has to be in the future; the API sets no upper bound.
  static String? departure(DateTime? value) {
    if (value == null) return 'fieldRequired';
    return value.isBefore(DateTime.now()) ? 'pastDateError' : null;
  }
}

extension on String {
  /// Grapheme-agnostic length is overkill here; code units are close enough
  /// for the short free-text fields the app collects.
  int get characters => runes.length;
}
