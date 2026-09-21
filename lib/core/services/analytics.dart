import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../types.dart';
import 'app_version_info.dart';

/// Names the server accepts. Anything else is dropped on arrival (API.md §22).
///
/// A closed set on both sides on purpose: with free-form strings one release
/// would send `search_empty` and the next `searchEmpty`, and the funnel would
/// quietly split in two without anybody noticing.
abstract final class Ev {
  static const appOpen = 'app_open';
  static const onboardingDone = 'onboarding_done';
  static const signInStarted = 'signin_started';
  static const signInCompleted = 'signin_completed';
  static const profileCompleted = 'profile_completed';

  static const searchPerformed = 'search_performed';
  static const searchEmpty = 'search_empty';
  static const rideViewed = 'ride_viewed';

  static const rideRequestCreated = 'ride_request_created';
  static const rideRequestOpened = 'ride_request_opened';

  static const bookingRequested = 'booking_requested';
  static const bookingConfirmed = 'booking_confirmed';
  static const bookingCancelled = 'booking_cancelled';

  static const publishStarted = 'publish_started';
  static const publishCompleted = 'publish_completed';
  static const rideRepeated = 'ride_repeated';
  static const vehicleAdded = 'vehicle_added';
  static const documentsUploaded = 'documents_uploaded';

  static const rideShared = 'ride_shared';
  static const modeSwitched = 'mode_switched';
  static const referralShared = 'referral_shared';
  static const reviewSubmitted = 'review_submitted';
}

/// Product telemetry, sent to our own backend.
///
/// There is no third-party SDK here and that is a decision, not an omission:
/// the API is ours, the data stays in the country, the app gains no new
/// dependency, and the funnel can be read with plain SQL from the admin panel.
///
/// Three rules hold everywhere in this class:
///
///  1. **It never throws and never blocks.** [log] returns nothing and is safe
///     to call from a build method or an error path. A failed flush loses
///     events; that is the correct trade against making a user wait.
///  2. **It carries no personal data.** Route ids, counts and screen names
///     only. The server strips the obvious keys as a second line of defence,
///     but the first line is not putting them in.
///  3. **It works signed out.** [anonymousId] ties the pre-sign-in steps
///     together, which is exactly where the funnel leaks most.
class Analytics {
  Analytics({
    required ApiClient client,
    required SharedPreferences preferences,
    required AppVersionInfo version,
    this.platform,
  }) : _client = client,
       _preferences = preferences,
       _version = version;

  final ApiClient _client;
  final SharedPreferences _preferences;
  final AppVersionInfo _version;

  /// `android` / `ios`, or null on a platform the API does not know.
  final String? platform;

  static const _anonymousIdKey = 'analytics.anonymous_id';

  /// Flush when this many are waiting, so a burst does not sit around.
  static const _batchSize = 20;

  /// …or when this long has passed, so a trickle still gets out.
  static const _flushAfter = Duration(seconds: 30);

  /// Hard ceiling. Reached only when the device has been offline for a while;
  /// past it the oldest events are dropped, because an unbounded buffer on a
  /// phone is a memory leak with extra steps.
  static const _maxBuffered = 200;

  final List<Json> _buffer = <Json>[];
  Timer? _timer;
  bool _sending = false;
  String? _anonymousId;

  /// A per-install id, created on first use and kept in shared preferences.
  ///
  /// Not the account id: its whole job is to exist *before* there is an
  /// account. It is random, carries nothing about the device, and dies with
  /// the install.
  String get anonymousId {
    final cached = _anonymousId;
    if (cached != null) return cached;

    final stored = _preferences.getString(_anonymousIdKey);
    if (stored != null && stored.isNotEmpty) {
      return _anonymousId = stored;
    }

    final random = Random.secure();
    final generated = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    // Fire-and-forget: if the write loses the race with a crash, the next
    // launch simply gets a new id, which costs one stitched-together funnel.
    unawaited(_preferences.setString(_anonymousIdKey, generated));

    return _anonymousId = generated;
  }

  /// Records one event. Cheap, synchronous, and impossible to fail.
  void log(String name, {Json? params}) {
    if (_buffer.length >= _maxBuffered) {
      _buffer.removeAt(0);
    }

    _buffer.add({
      'name': name,
      if (params != null && params.isNotEmpty) 'params': _sanitise(params),
      'occurred_at': DateTime.now().toIso8601String(),
    });

    if (_buffer.length >= _batchSize) {
      unawaited(flush());
      return;
    }

    _timer ??= Timer(_flushAfter, () => unawaited(flush()));
  }

  /// Sends whatever is buffered. Called on the timer, on a full batch, and when
  /// the app goes to the background.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;

    // One flight at a time. Two overlapping ones could send the same events
    // twice, and the second would have nothing to send anyway.
    if (_sending || _buffer.isEmpty) return;

    _sending = true;
    final batch = List<Json>.from(_buffer);
    _buffer.clear();

    final result = await _client.postFull(
      Api.events,
      body: {
        'anonymous_id': anonymousId,
        'platform': ?platform,
        'app_version': _version.display,
        'events': batch,
      },
      parse: (json) => json,
    );

    _sending = false;

    // On failure the events go back to the front of the queue and ride along
    // with the next flush. They are dropped only if that pushes past the cap —
    // telemetry must never grow without bound on someone's phone.
    if (result.isErr) {
      _buffer.insertAll(0, batch);
      if (_buffer.length > _maxBuffered) {
        _buffer.removeRange(0, _buffer.length - _maxBuffered);
      }
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await flush();
  }

  /// Second gate on personal data, in front of the server's own.
  ///
  /// Only scalars survive, and only a handful of them: a nested object would
  /// bloat the JSON column and is never what an analysis needs.
  Json _sanitise(Json params) {
    const forbidden = {
      'phone',
      'full_name',
      'name',
      'message',
      'text',
      'token',
      'email',
      'note',
    };

    final clean = <String, Object?>{};

    for (final entry in params.entries) {
      if (clean.length >= 12) break;
      if (forbidden.contains(entry.key.toLowerCase())) continue;
      final value = entry.value;
      if (value == null || value is num || value is bool || value is String) {
        clean[entry.key] = value;
      }
    }

    return clean;
  }
}
