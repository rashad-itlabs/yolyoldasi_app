// The enum values in API.md §2.
//
// The server matches on these strings exactly, and several of them are
// `snake_case` while Dart's `.name` is `camelCase`, so every enum here owns its
// own wire spelling rather than relying on `.name`.

/// Which side of the marketplace the user is currently acting as.
///
/// A single account can be both; this only drives navigation and defaults.
/// Wire: `passenger | driver`.
enum UserMode {
  passenger,
  driver;

  bool get isDriver => this == UserMode.driver;

  UserMode get opposite =>
      this == UserMode.driver ? UserMode.passenger : UserMode.driver;

  String get apiValue => name;

  static UserMode fromApi(String? value) => UserMode.values.firstWhere(
    (m) => m.apiValue == value,
    orElse: () => UserMode.passenger,
  );
}

/// Wire: `male | female | unspecified`.
enum Gender {
  male,
  female,
  unspecified;

  String get apiValue => name;

  static Gender fromApi(String? value) => Gender.values.firstWhere(
    (g) => g.apiValue == value,
    orElse: () => Gender.unspecified,
  );
}

/// The four documents an Azerbaijani driver must provide (API.md §7).
///
/// Wire: `id_card | driver_license | vehicle_registration | insurance`.
enum DocumentType {
  /// Şəxsiyyət vəsiqəsi
  idCard('id_card'),

  /// Sürücülük vəsiqəsi
  driverLicense('driver_license'),

  /// FŞH — qeydiyyat şəhadətnaməsi
  vehicleRegistration('vehicle_registration'),

  /// İcbari sığorta
  insurance('insurance');

  const DocumentType(this.apiValue);

  final String apiValue;

  /// Only the ID card and the driving licence have a back side; sending
  /// `back_file` for the other two is a 422 (API.md §7).
  bool get requiresBackSide =>
      this == DocumentType.idCard || this == DocumentType.driverLicense;

  static DocumentType fromApi(String? value) => DocumentType.values.firstWhere(
    (d) => d.apiValue == value,
    orElse: () => DocumentType.idCard,
  );
}

/// Status of a single document, and — aggregated — of the whole driver profile.
///
/// Wire: `not_uploaded | pending | approved | rejected`.
enum VerificationStatus {
  notUploaded('not_uploaded'),
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const VerificationStatus(this.apiValue);

  final String apiValue;

  bool get isApproved => this == VerificationStatus.approved;
  bool get isPending => this == VerificationStatus.pending;
  bool get isRejected => this == VerificationStatus.rejected;
  bool get isNotUploaded => this == VerificationStatus.notUploaded;

  static VerificationStatus fromApi(String? value) =>
      VerificationStatus.values.firstWhere(
        (s) => s.apiValue == value,
        orElse: () => VerificationStatus.notUploaded,
      );
}

/// Wire: `android | ios` on `POST /me/device-tokens`.
enum DevicePlatform {
  android,
  ios;

  String get apiValue => name;
}

/// The languages the API accepts for `language_code`.
abstract final class AppLanguages {
  static const List<String> codes = ['az', 'en', 'ru'];

  static bool isSupported(String? code) => codes.contains(code);

  static String normalize(String? code) =>
      isSupported(code) ? code! : codes.first;
}
