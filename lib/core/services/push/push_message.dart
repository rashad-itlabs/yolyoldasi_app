import 'package:equatable/equatable.dart';

import '../../../features/notifications/domain/entities/app_notification.dart';
import '../../types.dart';
import 'notification_channels.dart';

/// One push as it reaches Dart, whatever transport carried it.
///
/// The wire form is a flat `Map<String, String>` because that is all FCM's
/// `data` block can hold — every value is a string, and nesting is impossible.
/// That constraint is why `actor` arrives as three flat keys rather than the
/// nested object API.md §13 shows for the REST endpoint: `JsonReader.child()`
/// silently returns an empty map for a String, so a JSON-encoded `actor` would
/// vanish without an error. The flattening is a deliberate part of the payload
/// contract and belongs in API.md §13 alongside it.
class PushMessage extends Equatable {
  const PushMessage({
    required this.type,
    this.notificationId,
    this.rideId,
    this.bookingId,
    this.conversationId,
    this.actorName,
    this.title,
    this.body,
    this.sentAt,
  });

  final NotificationType type;

  /// The row in `GET /notifications` this push mirrors, when the server sent
  /// one. It is how the client can fetch the full object — with the nested
  /// `actor` and `payload` the push cannot carry.
  final int? notificationId;

  final int? rideId;
  final int? bookingId;
  final int? conversationId;

  /// Who caused it. Only the display name travels in the push.
  final String? actorName;

  /// The `notification` block, when the transport exposes it. Absent for a
  /// data-only message.
  final String? title;
  final String? body;

  final DateTime? sentAt;

  /// Reads the flat `data` map.
  ///
  /// Everything is defensive: a malformed push must degrade to something the
  /// app can still show, never throw inside a background isolate where nothing
  /// would catch it.
  factory PushMessage.fromData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    return PushMessage(
      type: NotificationType.fromApi(_string(data['type'])),
      notificationId: _int(data['notification_id']),
      rideId: _int(data['ride_id']),
      bookingId: _int(data['booking_id']),
      conversationId: _int(data['conversation_id']),
      actorName: _string(data['actor_name']),
      title: title ?? _string(data['title']),
      body: body ?? _string(data['body']),
      sentAt: DateTime.tryParse(_string(data['created_at']) ?? ''),
    );
  }

  /// `null`, an empty string and the four characters `null` all mean absent.
  ///
  /// The last one matters: a server that string-interpolates a null id sends
  /// `"null"`, and `int.tryParse` would answer null anyway — but the same
  /// string in [actorName] would show up as a contact called "null".
  static String? _string(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return text;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    final text = _string(value);
    return text == null ? null : int.tryParse(text);
  }

  /// The same routing the notification centre already uses.
  ///
  /// Built as an [AppNotification] rather than re-deriving the rules, so a tap
  /// on a push and a tap on the in-app list can never disagree about where they
  /// lead. `actor` is null here: the push carries only a name, and inventing a
  /// half-empty profile would be worse than admitting it is absent.
  AppNotification toNotification() => AppNotification(
    id: notificationId ?? 0,
    type: type,
    createdAt: sentAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    rideId: rideId,
    bookingId: bookingId,
    conversationId: conversationId,
  );

  NotificationTarget get target => toNotification().target;

  /// Nothing to open — API.md §13 warns every id can be null at once.
  bool get isDeadLink => toNotification().isDeadLink;

  PushChannel get channel => PushChannel.forType(type);

  /// A stable id for the tray entry, so a second message in the same thread
  /// replaces the first instead of stacking.
  ///
  /// Falls back to the notification id, then to a constant — a push with no
  /// identity at all collapses onto one entry, which is noisy but bounded.
  int get collapseId {
    final id = conversationId ?? bookingId ?? rideId ?? notificationId;
    return id ?? 0;
  }

  /// Groups the tray entry, so several messages from one thread collapse.
  String get collapseKey => switch (target) {
    ConversationTarget(:final conversationId) => 'conv_$conversationId',
    BookingTarget(:final bookingId) => 'booking_$bookingId',
    RideTarget(:final rideId) => 'ride_$rideId',
    _ => 'general',
  };

  /// Round-trips through the flat wire form, for handing a tap between
  /// isolates or persisting one across a cold start.
  Json toData() => {
    'type': type.apiValue,
    'notification_id': ?notificationId?.toString(),
    'ride_id': ?rideId?.toString(),
    'booking_id': ?bookingId?.toString(),
    'conversation_id': ?conversationId?.toString(),
    'actor_name': ?actorName,
    'title': ?title,
    'body': ?body,
    'created_at': ?sentAt?.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    type,
    notificationId,
    rideId,
    bookingId,
    conversationId,
    actorName,
    title,
    body,
    sentAt,
  ];
}
