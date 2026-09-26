import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/core/localization/app_localizations.dart';
import 'package:yolyoldasi/core/network/api_envelope.dart';
import 'package:yolyoldasi/core/theme/app_theme.dart';
import 'package:yolyoldasi/features/chat/domain/repositories/chat_repository.dart';
import 'package:yolyoldasi/features/notifications/domain/entities/app_notification.dart';
import 'package:yolyoldasi/features/notifications/domain/repositories/notification_repository.dart';
import 'package:yolyoldasi/features/notifications/presentation/pages/notifications_page.dart';
import 'package:yolyoldasi/features/profile/domain/entities/app_user.dart';
import 'package:yolyoldasi/features/shell/presentation/bloc/badges/badges_bloc.dart';

/// Every row in the notification centre says something under its title.
/// The types with no actor and no seat count — document review, reminders,
/// admin cancellations — used to leave that line empty.
void main() {
  final az = AppStrings.of('az');
  final now = DateTime.now();

  AppNotification item(
    int id,
    NotificationType type, {
    Map<String, dynamic> payload = const {},
    int? rideId,
  }) => AppNotification(
    id: id,
    type: type,
    createdAt: now,
    rideId: rideId,
    payload: payload,
  );

  Future<void> pump(WidgetTester tester, List<AppNotification> items) async {
    final badges = _MockBadgesBloc();
    whenListen(
      badges,
      const Stream<BadgesState>.empty(),
      initialState: const BadgesState(),
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<NotificationRepository>.value(
            value: _FakeNotificationRepository(items),
          ),
          // The list listens for threads read elsewhere; nothing is read here.
          RepositoryProvider<ChatRepository>.value(value: _QuietChat()),
        ],
        child: BlocProvider<BadgesBloc>.value(
          value: badges,
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('az'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const NotificationsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('approved documents say what the driver can do now', (
    tester,
  ) async {
    await pump(tester, [item(1, NotificationType.documentsApproved)]);

    expect(find.text(az.notifDocsApprovedTitle), findsOneWidget);
    expect(find.text(az.notifDocsApprovedBody), findsOneWidget);
  });

  testWidgets('rejected documents show the admin\'s reason', (tester) async {
    await pump(tester, [
      item(
        1,
        NotificationType.documentsRejected,
        payload: {'reason': 'Şəkil bulanıqdır'},
      ),
    ]);

    expect(
      find.text('${az.rejectionReason}: Şəkil bulanıqdır'),
      findsOneWidget,
    );
  });

  testWidgets('rejected documents without a reason still say what to do', (
    tester,
  ) async {
    await pump(tester, [item(1, NotificationType.documentsRejected)]);

    expect(find.text(az.verificationRejectedBody), findsOneWidget);
  });

  testWidgets('a reminder names the departure', (tester) async {
    final departure = DateTime(
      now.year,
      now.month,
      now.day,
      9,
      30,
    ).add(const Duration(days: 1));
    await pump(tester, [
      // A reminder always names its ride; without one the row would read as
      // a deleted link, which is a different case.
      item(
        1,
        NotificationType.rideReminder,
        payload: {'departure_at': departure.toIso8601String()},
        rideId: 7,
      ),
    ]);

    expect(find.textContaining('${az.departure}: '), findsOneWidget);
    expect(find.textContaining('09:30'), findsOneWidget);
  });

  testWidgets('an instant booking names who took the seat, and how many', (
    tester,
  ) async {
    // No case of its own in the subtitle: the actor and the seat count say it.
    // What it must not do is borrow the passenger's "booking confirmed" title.
    await pump(tester, [
      AppNotification(
        id: 1,
        type: NotificationType.bookingInstant,
        createdAt: now,
        rideId: 7,
        bookingId: 88,
        actor: const PublicUser(id: 5, fullName: 'Aysel Həsənova'),
        payload: const {'seats': 2},
      ),
    ]);

    expect(find.text(az.notifInstantBookingTitle), findsOneWidget);
    expect(find.text(az.notifBookingConfirmedTitle), findsNothing);
    expect(find.text('Aysel H. · ${az.seats(2)}'), findsOneWidget);
  });
}

class _MockBadgesBloc extends MockBloc<BadgesEvent, BadgesState>
    implements BadgesBloc {}

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository(this._items);

  final List<AppNotification> _items;

  @override
  FutureResult<Paginated<AppNotification>> list({
    bool unreadOnly = false,
    int? page,
  }) async => Ok(Paginated(items: _items, meta: PageMeta.single));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuietChat implements ChatRepository {
  @override
  Stream<int> get threadsRead => const Stream<int>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
