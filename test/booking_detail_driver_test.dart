import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/core/localization/app_localizations.dart';
import 'package:yolyoldasi/core/theme/app_theme.dart';
import 'package:yolyoldasi/core/utils/phone_number.dart';
import 'package:yolyoldasi/features/bookings/data/models/booking_model.dart';
import 'package:yolyoldasi/features/bookings/domain/entities/booking.dart';
import 'package:yolyoldasi/features/bookings/domain/repositories/booking_repository.dart';
import 'package:yolyoldasi/features/bookings/presentation/pages/booking_detail_page.dart';

/// Where an instant-booking notification leads the driver: a booking that is
/// already confirmed.
///
/// Every other way a driver reaches this screen from a notification starts at a
/// pending request, with confirm and reject in the bar. Here there is nothing
/// to decide, and the screen has to read as "someone is coming" instead.
void main() {
  final az = AppStrings.of('az');

  /// `GET /bookings/{id}` as the server answers the driver: the embedded ride
  /// is theirs, and a confirmed booking unlocks the passenger's number.
  Booking confirmedAsDriver() => BookingModel.fromJson({
    'id': 88,
    'ride': {
      'id': 7,
      'from_city': {'id': 1, 'name': 'Bakı'},
      'to_city': {'id': 9, 'name': 'Qəbələ'},
      'departure_at': DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String(),
      'total_seats': 4,
      'booked_seats': 2,
      'seats_left': 2,
      'price_per_seat': 15.0,
      'status': 'active',
      'instant_booking': true,
      'is_mine': true,
      'created_at': '2026-09-25T09:00:00+04:00',
    },
    'passenger': {'id': 5, 'full_name': 'Aysel Həsənova'},
    'driver': {'id': 42, 'full_name': 'Rəşad Məmmədov'},
    'seats': 2,
    'total_price': 30.0,
    'status': 'confirmed',
    'message': '',
    'decided_at': '2026-09-26T10:00:00+04:00',
    'passenger_reviewed': false,
    'driver_reviewed': false,
    'conversation_id': 14,
    'contact_phone': '+994501234567',
    'created_at': '2026-09-26T10:00:00+04:00',
  });

  testWidgets('the driver sees who is coming, their number and the thread', (
    tester,
  ) async {
    await tester.pumpWidget(
      RepositoryProvider<BookingRepository>.value(
        value: _FakeBookingRepository(confirmedAsDriver()),
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
          home: const BookingDetailPage(bookingId: 88),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(az.statusConfirmed), findsOneWidget);

    // The other side of the booking is the passenger, not the driver's own
    // profile — `is_mine` on the embedded ride is what decides that.
    expect(find.text(az.passenger), findsOneWidget);
    expect(find.text('Aysel H.'), findsOneWidget);
    expect(find.text(PhoneNumbers.format('+994501234567')), findsOneWidget);

    // Nothing left to decide; the way to reach the passenger and the way out
    // are what remain.
    expect(find.text(az.confirmBooking), findsNothing);
    expect(find.text(az.reject), findsNothing);
    expect(find.text(az.sendMessage), findsOneWidget);
    expect(find.text(az.cancelBooking), findsOneWidget);
  });
}

class _FakeBookingRepository implements BookingRepository {
  _FakeBookingRepository(this._booking);

  final Booking _booking;

  @override
  FutureResult<Booking> byId(int bookingId) async => Ok(_booking);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
