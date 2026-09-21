import 'strings_az.dart';
import 'strings_en.dart';
import 'strings_ru.dart';

/// Typed access to the localized string table.
///
/// The maps in `strings_*.dart` are the single source of truth; the getters
/// below are generated from the Azerbaijani key set. Azerbaijani also acts as
/// the fallback, so a missing translation degrades gracefully instead of
/// crashing.
///
/// Obtain an instance with `context.l10n`.
class AppStrings {
  const AppStrings._(this.languageCode, this._table);

  factory AppStrings.of(String languageCode) => switch (languageCode) {
    'ru' => const AppStrings._('ru', kStringsRu),
    'en' => const AppStrings._('en', kStringsEn),
    _ => const AppStrings._('az', kStringsAz),
  };

  final String languageCode;
  final Map<String, String> _table;

  String _get(String key) => _table[key] ?? kStringsAz[key] ?? key;

  /// Escape hatch for dynamic keys (failure codes, enum names, ...).
  String byKey(String key) => _get(key);

  // ---------------------------------------------------------------- general
  String get appName => _get('appName');
  String get appTagline => _get('appTagline');
  String get ok => _get('ok');
  String get cancel => _get('cancel');
  String get save => _get('save');
  String get delete => _get('delete');
  String get edit => _get('edit');
  String get retry => _get('retry');
  String get next => _get('next');
  String get back => _get('back');
  String get skip => _get('skip');
  String get done => _get('done');
  String get close => _get('close');
  String get search => _get('search');
  String get confirm => _get('confirm');
  String get reject => _get('reject');
  String get yes => _get('yes');
  String get no => _get('no');
  String get loading => _get('loading');
  String get seeAll => _get('seeAll');
  String get clear => _get('clear');
  String get apply => _get('apply');
  String get reset => _get('reset');
  String get optional => _get('optional');
  String get continueLabel => _get('continueLabel');
  String get share => _get('share');
  String get copy => _get('copy');
  String get copied => _get('copied');
  String get today => _get('today');
  String get tomorrow => _get('tomorrow');
  String get yesterday => _get('yesterday');
  String get from => _get('from');
  String get to => _get('to');
  String get currency => _get('currency');
  String get perSeat => _get('perSeat');
  String get rating => _get('rating');
  String get noResultsTitle => _get('noResultsTitle');
  String get noResultsBody => _get('noResultsBody');
  String get emptyTitle => _get('emptyTitle');
  String get refresh => _get('refresh');
  String get showMore => _get('showMore');
  String get showLess => _get('showLess');
  String get anonymous => _get('anonymous');
  String get you => _get('you');
  String get now => _get('now');
  String get unknown => _get('unknown');

  // ------------------------------------------------------------ onboarding
  String get onboard1Title => _get('onboard1Title');
  String get onboard1Body => _get('onboard1Body');
  String get onboard2Title => _get('onboard2Title');
  String get onboard2Body => _get('onboard2Body');
  String get onboard3Title => _get('onboard3Title');
  String get onboard3Body => _get('onboard3Body');
  String get getStarted => _get('getStarted');

  // ------------------------------------------------------------------ auth
  String get loginTitle => _get('loginTitle');
  String get loginSubtitle => _get('loginSubtitle');
  String get phoneNumber => _get('phoneNumber');
  String get phoneHint => _get('phoneHint');
  String get sendCode => _get('sendCode');
  String get termsPrefix => _get('termsPrefix');
  String get termsOfUse => _get('termsOfUse');
  String get termsAnd => _get('termsAnd');
  String get privacyPolicy => _get('privacyPolicy');
  String get termsSuffix => _get('termsSuffix');
  String get otpTitle => _get('otpTitle');
  String get changeNumber => _get('changeNumber');
  String get resendCode => _get('resendCode');
  String get resendIn => _get('resendIn');
  String get verify => _get('verify');
  String get otpAutoHint => _get('otpAutoHint');
  String get signingIn => _get('signingIn');

  // ------------------------------------------------------------------ role
  String get roleTitle => _get('roleTitle');
  String get roleSubtitle => _get('roleSubtitle');
  String get driver => _get('driver');
  String get passenger => _get('passenger');
  String get driverRoleDesc => _get('driverRoleDesc');
  String get passengerRoleDesc => _get('passengerRoleDesc');
  String get driverMode => _get('driverMode');
  String get passengerMode => _get('passengerMode');
  String get activeMode => _get('activeMode');

  // --------------------------------------------------------------- profile
  String get profile => _get('profile');
  String get profileSetupTitle => _get('profileSetupTitle');
  String get profileSetupSubtitle => _get('profileSetupSubtitle');
  String get fullName => _get('fullName');
  String get fullNameHint => _get('fullNameHint');
  String get about => _get('about');
  String get aboutHint => _get('aboutHint');
  String get gender => _get('gender');
  String get male => _get('male');
  String get female => _get('female');
  String get genderUnspecified => _get('genderUnspecified');
  String get photo => _get('photo');
  String get addPhoto => _get('addPhoto');
  String get changePhoto => _get('changePhoto');
  String get removePhoto => _get('removePhoto');
  String get takePhoto => _get('takePhoto');
  String get pickFromGallery => _get('pickFromGallery');
  String get editProfile => _get('editProfile');
  String get memberSince => _get('memberSince');
  String get completedTrips => _get('completedTrips');
  String get profileSaved => _get('profileSaved');
  String get verifiedBadge => _get('verifiedBadge');
  String get phoneVerified => _get('phoneVerified');

