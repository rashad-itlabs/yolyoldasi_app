import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/localization/app_strings.dart';
import 'package:yolyoldasi/core/localization/strings_az.dart';
import 'package:yolyoldasi/core/localization/strings_en.dart';
import 'package:yolyoldasi/core/localization/strings_ru.dart';

void main() {
  group('string tables', () {
    test('every locale defines exactly the Azerbaijani key set', () {
      final expected = kStringsAz.keys.toSet();

      for (final entry in {'ru': kStringsRu, 'en': kStringsEn}.entries) {
        final actual = entry.value.keys.toSet();
        expect(
          actual.difference(expected),
          isEmpty,
          reason: '${entry.key} has keys that az does not',
        );
        expect(
          expected.difference(actual),
          isEmpty,
          reason: '${entry.key} is missing keys',
        );
      }
    });

    test('no value is left empty', () {
      for (final entry in {
        'az': kStringsAz,
        'ru': kStringsRu,
        'en': kStringsEn,
      }.entries) {
        for (final pair in entry.value.entries) {
          expect(
            pair.value.trim(),
            isNotEmpty,
            reason: '${entry.key}.${pair.key} is empty',
          );
        }
      }
    });
  });

  group('AppStrings', () {
    test('falls back to Azerbaijani for an unknown locale', () {
      final strings = AppStrings.of('de');
      expect(strings.languageCode, 'az');
      expect(strings.appName, kStringsAz['appName']);
    });

    test('parameterised strings actually interpolate', () {
      // A literal `$name` shipped to users once; a generator escaping bug is
      // invisible to the analyzer, so assert on the rendered output.
      for (final code in ['az', 'ru', 'en']) {
        final s = AppStrings.of(code);
        final rendered = <String>[
          s.greeting('Nigar'),
          s.stepOf(2, 3),
          s.priceAzn('15'),
          s.resendCountdown('00:42'),
          s.routeLabel('Bakı', 'Gəncə'),
          s.memberSinceValue('sentyabr 2025'),
          s.rateWithName('Rəşad'),
          s.documentsApprovedCount(2, 4),
          s.bookingRequestBody('Aysel', 2),
        ];

        for (final value in rendered) {
          expect(
            value,
            isNot(contains(r'$')),
            reason: '$code: "$value" contains an un-interpolated placeholder',
          );
        }

        expect(s.greeting('Nigar'), contains('Nigar'));
        expect(s.stepOf(2, 3), allOf(contains('2'), contains('3')));
        expect(s.routeLabel('Bakı', 'Gəncə'), 'Bakı → Gəncə');
        expect(s.documentsApprovedCount(2, 4), '2/4');
        expect(s.bookingRequestBody('Aysel', 2), contains('Aysel'));
      }
    });

    test('pluralises seats per locale', () {
      expect(AppStrings.of('az').seats(3), '3 yer');
      expect(AppStrings.of('en').seats(1), '1 seat');
      expect(AppStrings.of('en').seats(2), '2 seats');
      expect(AppStrings.of('ru').seats(1), '1 место');
      expect(AppStrings.of('ru').seats(3), '3 места');
      expect(AppStrings.of('ru').seats(5), '5 мест');
      expect(AppStrings.of('ru').seats(11), '11 мест');
      expect(AppStrings.of('ru').seats(21), '21 место');
    });
  });
}
