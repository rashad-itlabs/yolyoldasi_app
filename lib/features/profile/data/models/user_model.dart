import '../../../../core/network/json_reader.dart';
import '../../../../core/types.dart';
import '../../../cities/data/models/city_model.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_enums.dart';

/// `GET /me` (API.md §4).
abstract final class UserModel {
  static AppUser fromJson(Json json) {
    return AppUser(
      id: json.integer('id'),
      phone: json.str('phone'),
      phoneVerifiedAt: json.dateOrNull('phone_verified_at'),
      fullName: json.str('full_name'),
      photoUrl: json.strOrNull('photo_url'),
      about: json.str('about'),
      gender: Gender.fromApi(json.strOrNull('gender')),
      birthYear: json.integerOrNull('birth_year'),
      city: CityModel.fromJsonOrNull(json.childOrNull('city')),
      activeMode: UserMode.fromApi(json.strOrNull('active_mode')),
      hasDriverProfile: json.flag('has_driver_profile'),
      languageCode: AppLanguages.normalize(json.strOrNull('language_code')),
      isAdmin: json.flag('is_admin'),
      stats: UserStatsModel.fromJson(json.child('stats')),
      notificationPreferences: NotificationPreferencesModel.fromJson(
        json.child('notification_preferences'),
      ),
    );
  }

  /// Body for `PATCH /me`. Only the keys the user actually edited are sent —
  /// API.md §4 says anything omitted is left alone.
  ///
  /// The nullable fields take a `Function()` wrapper so "set this to null"
  /// (clear my city) is distinguishable from "don't touch this".
  static Json patchBody({
    String? fullName,
    String? Function()? about,
    Gender? gender,
    int? Function()? birthYear,
    int? Function()? cityId,
    String? languageCode,
  }) {
    return {
      'full_name': ?fullName,
      // The wrapped fields keep an explicit `if`: calling the closure may yield
      // null, and that null is the payload — it is how a field gets cleared.
      if (about != null) 'about': about(),
      'gender': ?gender?.apiValue,
      if (birthYear != null) 'birth_year': birthYear(),
      if (cityId != null) 'city_id': cityId(),
      'language_code': ?languageCode,
    };
  }
}

/// The "qısa profil" embedded in rides, bookings, conversations and reviews,
/// and returned by `GET /users/{id}`.
abstract final class PublicUserModel {
  static PublicUser fromJson(Json json) {
    return PublicUser(
      id: json.integer('id'),
      fullName: json.str('full_name'),
      photoUrl: json.strOrNull('photo_url'),
      gender: Gender.fromApi(json.strOrNull('gender')),
      birthYear: json.integerOrNull('birth_year'),
      city: CityModel.fromJsonOrNull(json.childOrNull('city')),
      hasDriverProfile: json.flag('has_driver_profile'),
      stats: UserStatsModel.fromJson(json.child('stats')),
    );
  }

  /// For the embedded profiles, which are absent rather than null when the
  /// related user has been deleted (API.md §1: a 404 covers deleted users, but
  /// a list row can still carry a hole).
  static PublicUser? fromJsonOrNull(Json? json) {
    if (json == null || json.isEmpty) return null;
    final id = json.integerOrNull('id');
    return id == null ? null : fromJson(json);
  }
}

abstract final class UserStatsModel {
  static UserStats fromJson(Json json) {
    if (json.isEmpty) return UserStats.empty;
    return UserStats(
      driverRating: json.decimal('driver_rating'),
      driverReviewCount: json.integer('driver_review_count'),
      driverTripCount: json.integer('driver_trip_count'),
      passengerRating: json.decimal('passenger_rating'),
      passengerReviewCount: json.integer('passenger_review_count'),
      passengerTripCount: json.integer('passenger_trip_count'),
    );
  }
}

/// `GET|PUT /me/notification-preferences` (API.md §4).
abstract final class NotificationPreferencesModel {
  static NotificationPreferences fromJson(Json json) {
    if (json.isEmpty) return NotificationPreferences.defaults;
    return NotificationPreferences(
      pushEnabled: json.flag('push_enabled', true),
      bookings: json.flag('bookings', true),
      messages: json.flag('messages', true),
      reminders: json.flag('reminders', true),
      marketing: json.flag('marketing'),
    );
  }

  /// PUT accepts any subset, so the whole object is sent — the settings screen
  /// always has all five switches in hand.
  static Json toJson(NotificationPreferences prefs) => {
    'push_enabled': prefs.pushEnabled,
    'bookings': prefs.bookings,
    'messages': prefs.messages,
    'reminders': prefs.reminders,
    'marketing': prefs.marketing,
  };
}