  // --------------------------------------------------------------- vehicle
  String get vehicle => _get('vehicle');
  String get vehicleInfo => _get('vehicleInfo');
  String get vehicleBrand => _get('vehicleBrand');
  String get vehicleBrandHint => _get('vehicleBrandHint');
  String get vehicleModel => _get('vehicleModel');
  String get vehicleModelHint => _get('vehicleModelHint');
  String get vehicleColor => _get('vehicleColor');
  String get vehiclePlate => _get('vehiclePlate');
  String get vehiclePlateHint => _get('vehiclePlateHint');
  String get vehicleYear => _get('vehicleYear');
  String get vehicleSeats => _get('vehicleSeats');
  String get saveVehicle => _get('saveVehicle');
  String get vehicleSaved => _get('vehicleSaved');
  String get noVehicle => _get('noVehicle');

  // ------------------------------------------------------------- documents
  String get documents => _get('documents');
  String get documentsTitle => _get('documentsTitle');
  String get documentsSubtitle => _get('documentsSubtitle');
  String get docIdCard => _get('docIdCard');
  String get docDriverLicense => _get('docDriverLicense');
  String get docVehicleRegistration => _get('docVehicleRegistration');
  String get docInsurance => _get('docInsurance');
  String get docIdCardDesc => _get('docIdCardDesc');
  String get docDriverLicenseDesc => _get('docDriverLicenseDesc');
  String get docVehicleRegistrationDesc => _get('docVehicleRegistrationDesc');
  String get docInsuranceDesc => _get('docInsuranceDesc');
  String get uploadDocument => _get('uploadDocument');
  String get replaceDocument => _get('replaceDocument');
  String get docStatusNotUploaded => _get('docStatusNotUploaded');
  String get docStatusPending => _get('docStatusPending');
  String get docStatusApproved => _get('docStatusApproved');
  String get docStatusRejected => _get('docStatusRejected');
  String get verificationPending => _get('verificationPending');
  String get verificationPendingBody => _get('verificationPendingBody');
  String get verificationApproved => _get('verificationApproved');
  String get verificationRejected => _get('verificationRejected');
  String get verificationRejectedBody => _get('verificationRejectedBody');
  String get rejectionReason => _get('rejectionReason');
  String get submitForReview => _get('submitForReview');
  String get documentsSubmitted => _get('documentsSubmitted');
  String get allDocumentsRequired => _get('allDocumentsRequired');

  // ------------------------------------------------------------------ ride
  String get publishRide => _get('publishRide');
  String get publishRideShort => _get('publishRideShort');
  String get editRide => _get('editRide');
  String get routeStep => _get('routeStep');
  String get scheduleStep => _get('scheduleStep');
  String get detailsStep => _get('detailsStep');
  String get fromCity => _get('fromCity');
  String get toCity => _get('toCity');
  String get selectCity => _get('selectCity');
  String get searchCity => _get('searchCity');
  String get swapCities => _get('swapCities');
  String get date => _get('date');
  String get time => _get('time');
  String get selectDate => _get('selectDate');
  String get selectTime => _get('selectTime');
  String get seatsAvailable => _get('seatsAvailable');
  String get pricePerSeat => _get('pricePerSeat');
  String get priceHint => _get('priceHint');
  String get rideNote => _get('rideNote');
  String get rideNoteHint => _get('rideNoteHint');
  String get pickupPoint => _get('pickupPoint');
  String get pickupPointHint => _get('pickupPointHint');
  String get dropoffPoint => _get('dropoffPoint');
  String get dropoffPointHint => _get('dropoffPointHint');
  String get publish => _get('publish');
  String get ridePublished => _get('ridePublished');
  String get rideUpdated => _get('rideUpdated');
  String get rideDeleted => _get('rideDeleted');
  String get deleteRideConfirm => _get('deleteRideConfirm');
  String get deleteRideWithBookings => _get('deleteRideWithBookings');
  String get myRides => _get('myRides');
  String get activeRides => _get('activeRides');
  String get pastRides => _get('pastRides');
  String get rideActive => _get('rideActive');
  String get rideInactive => _get('rideInactive');
  String get rideCompleted => _get('rideCompleted');
  String get rideCancelled => _get('rideCancelled');
  String get activateRide => _get('activateRide');
  String get deactivateRide => _get('deactivateRide');
  String get rideDetails => _get('rideDetails');
  String get noRidesYet => _get('noRidesYet');
  String get noRidesYetBody => _get('noRidesYetBody');
  String get rideFull => _get('rideFull');
  String get departure => _get('departure');
  String get instantBooking => _get('instantBooking');
  String get instantBookingDesc => _get('instantBookingDesc');
  String get requestBooking => _get('requestBooking');
  String get requestBookingDesc => _get('requestBookingDesc');

