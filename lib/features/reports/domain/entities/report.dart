import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';

/// Wire: the seven values in API.md §2.
enum ReportReason {
  noShow('no_show'),
  unsafeDriving('unsafe_driving'),
  rudeBehaviour('rude_behaviour'),
  wrongVehicle('wrong_vehicle'),
  priceDispute('price_dispute'),
  spam('spam'),
  other('other');

  const ReportReason(this.apiValue);

  final String apiValue;

  /// `details` becomes required once the reason is "other" (API.md §15).
  bool get requiresDetails => this == ReportReason.other;

  static ReportReason fromApi(String? value) => ReportReason.values.firstWhere(
    (r) => r.apiValue == value,
    orElse: () => ReportReason.other,
  );

  /// Short localized labels, kept here because only the report sheet uses them.
  static const Map<String, Map<String, String>> labels = {
    'az': {
      'no_show': 'Gəlmədi',
      'unsafe_driving': 'Təhlükəli sürücülük',
      'rude_behaviour': 'Kobud davranış',
      'wrong_vehicle': 'Avtomobil uyğun deyil',
      'price_dispute': 'Qiymət mübahisəsi',
      'spam': 'Spam / saxta elan',
      'other': 'Digər',
    },
    'ru': {
      'no_show': 'Не явился',
      'unsafe_driving': 'Опасное вождение',
      'rude_behaviour': 'Грубое поведение',
      'wrong_vehicle': 'Автомобиль не соответствует',
      'price_dispute': 'Спор о цене',
      'spam': 'Спам / фальшивое объявление',
      'other': 'Другое',
    },
    'en': {
      'no_show': 'No-show',
      'unsafe_driving': 'Unsafe driving',
      'rude_behaviour': 'Rude behaviour',
      'wrong_vehicle': 'Vehicle did not match',
      'price_dispute': 'Price dispute',
      'spam': 'Spam / fake listing',
      'other': 'Other',
    },
  };

  String label(String languageCode) =>
      labels[languageCode]?[apiValue] ?? labels['az']![apiValue] ?? name;
}

/// What the report sheet collects for `POST /reports` (API.md §15).
///
/// The API exposes no way to read reports back — filing one is the whole
/// client-side story.
class ReportDraft extends Equatable {
  const ReportDraft({
    required this.targetUserId,
    this.reason,
    this.details = '',
    this.rideId,
    this.bookingId,
  });

  /// May not be the reporter themselves; the API answers 422 if it is.
  final int targetUserId;

  final ReportReason? reason;
  final String details;

  /// Optional context, so the moderator can see what the report is about.
  final int? rideId;
  final int? bookingId;

  bool get isValid {
    final picked = reason;
    if (picked == null) return false;
    if (details.length > AppRules.maxReportDetailsLength) return false;
    if (picked.requiresDetails && details.trim().isEmpty) return false;
    return true;
  }

  ReportDraft copyWith({ReportReason? reason, String? details}) => ReportDraft(
    targetUserId: targetUserId,
    reason: reason ?? this.reason,
    details: details ?? this.details,
    rideId: rideId,
    bookingId: bookingId,
  );

  @override
  List<Object?> get props => [targetUserId, reason, details, rideId, bookingId];
}
