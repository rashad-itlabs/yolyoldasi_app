/// Every path and route name in the app, in one place.
///
/// Ids are `int` on the wire, so the builders parse the path parameter and the
/// helpers take an `int` — a mistyped id then fails to compile rather than 404
/// at runtime.
abstract final class Routes {
  // Boot / auth
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const profileSetup = '/profile-setup';
  static const blocked = '/blocked';

  /// The forced-update wall. Outranks every other destination, including the
  /// sign-in screen — see the guard in `app_router.dart`.
  static const updateRequired = '/update';

  // Shell tabs
  static const home = '/home';
  static const bookings = '/bookings';
  static const chat = '/chat';
  static const profile = '/profile';

  // Rides
  static const publishRide = '/ride/publish';
  static String rideDetail(int id) => '/ride/$id';
  static String rideEdit(int id) => '/ride/$id/edit';
  static String rideBookings(int id) => '/ride/$id/bookings';
  static const rideDetailPath = '/ride/:rideId';
  static const rideEditPath = 'edit';
  static const rideBookingsPath = 'bookings';

  // Search
  static const searchResults = '/search';

  // Ride requests — the demand side of the marketplace
  static const rideRequests = '/ride-requests';
  static const rideRequestsIncoming = '/ride-requests/incoming';
  static String rideRequestDetail(int id) => '/ride-requests/$id';
  static const rideRequestDetailPath = ':requestId';

  // Bookings
  static String bookingDetail(int id) => '/bookings/$id';
  static const bookingDetailPath = ':bookingId';

  // Chat
  static String conversation(int id) => '/chat/$id';
  static const conversationPath = ':conversationId';

  // Profile / people
  static String publicProfile(int id) => '/user/$id';
  static const publicProfilePath = '/user/:userId';
  static const editProfile = '/profile/edit';
  static const editProfilePath = 'edit';
  static const vehicle = '/profile/vehicle';
  static const vehiclePath = 'vehicle';
  static const documents = '/profile/documents';
  static const documentsPath = 'documents';
  static const myReviews = '/profile/reviews';
  static const myReviewsPath = 'reviews';
  static const referral = '/profile/referral';
  static const referralPath = 'referral';

  // Reviews
  static String writeReview(int bookingId) => '/review/$bookingId';
  static const writeReviewPath = '/review/:bookingId';

  // Misc
  static const notifications = '/notifications';
  static const settings = '/settings';

  /// Parses a path parameter, falling back to `0` — which every endpoint
  /// answers with a 404, so a malformed link lands on the not-found state
  /// rather than crashing the builder.
  static int idOf(String? raw) => int.tryParse(raw ?? '') ?? 0;
}