  // ---------------------------------------------------------------- search
  String get searchTitle => _get('searchTitle');
  String get searchRides => _get('searchRides');
  String get anyDate => _get('anyDate');
  String get passengersCount => _get('passengersCount');
  String get searchResults => _get('searchResults');
  String get filters => _get('filters');
  String get sortBy => _get('sortBy');
  String get sortEarliest => _get('sortEarliest');
  String get sortCheapest => _get('sortCheapest');
  String get sortTopRated => _get('sortTopRated');
  String get priceRange => _get('priceRange');
  String get timeOfDay => _get('timeOfDay');
  String get morning => _get('morning');
  String get afternoon => _get('afternoon');
  String get evening => _get('evening');
  String get night => _get('night');
  String get onlyVerified => _get('onlyVerified');
  String get noRidesFound => _get('noRidesFound');
  String get noRidesFoundBody => _get('noRidesFoundBody');
  String get popularRoutes => _get('popularRoutes');
  String get allActiveRides => _get('allActiveRides');
  String get noActiveRides => _get('noActiveRides');
  String get noActiveRidesBody => _get('noActiveRidesBody');

  // --------------------------------------------------------------- booking
  String get bookSeat => _get('bookSeat');
  String get bookingTitle => _get('bookingTitle');
  String get howManySeats => _get('howManySeats');
  String get totalPrice => _get('totalPrice');
  String get messageToDriver => _get('messageToDriver');
  String get messageToDriverHint => _get('messageToDriverHint');
  String get sendRequest => _get('sendRequest');
  String get bookNow => _get('bookNow');
  String get bookingSent => _get('bookingSent');
  String get bookingConfirmedToast => _get('bookingConfirmedToast');
  String get myBookings => _get('myBookings');
  String get bookingRequests => _get('bookingRequests');
  String get upcoming => _get('upcoming');
  String get history => _get('history');
  String get statusPending => _get('statusPending');
  String get statusConfirmed => _get('statusConfirmed');
  String get statusRejected => _get('statusRejected');
  String get statusCancelledByPassenger => _get('statusCancelledByPassenger');
  String get statusCancelledByDriver => _get('statusCancelledByDriver');
  String get statusCompleted => _get('statusCompleted');
  String get cancelRide => _get('cancelRide');

  /// API.md §9: a cancellation cascades to every pending and confirmed
  /// booking, so the confirmation says so.
  String get cancelRideConfirm => _get('cancelRideConfirm');
  String get cancelBooking => _get('cancelBooking');
  String get cancelBookingConfirm => _get('cancelBookingConfirm');
  String get bookingCancelled => _get('bookingCancelled');
  String get keepBooking => _get('keepBooking');

  /// API.md §10: the passenger's own cancellation reopens the ride, so the
  /// sheet promises the way back — and warns that the seat may not wait.
  String get cancelReleasesSeat => _get('cancelReleasesSeat');
  String get rebookSameRide => _get('rebookSameRide');
  String get rebookSameRideBody => _get('rebookSameRideBody');

  /// The driver declined, cancelled, or blocked them: that answer is final
  /// (API.md §10).
  String get rideClosedToYou => _get('rideClosedToYou');
  String get rideClosedToYouBody => _get('rideClosedToYouBody');

  /// Nobody shut the door — the seat simply went to someone else.
  String get seatTakenAlready => _get('seatTakenAlready');
  String get seatTakenAlreadyBody => _get('seatTakenAlreadyBody');

  /// The driver's veto over a cancelling passenger's return, and its undo.
  String get blockPassenger => _get('blockPassenger');
  String get blockPassengerConfirm => _get('blockPassengerConfirm');
  String get passengerBlocked => _get('passengerBlocked');
  String get passengerBlockedBody => _get('passengerBlockedBody');
  String get unblockPassenger => _get('unblockPassenger');
  String get passengerBlockedMsg => _get('passengerBlockedMsg');
  String get passengerUnblockedMsg => _get('passengerUnblockedMsg');
  String get lateCancellationWarning => _get('lateCancellationWarning');
  String get cancelReasonQuestion => _get('cancelReasonQuestion');
  String get cancelReasonPlanChanged => _get('cancelReasonPlanChanged');
  String get cancelReasonFoundCheaper => _get('cancelReasonFoundCheaper');
  String get cancelReasonNoAnswer => _get('cancelReasonNoAnswer');
  String get cancelReasonVehicleProblem => _get('cancelReasonVehicleProblem');
  String get cancelReasonRescheduled => _get('cancelReasonRescheduled');
  String get cancelReasonOther => _get('cancelReasonOther');
  String get cancelReasonHint => _get('cancelReasonHint');
  String get cancellationReasonTitle => _get('cancellationReasonTitle');
  String get findAnotherRide => _get('findAnotherRide');
  String get findAnotherRideBody => _get('findAnotherRideBody');
  String get confirmBooking => _get('confirmBooking');
  String get rejectBooking => _get('rejectBooking');
  String get bookingConfirmedMsg => _get('bookingConfirmedMsg');
  String get bookingRejectedMsg => _get('bookingRejectedMsg');
  String get noBookingsYet => _get('noBookingsYet');
  String get noBookingsYetBody => _get('noBookingsYetBody');
  String get noRequestsYet => _get('noRequestsYet');
  String get noRequestsYetBody => _get('noRequestsYetBody');
  String get seatsBooked => _get('seatsBooked');
  String get bookedBy => _get('bookedBy');
  String get markCompleted => _get('markCompleted');
  String get tripCompleted => _get('tripCompleted');

