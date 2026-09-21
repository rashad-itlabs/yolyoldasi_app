/// Every path in `API.md`, relative to `AppConfig.apiBaseUrl`.
///
/// Kept in one place so a route rename on the server is a one-line change here
/// rather than a grep through the services.
abstract final class Api {
  // -------------------------------------------------------------------- auth
  /// Step 1 of sign-in: hands over a phone number, gets an OTP issued.
  static const authPhoneRequest = '/auth/phone/request';

  /// Step 2: trades the phone number and the code for a Sanctum token.
  static const authPhoneVerify = '/auth/phone/verify';

  static const authLogout = '/auth/logout';
  static const authAccount = '/auth/account';

  // ------------------------------------------------------------------ profile
  static const me = '/me';
  static const meMode = '/me/mode';
  static const mePhoto = '/me/photo';
  static const meNotificationPreferences = '/me/notification-preferences';
  static const meDeviceTokens = '/me/device-tokens';

  /// Invite code, how many it brought in, and how long the reward still runs
  /// (API.md §21).
  static const meReferral = '/me/referral';

  // ------------------------------------------------------------------- cities
  static const cities = '/cities';

  // -------------------------------------------------------------- app version
  /// Public, and deliberately so: the update wall has to be able to stand in
  /// front of the sign-in screen.
  static const appVersion = '/app-version';

  // ------------------------------------------------------------------- driver
  static const driverProfile = '/driver/profile';
  static const driverDocuments = '/driver/documents';

  // ----------------------------------------------------------------- vehicles
  static const vehicles = '/vehicles';
  static String vehicle(int id) => '/vehicles/$id';

  // -------------------------------------------------------------------- rides
  /// Open to guests, and the search screen relies on that: a first-time visitor
  /// has to be able to see what is on offer before handing over a phone number
  /// (API.md §18).
  static const rides = '/rides';
  static const ridesMine = '/rides/mine';
  static String ride(int id) => '/rides/$id';
  static String rideComplete(int id) => '/rides/$id/complete';
  static String rideBookings(int rideId) => '/rides/$rideId/bookings';

  /// Re-publishes an existing listing on a new date — the two-tap path for the
  /// driver who makes the same run every week (API.md §21).
  static String rideRepeat(int id) => '/rides/$id/repeat';

  // ------------------------------------------------------------ ride requests
  /// The demand side of the marketplace: what passengers are looking for
  /// (API.md §19).
  static const rideRequests = '/ride-requests';
  static const rideRequestsIncoming = '/ride-requests/incoming';
  static String rideRequest(int id) => '/ride-requests/$id';

  // ------------------------------------------------------------------- demand
  /// How many people are searching a route, and what it usually costs
  /// (API.md §20).
  static const demand = '/demand';
  static const demandTop = '/demand/top';
  static const priceSuggestion = '/price-suggestion';

  // --------------------------------------------------------------- telemetry
  /// Open, on purpose: the steps before sign-in are where the funnel leaks
  /// most (API.md §22).
  static const events = '/events';

  // ----------------------------------------------------------------- bookings
  static const bookings = '/bookings';
  static const bookingsIncoming = '/bookings/incoming';
  static String booking(int id) => '/bookings/$id';
  static String bookingConfirm(int id) => '/bookings/$id/confirm';
  static String bookingReject(int id) => '/bookings/$id/reject';
  static String bookingCancel(int id) => '/bookings/$id/cancel';

  /// Driver only. Shuts this ride to the passenger who cancelled, so the
  /// re-booking the API otherwise allows is refused with a 409 (API.md §10).
  static String bookingBlock(int id) => '/bookings/$id/block';
  static String bookingUnblock(int id) => '/bookings/$id/unblock';
  static String bookingReviews(int id) => '/bookings/$id/reviews';

  // ------------------------------------------------------------ conversations
  static const conversations = '/conversations';
  static const conversationsUnreadCount = '/conversations/unread-count';
  static String conversationMessages(int id) => '/conversations/$id/messages';
  static String conversationRead(int id) => '/conversations/$id/read';

  // -------------------------------------------------------------------- users
  static String user(int id) => '/users/$id';
  static String userReviews(int id) => '/users/$id/reviews';

  // ------------------------------------------------------------ notifications
  static const notifications = '/notifications';
  static const notificationsUnreadCount = '/notifications/unread-count';
  static const notificationsReadAll = '/notifications/read-all';
  static String notificationRead(int id) => '/notifications/$id/read';

  // ------------------------------------------------------------------ reports
  static const reports = '/reports';
}
