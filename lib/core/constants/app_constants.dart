/// Business rules the UI enforces up front so a form can be validated without
/// a round trip.
///
/// The server is always the authority — these mirror the validation table in
/// `API.md` and exist to keep the user from submitting something the API would
/// only reject with a 422.
abstract final class AppRules {
  /// API.md §9: `total_seats` is 1–4.
  static const int maxSeatsPerRide = 4;
  static const int minSeatsPerRide = 1;

  /// API.md §8: a vehicle's `seats` is 1–4 and *includes the driver*.
  static const int maxVehicleSeats = 4;
  static const int minVehicleSeats = 1;
  static const int defaultVehicleSeats = 4;

  /// API.md §9: `price_per_seat` is 1–500.
  static const double minPricePerSeat = 1;
  static const double maxPricePerSeat = 500;

  /// API.md §4: `birth_year` is 1930 – (current year − 16).
  static const int minBirthYear = 1930;
  static const int minimumAge = 16;

  /// API.md §8: `year` is 1950 – (current year + 1).
  static const int minVehicleYear = 1950;

  /// Rides stop accepting bookings this long before departure. The server
  /// refuses a late booking with a 422; this only greys the button out early.
  static const Duration bookingCutoff = Duration(minutes: 30);

  /// A passenger may cancel freely until this point before departure. Purely a
  /// UI warning — the API imposes no fee.
  static const Duration freeCancellationWindow = Duration(hours: 6);

  /// Reviews stay open this long after a trip completes.
  static const Duration reviewWindow = Duration(days: 14);

  // Field lengths, from the validation tables in API.md.
  static const int maxNoteLength = 400;

  /// API.md §19: a ride request's `note` is shorter than a ride's — it is a
  /// line to a driver, not a description of the trip.
  static const int maxRequestNoteLength = 300;
  static const int maxReviewLength = 500;
  static const int maxMessageLength = 1000;
  static const int maxAboutLength = 300;
  static const int maxFullNameLength = 255;
  static const int minFullNameLength = 3;
  static const int maxPlateLength = 15;
  static const int maxPointLength = 255;
  static const int maxCancellationReasonLength = 255;
  static const int maxBookingMessageLength = 400;
  static const int maxReportDetailsLength = 2000;

  /// API.md §7: `file` is ≤8 MB, §4: `photo` is ≤4 MB.
  static const int maxDocumentBytes = 8 * 1024 * 1024;
  static const int maxPhotoBytes = 4 * 1024 * 1024;

  static const int otpLength = 6;
  static const Duration otpResendCooldown = Duration(seconds: 60);
  static const Duration otpTimeout = Duration(seconds: 90);

  /// Documents a driver must have approved before publishing (API.md §7).
  static const int requiredDocumentCount = 4;

  /// Page sizes the API uses, so a list knows when it has everything.
  static const int ridesPerPage = 20;
  static const int messagesPerPage = 50;
  static const int notificationsPerPage = 30;

  /// The latest birth year the profile form will accept.
  static int get maxBirthYear => DateTime.now().year - minimumAge;

  /// The latest vehicle year the form will accept.
  static int get maxVehicleYear => DateTime.now().year + 1;
}

abstract final class AppLinks {
  static const String supportEmail = 'support@yolyoldasi.az';
  static const String supportPhone = '+994556691248';
  static const String termsUrl = 'https://yolyoldasi.az/terms-of-use';
  static const String privacyUrl = 'https://yolyoldasi.az/privacy-policy';
  static const String helpUrl = 'https://yolyoldasi.az/contact';

  /// Where the update screen sends the user when the server names no store
  /// URL of its own (`GET /app-version`).
  ///
  /// The Play listing is addressed by application id, so it is known before
  /// the app ships. The App Store is not — a listing is reachable only by the
  /// numeric id Apple assigns at first submission — so iOS falls back to a
  /// search. Set the real link in the admin panel once the app is live;
  /// dropping a user on a search results page is a stopgap, not the plan.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=yolyoldasi.az';

  static const String appStoreSearchUrl =
      'https://apps.apple.com/az/search?term=Yol%20Yolda%C5%9F%C4%B1';
}

/// Keys for device-local values in `SharedPreferences`.
///
/// Only settings that belong to the *device* live here. Anything tied to the
/// account (language, notification switches, active mode) is on the server and
/// is read from `/me`.
abstract final class PrefKeys {
  static const themeMode = 'pref_theme_mode';
  static const languageCode = 'pref_language_code';
  static const onboardingSeen = 'pref_onboarding_seen';

  /// The release the user last answered "later" to, so an *optional* update
  /// prompt asks once per release rather than on every launch. Keyed by the
  /// version rather than a bare flag: the next release must be free to ask
  /// again. A forced update ignores this entirely — there is no "later".
  static const dismissedUpdate = 'pref_dismissed_update_version';
}