  // --------------------------------------------------------------- contact
  String get contact => _get('contact');
  String get callDriver => _get('callDriver');
  String get callPassenger => _get('callPassenger');
  String get sendMessage => _get('sendMessage');
  String get phoneHiddenTitle => _get('phoneHiddenTitle');
  String get phoneHiddenBody => _get('phoneHiddenBody');
  String get openWhatsapp => _get('openWhatsapp');
  String get cannotCall => _get('cannotCall');

  // ------------------------------------------------------------------ chat
  String get chat => _get('chat');
  String get messages => _get('messages');
  String get typeMessage => _get('typeMessage');
  String get noMessages => _get('noMessages');
  String get noMessagesBody => _get('noMessagesBody');
  String get noConversations => _get('noConversations');
  String get noConversationsBody => _get('noConversationsBody');
  String get chatLockedTitle => _get('chatLockedTitle');
  String get chatLockedBody => _get('chatLockedBody');

  // --------------------------------------------------------- notifications
  String get notifications => _get('notifications');
  String get markAllRead => _get('markAllRead');
  String get noNotifications => _get('noNotifications');
  String get noNotificationsBody => _get('noNotificationsBody');
  String get notifNewBookingTitle => _get('notifNewBookingTitle');
  String get notifBookingConfirmedTitle => _get('notifBookingConfirmedTitle');
  String get notifBookingRejectedTitle => _get('notifBookingRejectedTitle');
  String get notifBookingCancelledTitle => _get('notifBookingCancelledTitle');
  String get notifRideReminderTitle => _get('notifRideReminderTitle');
  String get notifRideCancelledTitle => _get('notifRideCancelledTitle');
  String get notifNewMessageTitle => _get('notifNewMessageTitle');
  String get notifReviewRequestTitle => _get('notifReviewRequestTitle');
  String get notifDocsApprovedTitle => _get('notifDocsApprovedTitle');
  String get notifDocsRejectedTitle => _get('notifDocsRejectedTitle');
  String get notifAdminMessageTitle => _get('notifAdminMessageTitle');
  String get notifAdminMarketingTitle => _get('notifAdminMarketingTitle');

  /// A `type` this build does not recognise — see [NotificationType.unknown].
  String get notifUnknownTitle => _get('notifUnknownTitle');

  // Android notification channel names and descriptions. Both are shown in the
  // OS settings list, so they are user-facing copy, not identifiers.
  String get channelMessages => _get('channelMessages');
  String get channelMessagesDesc => _get('channelMessagesDesc');
  String get channelBookings => _get('channelBookings');
  String get channelBookingsDesc => _get('channelBookingsDesc');
  String get channelReminders => _get('channelReminders');
  String get channelRemindersDesc => _get('channelRemindersDesc');
  String get channelMarketing => _get('channelMarketing');
  String get channelMarketingDesc => _get('channelMarketingDesc');
  String get channelGeneral => _get('channelGeneral');
  String get channelGeneralDesc => _get('channelGeneralDesc');

  // --------------------------------------------------------------- reviews
  String get reviews => _get('reviews');
  String get rateTrip => _get('rateTrip');
  String get rateTripSubtitle => _get('rateTripSubtitle');
  String get yourRating => _get('yourRating');
  String get writeComment => _get('writeComment');
  String get writeCommentHint => _get('writeCommentHint');
  String get submitReview => _get('submitReview');
  String get reviewSubmitted => _get('reviewSubmitted');
  String get noReviews => _get('noReviews');
  String get noReviewsBody => _get('noReviewsBody');
  String get ratingPoor => _get('ratingPoor');
  String get ratingFair => _get('ratingFair');
  String get ratingGood => _get('ratingGood');
  String get ratingVeryGood => _get('ratingVeryGood');
  String get ratingExcellent => _get('ratingExcellent');
  String get reviewsAsDriver => _get('reviewsAsDriver');
  String get reviewsAsPassenger => _get('reviewsAsPassenger');
  String get pendingReviews => _get('pendingReviews');

