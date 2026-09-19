import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/az_cities.dart' show AzCity;

/// A car the driver offers seats in — `/vehicles` (API.md §8).
class Vehicle extends Equatable {
  const Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    this.color,
    this.plate,
    this.year,
    this.seats = AppRules.defaultVehicleSeats,
  });

  /// `0` for a car that has not been created yet — see [Vehicle.blank].
  final int id;

  final String brand;
  final String model;

  /// Free text on the wire (≤20 chars), e.g. `"Ağ"`. [VehicleColors] maps it
  /// back to a swatch for display; anything unrecognised still renders.
  final String? color;

  /// `10-AB-123`. API.md §9 returns it **only to the driver themselves**, so
  /// this is null on somebody else's ride.
  final String? plate;

  final int? year;

  /// Total seats **including the driver** (API.md §8), which is why the publish
  /// form offers at most `seats - 1` to passengers.
  final int seats;

  /// A not-yet-saved car, used as the vehicle form's starting point.
  static const Vehicle blank = Vehicle(id: 0, brand: '', model: '');

  bool get isPersisted => id > 0;

  bool get isComplete => brand.trim().isNotEmpty && model.trim().isNotEmpty;

  /// "Toyota Prius"
  String get displayName => '$brand $model'.trim();

  /// "Toyota Prius, Ağ (2018)" — the one-line summary on a ride card.
  String get summary {
    final parts = <String>[
      displayName,
      if (color != null && color!.trim().isNotEmpty) color!.trim(),
    ];
    final line = parts.join(', ');
    return year == null ? line : '$line ($year)';
  }

  /// Seats a passenger could take, i.e. everything but the driver's.
  int get passengerSeats => (seats - 1).clamp(0, AppRules.maxSeatsPerRide);

  Vehicle copyWith({
    int? id,
    String? brand,
    String? model,
    String? Function()? color,
    String? Function()? plate,
    int? Function()? year,
    int? seats,
  }) {
    return Vehicle(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      color: color != null ? color() : this.color,
      plate: plate != null ? plate() : this.plate,
      year: year != null ? year() : this.year,
      seats: seats ?? this.seats,
    );
  }

  @override
  List<Object?> get props => [id, brand, model, color, plate, year, seats];
}

/// Vehicle colours offered in the picker.
///
/// The API stores `color` as free text and its own examples use the Azerbaijani
/// name (`"Ağ"`), so that is what the app sends. The keys here exist only to
/// drive the swatch grid and the localized labels; [keyForValue] maps a stored
/// value in any of the three languages back to a swatch.
abstract final class VehicleColors {
  static const Map<String, int> swatches = {
    'white': 0xFFF2F4F4,
    'black': 0xFF1A1A1A,
    'silver': 0xFFC0C6C8,
    'grey': 0xFF71797E,
    'blue': 0xFF2563EB,
    'red': 0xFFDC2626,
    'green': 0xFF15803D,
    'beige': 0xFFD8C9A8,
    'brown': 0xFF6B4423,
    'yellow': 0xFFEAB308,
    'orange': 0xFFEA580C,
    'other': 0xFF8B5CF6,
  };

  static const List<String> keys = [
    'white',
    'black',
    'silver',
    'grey',
    'blue',
    'red',
    'green',
    'beige',
    'brown',
    'yellow',
    'orange',
    'other',
  ];

  /// Localized colour names — small enough to keep beside the swatches rather
  /// than bloating the main string tables.
  static const Map<String, Map<String, String>> names = {
    'az': {
      'white': 'Ağ',
      'black': 'Qara',
      'silver': 'Gümüşü',
      'grey': 'Boz',
      'blue': 'Mavi',
      'red': 'Qırmızı',
      'green': 'Yaşıl',
      'beige': 'Bej',
      'brown': 'Qəhvəyi',
      'yellow': 'Sarı',
      'orange': 'Narıncı',
      'other': 'Digər',
    },
    'ru': {
      'white': 'Белый',
      'black': 'Чёрный',
      'silver': 'Серебристый',
      'grey': 'Серый',
      'blue': 'Синий',
      'red': 'Красный',
      'green': 'Зелёный',
      'beige': 'Бежевый',
      'brown': 'Коричневый',
      'yellow': 'Жёлтый',
      'orange': 'Оранжевый',
      'other': 'Другой',
    },
    'en': {
      'white': 'White',
      'black': 'Black',
      'silver': 'Silver',
      'grey': 'Grey',
      'blue': 'Blue',
      'red': 'Red',
      'green': 'Green',
      'beige': 'Beige',
      'brown': 'Brown',
      'yellow': 'Yellow',
      'orange': 'Orange',
      'other': 'Other',
    },
  };

  static String nameFor(String key, String languageCode) =>
      names[languageCode]?[key] ?? names['az']![key] ?? key;

  /// What to send as `color`: the Azerbaijani name, matching the API's own
  /// examples so the value reads sensibly in the admin panel too.
  static String? apiValueFor(String? key) =>
      key == null ? null : names['az']![key] ?? key;

  static final Map<String, String> _keyByFoldedName = {
    for (final table in names.values)
      for (final entry in table.entries)
        AzCity.foldQuery(entry.value): entry.key,
  };

  /// The swatch key for a stored colour, in any of the three languages.
  /// `null` for free text the picker does not know.
  static String? keyForValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _keyByFoldedName[AzCity.foldQuery(value)];
  }

  /// The swatch to paint for a stored colour, falling back to the neutral
  /// "other" swatch so an unknown value still renders as a chip.
  static int swatchForValue(String? value) =>
      swatches[keyForValue(value)] ?? swatches['other']!;

  /// A stored colour shown in the reader's language when it is one the picker
  /// knows, and verbatim otherwise.
  static String labelForValue(String? value, String languageCode) {
    if (value == null || value.trim().isEmpty) return '';
    final key = keyForValue(value);
    return key == null ? value.trim() : nameFor(key, languageCode);
  }
}
