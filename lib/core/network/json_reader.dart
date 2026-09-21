import '../types.dart';

/// Defensive readers for JSON coming back from the API.
///
/// A field that is missing, null or of the wrong type falls back to the
/// supplied default instead of throwing. That matters more than it looks:
/// API.md §16.5 lists a dozen keys that are simply *absent* rather than null
/// (`vehicle.plate`, `booking.contact_phone`, …), and a list must never crash
/// because one row omitted one of them.
extension JsonReader on Json {
  String str(String key, [String fallback = '']) {
    final value = this[key];
    return value is String ? value : fallback;
  }

  String? strOrNull(String key) {
    final value = this[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  int integer(String key, [int fallback = 0]) {
    final value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  int? integerOrNull(String key) {
    final value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Money and ratings arrive as JSON numbers, but Laravel serialises `decimal`
  /// columns as strings often enough to be worth tolerating.
  double decimal(String key, [double fallback = 0]) {
    final value = this[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  double? decimalOrNull(String key) {
    final value = this[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool flag(String key, [bool fallback = false]) {
    final value = this[key];
    if (value is bool) return value;
    // Laravel casts booleans to 0/1 on some serialisers.
    if (value is num) return value != 0;
    if (value is String) return value == '1' || value == 'true';
    return fallback;
  }

  /// A flag that keeps "the key was not there" apart from "it was false".
  ///
  /// Needed where absence carries its own meaning — `is_verified` is omitted
  /// when the server did not load the relation (API.md §21), and reading that
  /// as `false` would strip the badge off an approved driver.
  bool? flagOrNull(String key) {
    final value = this[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value == '1' || value == 'true';
    return null;
  }

  /// ISO 8601 (API.md §1). Falls back to the epoch so a malformed timestamp
  /// sorts last rather than taking the screen down.
  DateTime date(String key, [DateTime? fallback]) =>
      dateOrNull(key) ?? fallback ?? DateTime.fromMillisecondsSinceEpoch(0);

  DateTime? dateOrNull(String key) {
    final value = this[key];
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  Json child(String key) {
    final value = this[key];
    return value is Map ? Json.from(value) : <String, dynamic>{};
  }

  Json? childOrNull(String key) {
    final value = this[key];
    return value is Map ? Json.from(value) : null;
  }

  List<String> strings(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  List<Json> children(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value.whereType<Map>().map(Json.from).toList(growable: false);
  }
}