  // -------------------------------------------------------------- settings
  String get settings => _get('settings');
  String get language => _get('language');
  String get languageAz => _get('languageAz');
  String get languageRu => _get('languageRu');
  String get languageEn => _get('languageEn');
  String get appearance => _get('appearance');
  String get themeSystem => _get('themeSystem');
  String get themeLight => _get('themeLight');
  String get themeDark => _get('themeDark');
  String get notificationSettings => _get('notificationSettings');
  String get pushNotifications => _get('pushNotifications');
  String get bookingNotifications => _get('bookingNotifications');
  String get messageNotifications => _get('messageNotifications');
  String get reminderNotifications => _get('reminderNotifications');
  String get marketingNotifications => _get('marketingNotifications');
  String get account => _get('account');
  String get logout => _get('logout');
  String get logoutConfirm => _get('logoutConfirm');
  String get deleteAccount => _get('deleteAccount');
  String get deleteAccountTitle => _get('deleteAccountTitle');
  String get deleteAccountWarning => _get('deleteAccountWarning');
  String get deleteAccountConfirmHint => _get('deleteAccountConfirmHint');
  String get deleteAccountKeyword => _get('deleteAccountKeyword');
  String get accountDeleted => _get('accountDeleted');
  String get support => _get('support');
  String get helpCenter => _get('helpCenter');
  String get contactSupport => _get('contactSupport');
  String get rateApp => _get('rateApp');
  String get aboutApp => _get('aboutApp');
  String get version => _get('version');
  String get legal => _get('legal');

  // ----------------------------------------------------------------- admin
  String get adminPanel => _get('adminPanel');
  String get adminOverview => _get('adminOverview');
  String get adminDocuments => _get('adminDocuments');
  String get adminUsers => _get('adminUsers');
  String get adminRides => _get('adminRides');
  String get adminReports => _get('adminReports');
  String get adminNoPending => _get('adminNoPending');
  String get approve => _get('approve');
  String get block => _get('block');
  String get unblock => _get('unblock');
  String get blocked => _get('blocked');
  String get userBlocked => _get('userBlocked');
  String get userUnblocked => _get('userUnblocked');
  String get totalUsers => _get('totalUsers');
  String get totalDrivers => _get('totalDrivers');
  String get totalRides => _get('totalRides');
  String get totalBookings => _get('totalBookings');
  String get pendingVerifications => _get('pendingVerifications');
  String get openReports => _get('openReports');
  String get reportUser => _get('reportUser');
  String get reportReason => _get('reportReason');
  String get reportSubmitted => _get('reportSubmitted');
  String get resolveReport => _get('resolveReport');
  String get adminOnly => _get('adminOnly');

  // ------------------------------------------------------------ validation
  String get fieldRequired => _get('fieldRequired');
  String get invalidPhone => _get('invalidPhone');
  String get invalidName => _get('invalidName');
  String get invalidOtpFormat => _get('invalidOtpFormat');
  String get invalidPlate => _get('invalidPlate');
  String get invalidPrice => _get('invalidPrice');
  String get invalidYear => _get('invalidYear');
  String get sameCityError => _get('sameCityError');
  String get pastDateError => _get('pastDateError');
  String get tooFarDateError => _get('tooFarDateError');
  String get selectAtLeastOneSeat => _get('selectAtLeastOneSeat');
  String get commentTooLong => _get('commentTooLong');

  // ---------------------------------------------------------------- errors
  String get errNetwork => _get('errNetwork');
  String get errTimeout => _get('errTimeout');
  String get errServer => _get('errServer');
  String get errUnauthenticated => _get('errUnauthenticated');
  String get errPermissionDenied => _get('errPermissionDenied');
  String get errNotFound => _get('errNotFound');
  String get errAlreadyExists => _get('errAlreadyExists');
  String get errInvalidInput => _get('errInvalidInput');
  String get errInvalidPhoneNumber => _get('errInvalidPhoneNumber');
  String get errInvalidOtp => _get('errInvalidOtp');
  String get errOtpExpired => _get('errOtpExpired');
  String get errTooManyRequests => _get('errTooManyRequests');
  String get errSeatsUnavailable => _get('errSeatsUnavailable');
  String get errRideNotBookable => _get('errRideNotBookable');
  String get errBookingNotCancellable => _get('errBookingNotCancellable');
  String get errSelfBooking => _get('errSelfBooking');
  String get errDocumentsPending => _get('errDocumentsPending');
  String get errDocumentsRejected => _get('errDocumentsRejected');
  String get errDriverProfileRequired => _get('errDriverProfileRequired');
  String get errWomenOnlyRide => _get('errWomenOnlyRide');
  String get errStorage => _get('errStorage');
  String get errCancelled => _get('errCancelled');
  String get errUnknown => _get('errUnknown');
  String get errorTitle => _get('errorTitle');

  // ------------------------------------------------------------ navigation
  String get navSearch => _get('navSearch');
  String get navRides => _get('navRides');
  String get navBookings => _get('navBookings');
  String get navChat => _get('navChat');
  String get navProfile => _get('navProfile');
  String get navPublish => _get('navPublish');
  String get navRequests => _get('navRequests');

  // ---------------------------------------------------------------------
  // Parameterised strings. Kept hand-written so the placeholders stay typed.
  // ---------------------------------------------------------------------

  /// "3 yer" / "3 места" / "3 seats"
  String seats(int count) => switch (languageCode) {
    'ru' => '$count ${_ruPlural(count, 'место', 'места', 'мест')}',
    'en' => count == 1 ? '1 seat' : '$count seats',
    _ => '$count yer',
  };

