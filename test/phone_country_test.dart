import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/constants/dial_codes.dart';
import 'package:yolyoldasi/core/utils/phone_number.dart';

/// Sign-in used to accept Azerbaijani numbers and nothing else — nine digits,
/// checked against the local operator table. Anyone on a foreign SIM was shut
/// out of the product entirely.
///
/// These tests hold the two halves of the fix apart: Azerbaijan keeps its
/// strict rule, and nowhere else gets a rule we would have had to invent.
void main() {
  final turkey = Countries.byIso('TR');
  final georgia = Countries.byIso('GE');

  group('Azerbaijan stays strict', () {
    test('accepts every shape a local number is written in', () {
      for (final input in [
        '501234567',
        '0501234567',
        '+994501234567',
        '00994 50 123 45 67',
        '50 123 45 67',
      ]) {
        expect(
          PhoneNumbers.toE164(input),
          '+994501234567',
          reason: 'should read "$input" as the same number',
        );
      }
    });

    test('refuses a prefix no operator was ever issued', () {
      // 30 is not an Azerbaijani mobile range. Catching it here saves an SMS
      // and tells the user before they start waiting for one.
      expect(PhoneNumbers.isValid('301234567'), isFalse);
      expect(PhoneNumbers.isValid('501234567'), isTrue);
    });

    test('refuses the wrong length', () {
      expect(PhoneNumbers.isValid('5012345'), isFalse);
      expect(PhoneNumbers.isValid('5012345678'), isFalse);
    });
  });

  group('other countries', () {
    test('a Turkish number is valid under Turkey and not under Azerbaijan', () {
      const typed = '5551234567';

      expect(PhoneNumbers.isValid(typed, country: turkey), isTrue);
      expect(PhoneNumbers.toE164(typed, country: turkey), '+905551234567');

      // Ten digits, and `55` happens to be a real Azerbaijani prefix — the old
      // code would still have refused it on length, but under the wrong reason.
      expect(PhoneNumbers.isValid(typed), isFalse);
    });

    test('the trunk zero is stripped, not carried into E.164', () {
      // `+05551234567` is what the server used to store for this input, and it
      // is not a number anyone can be reached on.
      expect(
        PhoneNumbers.toE164('0555 123 45 67', country: turkey),
        '+905551234567',
      );
    });

    test('a nine-digit Georgian number does not become Azerbaijani', () {
      expect(
        PhoneNumbers.toE164('555123456', country: georgia),
        '+995555123456',
      );
    });

    test('no operator table is invented for a country we do not know', () {
      // Georgia has no `nationalLength`, so anything of a plausible length
      // passes. Guessing a rule here is how a real person gets locked out.
      expect(georgia.nationalLength, isNull);
      expect(PhoneNumbers.isValid('123456', country: georgia), isTrue);

      // The floor and the ceiling still hold.
      expect(PhoneNumbers.isValid('12', country: georgia), isFalse);
      expect(
        PhoneNumbers.isValid('123456789012345', country: georgia),
        isFalse,
      );
    });
  });

  group('display', () {
    test('formats a local number the way Azerbaijanis write it', () {
      expect(PhoneNumbers.format('+994501234567'), '+994 50 123 45 67');
    });

    test('formats a foreign number readably rather than not at all', () {
      // Grouped from the right — wrong for some countries' conventions, but a
      // wall of digits is wrong for all of them.
      expect(PhoneNumbers.format('+905551234567'), '+90 5 551 234 567');
    });

    test('masking keeps the two ends whatever the length', () {
      final masked = PhoneNumbers.masked('+905551234567');

      expect(masked, startsWith('+90 55'));
      expect(masked, endsWith('67'));
      expect(masked, contains('•'));
    });

    test('an unreadable number is shown as it came rather than mangled', () {
      expect(PhoneNumbers.format('not-a-number'), 'not-a-number');
    });
  });

  group('Countries', () {
    test('Azerbaijan is the default and the only strict one', () {
      expect(PhoneNumbers.defaultCountry.iso, 'AZ');
      expect(Countries.azerbaijan.nationalLength, 9);

      final strict = Countries.all.where((c) => c.nationalLength != null);
      expect(strict.map((c) => c.iso), ['AZ']);
    });

    test('every ISO code appears once', () {
      final seen = <String>{};
      for (final country in Countries.all) {
        expect(seen.add(country.iso), isTrue, reason: 'duplicate ${country.iso}');
      }
    });

    test('flags are derived from the ISO code, not stored', () {
      expect(Countries.byIso('AZ').flag, '🇦🇿');
      expect(Countries.byIso('TR').flag, '🇹🇷');
    });

    test('an E.164 number maps back to the longest matching dial code', () {
      // `+99450…` starts with `9` and `994`; the longer one has to win, or
      // every Azerbaijani number would be read as something else.
      expect(Countries.forE164('+994501234567')?.iso, 'AZ');
      expect(Countries.forE164('+995555123456')?.iso, 'GE');
    });

    test('an unknown ISO falls back to Azerbaijan rather than throwing', () {
      expect(Countries.byIso('ZZ').iso, 'AZ');
      expect(Countries.byIso(null).iso, 'AZ');
    });

    test('the pinned shortcuts all exist', () {
      for (final iso in Countries.pinned) {
        expect(
          Countries.all.any((country) => country.iso == iso),
          isTrue,
          reason: '$iso is pinned but not in the list',
        );
      }
    });
  });
}
