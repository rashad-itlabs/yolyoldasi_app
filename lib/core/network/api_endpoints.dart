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
  static const meRecentSearches = '/me/recent-searches';

  // ------------------------------------------------------------------- cities
  static const cities = '/cities';

  // ------------------------------------------------------------------- driver
  static const driverProfile = '/driver/profile';
  static const driverDocuments = '/driver/documents';

  // ----------------------------------------------------------------- vehicles
  static const vehicles = '/vehicles';
  static String vehicle(int id) => '/vehicles/$id';

  // -------------------------------------------------------------------- rides
  static const rides = '/rides';
  static const ridesMine = '/rides/mine';
  static String ride(int id) => '/rides/$id';
  static String rideComplete(int id) => '/rides/$id/complete';
  static String rideBookings(int rideId) => '/rides/$rideId/bookings';

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