  /// "2 yer qaldı" – the scarcity line on a ride card.
  String seatsLeft(int count) => switch (languageCode) {
    'ru' => 'Осталось $count ${_ruPlural(count, 'место', 'места', 'мест')}',
    'en' => count == 1 ? '1 seat left' : '$count seats left',
    _ => '$count yer qaldı',
  };

  String passengers(int count) => switch (languageCode) {
    'ru' => '$count ${_ruPlural(count, 'пассажир', 'пассажира', 'пассажиров')}',
    'en' => count == 1 ? '1 passenger' : '$count passengers',
    _ => '$count sərnişin',
  };

  String reviewsCount(int count) => switch (languageCode) {
    'ru' => '$count ${_ruPlural(count, 'отзыв', 'отзыва', 'отзывов')}',
    'en' => count == 1 ? '1 review' : '$count reviews',
    _ => '$count rəy',
  };

  String tripsCount(int count) => switch (languageCode) {
    'ru' => '$count ${_ruPlural(count, 'поездка', 'поездки', 'поездок')}',
    'en' => count == 1 ? '1 trip' : '$count trips',
    _ => '$count səfər',
  };

  /// The OTP screen's subtitle. A method rather than a key because the number
  /// falls on either side of the sentence depending on the language.
  String otpSentTo(String phone) => switch (languageCode) {
    'ru' => 'Мы отправили 6-значный код на номер $phone',
    'en' => 'We sent a 6-digit code to $phone',
    _ => '$phone nömrəsinə 6 rəqəmli kod göndərdik',
  };

  /// Countdown on the OTP screen: "00:42 sonra".
  String resendCountdown(String time) => switch (languageCode) {
    'ru' => 'Отправить повторно через $time',
    'en' => 'Resend in $time',
    _ => '$time sonra yenidən göndər',
  };

  String stepOf(int current, int total) => switch (languageCode) {
    'ru' => 'Шаг $current из $total',
    'en' => 'Step $current of $total',
    _ => 'Addım $current / $total',
  };

  String priceAzn(String amount) => switch (languageCode) {
    'en' => '$amount AZN',
    _ => '$amount AZN',
  };

  String greeting(String name) => switch (languageCode) {
    'ru' => 'Привет, $name',
    'en' => 'Hi, $name',
    _ => 'Salam, $name',
  };

  String bookingRequestBody(String name, int seatCount) =>
      switch (languageCode) {
        'ru' => '$name бронирует ${seats(seatCount)}',
        'en' => '$name is booking ${seats(seatCount)}',
        _ => '$name ${seats(seatCount)} bron edir',
      };

  String routeLabel(String from, String to) => '$from → $to';

  String memberSinceValue(String date) => switch (languageCode) {
    'ru' => 'С $date',
    'en' => 'Since $date',
    _ => '$date-dən',
  };

  // ------------------------------------------------------- API-specific
  /// The price and departure-window filters narrow the loaded results rather
  /// than the query, because `GET /rides` has no parameter for either.
  String get filtersLocalNote => _get('filtersLocalNote');

  /// API.md §10: a 409 on a booking is permanent, so this reads differently
  /// from a generic "already exists".
  String get alreadyRequestedTitle => _get('alreadyRequestedTitle');
  String get alreadyRequestedBody => _get('alreadyRequestedBody');
  String get alreadyReviewedBody => _get('alreadyReviewedBody');

  String get conversationLocked => _get('conversationLocked');

  /// Shown when a notification's deep-link ids are all null (API.md §13).
  String get linkUnavailableTitle => _get('linkUnavailableTitle');
  String get linkUnavailableBody => _get('linkUnavailableBody');

  String get loadMore => _get('loadMore');

  /// The banner around the code `POST /auth/phone/request` echoes back while
  /// there is no SMS provider. Both keys go unused the moment the API stops
  /// sending it.
  String get devCodeTitle => _get('devCodeTitle');
  String get devCodeBody => _get('devCodeBody');

  String get chooseModeTitle => _get('chooseModeTitle');
  String get chooseModeBody => _get('chooseModeBody');
  String get driverModeNeedsVehicle => _get('driverModeNeedsVehicle');
  String get city => _get('city');
  String get birthYear => _get('birthYear');

  /// API.md §7: `back_file` only applies to the ID card and the licence,
  /// and both sides travel in the same request.
  String get docBackSideRequired => _get('docBackSideRequired');
  String get docBothSides => _get('docBothSides');
  String get documentsNoPreview => _get('documentsNoPreview');
  String get seatsIncludeDriver => _get('seatsIncludeDriver');
  String get plateVisibleToYou => _get('plateVisibleToYou');
  String get routeNotEditable => _get('routeNotEditable');

  // ------------------------------------------------------------- app update
  String get updateRequiredTitle => _get('updateRequiredTitle');
  String get updateRequiredBody => _get('updateRequiredBody');
  String get updateOptionalTitle => _get('updateOptionalTitle');
  String get updateOptionalBody => _get('updateOptionalBody');
  String get updateNow => _get('updateNow');
  String get updateLater => _get('updateLater');
  String get updateStoreUnavailable => _get('updateStoreUnavailable');

