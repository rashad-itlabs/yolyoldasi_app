import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../cities/domain/entities/city.dart';
import 'user_enums.dart';

/// Reputation counters, as returned in the `stats` block of `/me` and of every
/// embedded profile (API.md §4).
class UserStats extends Equatable {
  const UserStats({
    this.driverRating = 0,
    this.driverReviewCount = 0,
    this.driverTripCount = 0,
    this.passengerRating = 0,
    this.passengerReviewCount = 0,
    this.passengerTripCount = 0,
  });

  final double driverRating;
  final int driverReviewCount;
  final int driverTripCount;

  final double passengerRating;
  final int passengerReviewCount;
  final int passengerTripCount;

  static const UserStats empty = UserStats();

  double ratingFor(UserMode mode) =>
      mode.isDriver ? driverRating : passengerRating;

  int reviewCountFor(UserMode mode) =>
      mode.isDriver ? driverReviewCount : passengerReviewCount;

  int tripCountFor(UserMode mode) =>
      mode.isDriver ? driverTripCount : passengerTripCount;

  int get totalTrips => driverTripCount + passengerTripCount;

  /// Overall rating across both roles, weighted by review count.
  double get overallRating {
    final total = driverReviewCount + passengerReviewCount;
    if (total == 0) return 0;
    return (driverRating * driverReviewCount +
            passengerRating * passengerReviewCount) /
        total;
  }

  bool get hasAnyReview => driverReviewCount + passengerReviewCount > 0;

  @override
  List<Object?> get props => [
    driverRating,
    driverReviewCount,
    driverTripCount,
    passengerRating,
    passengerReviewCount,
    passengerTripCount,
  ];
}

/// `GET|PUT /me/notification-preferences` (API.md §4).
class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.pushEnabled = true,
    this.bookings = true,
    this.messages = true,
    this.reminders = true,
    this.marketing = false,
  });

  final bool pushEnabled;
  final bool bookings;
  final bool messages;
  final bool reminders;
  final bool marketing;

  static const NotificationPreferences defaults = NotificationPreferences();

  /// API.md §4: `push_enabled` sits above the other four. The settings screen
  /// binds its master switch to this, and greys the rest out when it is off.
  bool get isMuted => !pushEnabled;

  bool effective(bool channel) => pushEnabled && channel;

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? bookings,
    bool? messages,
    bool? reminders,
    bool? marketing,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      bookings: bookings ?? this.bookings,
      messages: messages ?? this.messages,
      reminders: reminders ?? this.reminders,
      marketing: marketing ?? this.marketing,
    );
  }

  @override
  List<Object?> get props => [
    pushEnabled,
    bookings,
    messages,
    reminders,
    marketing,
  ];
}

/// The signed-in account, as `GET /me` returns it (API.md §4).
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.phone,
    this.phoneVerifiedAt,
    this.fullName = '',
    this.photoUrl,
    this.about = '',
    this.gender = Gender.unspecified,
    this.birthYear,
    this.city,
    this.activeMode = UserMode.passenger,
    this.hasDriverProfile = false,
    this.languageCode = 'az',
    this.isAdmin = false,
    this.stats = UserStats.empty,
    this.notificationPreferences = NotificationPreferences.defaults,
  });

  final int id;

  /// E.164, e.g. `+994501234567`.
  final String phone;
  final DateTime? phoneVerifiedAt;

  final String fullName;
  final String? photoUrl;
  final String about;
  final Gender gender;
  final int? birthYear;

  /// Nullable — API.md §16.5 lists `city` among the keys that may be absent.
  final City? city;

  /// Which tab set the user last used. Persisted server-side via
  /// `PUT /me/mode`, so it follows the account across devices.
  final UserMode activeMode;

  /// `true` once the user has a vehicle; the API sets it when the first car is
  /// created (API.md §8). Gates `PUT /me/mode` to `driver`.
  final bool hasDriverProfile;

  final String languageCode;
  final bool isAdmin;

  final UserStats stats;
  final NotificationPreferences notificationPreferences;

  /// The profile is usable once we know what to call the person. `full_name` is
  /// optional on `POST /auth/firebase`, so a brand-new account lands here.
  bool get isProfileComplete =>
      fullName.trim().length >= AppRules.minFullNameLength;

  int? get age => birthYear == null ? null : DateTime.now().year - birthYear!;

  double ratingFor(UserMode mode) => stats.ratingFor(mode);

  AppUser copyWith({
    String? phone,
    DateTime? Function()? phoneVerifiedAt,
    String? fullName,
    String? Function()? photoUrl,
    String? about,
    Gender? gender,
    int? Function()? birthYear,
    City? Function()? city,
    UserMode? activeMode,
    bool? hasDriverProfile,
    String? languageCode,
    bool? isAdmin,
    UserStats? stats,
    NotificationPreferences? notificationPreferences,
  }) {
    return AppUser(
      id: id,
      phone: phone ?? this.phone,
      phoneVerifiedAt: phoneVerifiedAt != null
          ? phoneVerifiedAt()
          : this.phoneVerifiedAt,
      fullName: fullName ?? this.fullName,
      photoUrl: photoUrl != null ? photoUrl() : this.photoUrl,
      about: about ?? this.about,
      gender: gender ?? this.gender,
      birthYear: birthYear != null ? birthYear() : this.birthYear,
      city: city != null ? city() : this.city,
      activeMode: activeMode ?? this.activeMode,
      hasDriverProfile: hasDriverProfile ?? this.hasDriverProfile,
      languageCode: languageCode ?? this.languageCode,
      isAdmin: isAdmin ?? this.isAdmin,
      stats: stats ?? this.stats,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
    );
  }

  @override
  List<Object?> get props => [
    id,
    phone,
    phoneVerifiedAt,
    fullName,
    photoUrl,
    about,
    gender,
    birthYear,
    city,
    activeMode,
    hasDriverProfile,
    languageCode,
    isAdmin,
    stats,
    notificationPreferences,
  ];
}

/// The "qısa profil" the API embeds in rides, bookings, conversations, reviews
/// and notifications, and returns from `GET /users/{id}`.
///
/// Deliberately has no phone number: contact details arrive separately, on a
/// confirmed booking's `contact_phone` (API.md §10).
class PublicUser extends Equatable {
  const PublicUser({
    required this.id,
    this.fullName = '',
    this.photoUrl,
    this.gender = Gender.unspecified,
    this.birthYear,
    this.city,
    this.hasDriverProfile = false,
    this.stats = UserStats.empty,
  });

  final int id;
  final String fullName;
  final String? photoUrl;
  final Gender gender;
  final int? birthYear;
  final City? city;
  final bool hasDriverProfile;
  final UserStats stats;

  int? get age => birthYear == null ? null : DateTime.now().year - birthYear!;

  double ratingFor(UserMode mode) => stats.ratingFor(mode);
  int reviewCountFor(UserMode mode) => stats.reviewCountFor(mode);
  int tripCountFor(UserMode mode) => stats.tripCountFor(mode);

  /// "Rəşad M." — the API already abbreviates surnames in embedded profiles,
  /// but a locally-built snapshot may not, so the UI has one place to ask.
  String get displayName => fullName.trim().isEmpty ? '—' : fullName.trim();

  @override
  List<Object?> get props => [
    id,
    fullName,
    photoUrl,
    gender,
    birthYear,
    city,
    hasDriverProfile,
    stats,
  ];
}