  String updateNewVersion(String version) => switch (languageCode) {
    'ru' => 'Новая версия $version',
    'en' => 'New version $version',
    _ => 'Yeni versiya $version',
  };

  String updateMinVersion(String version) => switch (languageCode) {
    'ru' => 'Минимальная версия: $version',
    'en' => 'Minimum version: $version',
    _ => 'Minimum tələb olunan versiya: $version',
  };

  String rateWithName(String name) => switch (languageCode) {
    'ru' => 'Оцените: $name',
    'en' => 'Rate $name',
    _ => '$name-i qiymətləndirin',
  };

  String documentsApprovedCount(int done, int total) => '$done/$total';

  static String _ruPlural(int n, String one, String few, String many) {
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return many;
    return switch (n % 10) {
      1 => one,
      2 || 3 || 4 => few,
      _ => many,
    };
  }

  // ------------------------------------------------- böyümə funksiyaları
  String get rideRequests => _get('rideRequests');
  String get myRideRequests => _get('myRideRequests');
  String get createRideRequest => _get('createRideRequest');
  String get createRideRequestTitle => _get('createRideRequestTitle');
  String get createRideRequestBody => _get('createRideRequestBody');
  String get rideRequestCreated => _get('rideRequestCreated');
  String get rideRequestCreatedBody => _get('rideRequestCreatedBody');
  String get rideRequestCancelled => _get('rideRequestCancelled');
  String get rideRequestCancel => _get('rideRequestCancel');
  String get rideRequestCancelConfirm => _get('rideRequestCancelConfirm');
  String get rideRequestMatches => _get('rideRequestMatches');
  String get rideRequestNoMatches => _get('rideRequestNoMatches');
  String get rideRequestNoMatchesBody => _get('rideRequestNoMatchesBody');
  String get noRideRequests => _get('noRideRequests');
  String get noRideRequestsBody => _get('noRideRequestsBody');
  String get incomingRideRequests => _get('incomingRideRequests');
  String get incomingRideRequestsBody => _get('incomingRideRequestsBody');
  String get noIncomingRideRequests => _get('noIncomingRideRequests');
  String get noIncomingRideRequestsBody => _get('noIncomingRideRequestsBody');
  String get flexibleDays => _get('flexibleDays');
  String get flexibleDaysExact => _get('flexibleDaysExact');
  String get wantedDate => _get('wantedDate');
  String get requestNoteHint => _get('requestNoteHint');
  String get publishForThisRequest => _get('publishForThisRequest');
  String get rideRequestStatusOpen => _get('rideRequestStatusOpen');
  String get rideRequestStatusFulfilled => _get('rideRequestStatusFulfilled');
  String get rideRequestStatusCancelled => _get('rideRequestStatusCancelled');
  String get rideRequestStatusExpired => _get('rideRequestStatusExpired');
  String get demandTitle => _get('demandTitle');
  String get demandEmpty => _get('demandEmpty');
  String get topRoutesTitle => _get('topRoutesTitle');
  String get topRoutesBody => _get('topRoutesBody');
  String get demandPublishCta => _get('demandPublishCta');
  String get earningsTitle => _get('earningsTitle');
  String get earningsFuelNote => _get('earningsFuelNote');
  String get earningsFree => _get('earningsFree');
  String get suggestedPrice => _get('suggestedPrice');
  String get suggestedPriceHistory => _get('suggestedPriceHistory');
  String get suggestedPriceDistance => _get('suggestedPriceDistance');
  String get usePrice => _get('usePrice');
  String get womenOnly => _get('womenOnly');
  String get womenOnlyRide => _get('womenOnlyRide');
  String get womenOnlyHint => _get('womenOnlyHint');
  String get womenOnlyBlocked => _get('womenOnlyBlocked');
  String get filterDriverGender => _get('filterDriverGender');
  String get filterDriverAny => _get('filterDriverAny');
  String get filterDriverFemale => _get('filterDriverFemale');
  String get filterDriverMale => _get('filterDriverMale');
  String get filterInstantOnly => _get('filterInstantOnly');
  String get filterVerifiedOnly => _get('filterVerifiedOnly');
  String get filterWomenOnly => _get('filterWomenOnly');
  String get filterServerNote => _get('filterServerNote');
  String get verifiedDriver => _get('verifiedDriver');
  String get tierTrusted => _get('tierTrusted');
  String get tierRising => _get('tierRising');
  String get verifyBoostHint => _get('verifyBoostHint');
  String get repeatRide => _get('repeatRide');
  String get repeatRideTitle => _get('repeatRideTitle');
  String get repeatRideBody => _get('repeatRideBody');
  String get repeatWeeks => _get('repeatWeeks');
  String get repeatWeeksOnce => _get('repeatWeeksOnce');
  String get repeatCreated => _get('repeatCreated');
  String get shareRide => _get('shareRide');
  String get shareRideUnavailable => _get('shareRideUnavailable');
  String get referral => _get('referral');
  String get referralTitle => _get('referralTitle');
  String get referralBody => _get('referralBody');
  String get referralCode => _get('referralCode');
  String get referralInvited => _get('referralInvited');
  String get referralActive => _get('referralActive');
  String get referralBoostActive => _get('referralBoostActive');
  String get referralBoostUntil => _get('referralBoostUntil');
  String get referralShare => _get('referralShare');
  String get referralShareText => _get('referralShareText');
  String get referralCodeHint => _get('referralCodeHint');
  String get switchMode => _get('switchMode');
  String get switchToDriver => _get('switchToDriver');
  String get switchToPassenger => _get('switchToPassenger');
  String get switchModeConfirmDriver => _get('switchModeConfirmDriver');
  String get switchModeConfirmPassenger => _get('switchModeConfirmPassenger');
  String get switchModeDone => _get('switchModeDone');
  String get becomeDriverTitle => _get('becomeDriverTitle');
  String get becomeDriverBody => _get('becomeDriverBody');
  String get signInToContinue => _get('signInToContinue');
  String get signInToBook => _get('signInToBook');
  String get signInToRequest => _get('signInToRequest');
  String get browseAsGuest => _get('browseAsGuest');
  String get signIn => _get('signIn');
  String get skipSignIn => _get('skipSignIn');
  String get askDriversTitle => _get('askDriversTitle');
  String get askDriversBody => _get('askDriversBody');

  /// "43 nəfər bu həftə axtarıb" — the line that turns publishing from a
  /// gamble into an answer.
  String demandSearches(int count, int days) => switch (languageCode) {
    'ru' =>
      '$count ${_ruPlural(count, 'человек искал', 'человека искали', 'человек искали')} за $days ${_ruPlural(days, 'день', 'дня', 'дней')}',
    'en' =>
      count == 1
          ? '1 person searched this route in $days days'
          : '$count people searched this route in $days days',
    _ => 'Son $days gündə $count nəfər bu marşrutu axtarıb',
  };

  /// "6 nəfər konkret yer istəyir" — the stronger of the two demand signals.
  String demandRequests(int count) => switch (languageCode) {
    'ru' =>
      '$count ${_ruPlural(count, 'пассажир ищет', 'пассажира ищут', 'пассажиров ищут')} место',
    'en' =>
      count == 1 ? '1 passenger wants a seat' : '$count passengers want a seat',
    _ => '$count nəfər konkret yer istəyir',
  };

  /// "3 yer × 15 ₼ = 45 ₼". The driver has to see the number before the
  /// motivation lands.
  String earningsLine(int seats, String price, String total) =>
      '$seats × $price = $total';

  /// "±1 gün" — how wide a ride request's date window is.
  String flexibleDaysLabel(int days) => switch (languageCode) {
    'ru' => days == 0 ? 'Точная дата' : '±$days ${_ruPlural(days, 'день', 'дня', 'дней')}',
    'en' => days == 0 ? 'Exact date' : days == 1 ? '±1 day' : '±$days days',
    _ => days == 0 ? 'Dəqiq tarix' : '±$days gün',
  };

  /// "Adətən 2 saat ərzində cavab verir" — the unknown that decides whether a
  /// passenger sends the request at all.
  String respondsWithin(int minutes) {
    final hours = (minutes / 60).round();
    final within = minutes < 90
        ? switch (languageCode) {
            'ru' => '$minutes мин',
            'en' => '$minutes min',
            _ => '$minutes dəq',
          }
        : switch (languageCode) {
            'ru' => '$hours ${_ruPlural(hours, 'час', 'часа', 'часов')}',
            'en' => hours == 1 ? '1 hour' : '$hours hours',
            _ => '$hours saat',
          };

    return switch (languageCode) {
      'ru' => 'Обычно отвечает в течение $within',
      'en' => 'Usually answers within $within',
      _ => 'Adətən $within ərzində cavab verir',
    };
  }

  /// "Sorğuların 90%-inə cavab verir".
  String responseRateLabel(int percent) => switch (languageCode) {
    'ru' => 'Отвечает на $percent% запросов',
    'en' => 'Answers $percent% of requests',
    _ => 'Sorğuların $percent%-inə cavab verir',
  };

  String repeatWeeksLabel(int weeks) => switch (languageCode) {
    'ru' => weeks == 1
        ? 'Только один раз'
        : '$weeks ${_ruPlural(weeks, 'неделя', 'недели', 'недель')} подряд',
    'en' => weeks == 1 ? 'Just this once' : 'Every week for $weeks weeks',
    _ => weeks == 1 ? 'Yalnız bu dəfə' : '$weeks həftə ardıcıl',
  };

  /// How many rides one publish created — the confirmation after a repeat.
  String ridesPublished(int count) => switch (languageCode) {
    'ru' => count == 1
        ? 'Объявление размещено'
        : 'Размещено $count ${_ruPlural(count, 'объявление', 'объявления', 'объявлений')}',
    'en' => count == 1 ? 'Ride published' : '$count rides published',
    _ => count == 1 ? 'Elan verildi' : '$count elan verildi',
  };
}
