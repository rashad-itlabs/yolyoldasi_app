import '../constants/dial_codes.dart';

/// Phone numbers, for any country, with Azerbaijan as the default.
///
/// It used to assume `+994` everywhere: nine digits, checked against the local
/// operator prefixes. That is right for the market and wrong for everyone in
/// it who carries a foreign SIM — a Turkish driver on the Baku–Istanbul run,
/// a Georgian passenger, anyone visiting. They could not sign in at all.
///
/// Two rules keep the change honest:
///
///  * **Azerbaijan is still validated properly.** Nine digits, and the first
///    two have to be an operator prefix that exists. That is our market and we
///    know it, so a typo should be caught before the SMS is spent.
///  * **Nowhere else is guessed at.** Without libphonenumber's metadata any
///    per-country rule here would be invented, and an invented rule locks real
///    people out. Other countries get a permissive length range; the SMS
///    either arrives or it does not, and the user finds out one screen later.
abstract final class PhoneNumbers {
  /// Kept for the handful of call sites that only ever mean Azerbaijan.
  static const String countryCode = '+994';

  static Country get defaultCountry => Countries.azerbaijan;

  /// Mobile operator prefixes issued in Azerbaijan.
  static const Set<String> operatorCodes = {
    '50', '51', '55', '70', '77', // Azercell / Bakcell / Nar
    '99', '10', '60', // Naxtel, Azercell, Nar (newer ranges)
  };

  /// Loosest range we will accept for a country we have no rule for.
  ///
  /// The floor keeps obvious slips out; the ceiling is E.164's own limit of
  /// fifteen digits including the dial code.
  static const int _minNationalDigits = 5;
  static const int _maxNationalDigits = 14;

  /// Digits only, with the country's own trunk prefix and dial code removed.
  ///
  /// Accepts the shapes people actually paste: `0501234567`, `+994501234567`,
  /// `00994 50 123 45 67`, or the bare national number.
  static String? nationalDigits(String input, {Country? country}) {
    final dial = (country ?? defaultCountry).dialCode;
    var digits = input.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('00$dial')) {
      digits = digits.substring(2 + dial.length);
    } else if (digits.startsWith(dial)) {
      digits = digits.substring(dial.length);
    }

    // The national trunk prefix. Azerbaijan, Turkey, Russia and most of Europe
    // write it; stripping a leading zero is safe because no national number
    // begins with one.
    if (digits.startsWith('0')) digits = digits.substring(1);

    return digits.isEmpty ? null : digits;
  }

  /// Whether [input] is a complete, plausible number for [country].
  static bool isValid(String input, {Country? country}) {
    final target = country ?? defaultCountry;
    final digits = nationalDigits(input, country: target);
    if (digits == null) return false;

    final exact = target.nationalLength;
    if (exact != null) {
      if (digits.length != exact) return false;
      // Only Azerbaijan has an operator table worth checking against.
      if (target.iso == 'AZ') {
        return operatorCodes.contains(digits.substring(0, 2));
      }
      return true;
    }

    return digits.length >= _minNationalDigits &&
        digits.length <= _maxNationalDigits;
  }

  /// Canonical E.164, which is the storage key: `+994501234567`.
  static String? toE164(String input, {Country? country}) {
    final target = country ?? defaultCountry;
    if (!isValid(input, country: target)) return null;
    return '${target.prefix}${nationalDigits(input, country: target)}';
  }

  /// `+994 50 123 45 67` for a local number; `+90 555 123 45 67` for anything
  /// else, grouped from the right so the result stays readable without knowing
  /// the country's own convention.
  ///
  /// Falls back to the input untouched when it cannot be read as a number at
  /// all — showing the raw string beats showing a mangled one.
  static String format(String e164OrRaw) {
    final country = Countries.forE164(e164OrRaw);
    if (country == null) return e164OrRaw;

    final digits = nationalDigits(e164OrRaw, country: country);
    if (digits == null) return e164OrRaw;

    if (country.iso == 'AZ' && digits.length == 9) {
      return '${country.prefix} ${digits.substring(0, 2)} '
          '${digits.substring(2, 5)} ${digits.substring(5, 7)} '
          '${digits.substring(7, 9)}';
    }

    return '${country.prefix} ${_groupFromRight(digits)}';
  }

  /// `+994 50 ••• •• 67` — shown before a booking is confirmed, so the
  /// passenger can still recognise their own number without it leaking.
  static String masked(String e164OrRaw) {
    final country = Countries.forE164(e164OrRaw);
    final digits = country == null
        ? null
        : nationalDigits(e164OrRaw, country: country);

    if (country == null || digits == null || digits.length < 4) return '•••';

    final head = digits.substring(0, 2);
    final tail = digits.substring(digits.length - 2);
    final hidden = '•' * (digits.length - 4);

    return '${country.prefix} $head $hidden $tail';
  }

  /// Progressive formatting for the login field as the user types.
  ///
  /// Azerbaijani numbers keep their familiar `50 123 45 67` grouping; every
  /// other country is grouped in threes, which is wrong for some of them and
  /// unreadable for none.
  static String formatAsTyped(String input, {Country? country}) {
    final target = country ?? defaultCountry;
    final digits = nationalDigits(input, country: target) ?? '';
    final limit = target.nationalLength ?? _maxNationalDigits;
    final capped = digits.length > limit ? digits.substring(0, limit) : digits;

    if (target.iso == 'AZ') {
      final buffer = StringBuffer();
      for (var i = 0; i < capped.length; i++) {
        if (i == 2 || i == 5 || i == 7) buffer.write(' ');
        buffer.write(capped[i]);
      }
      return buffer.toString();
    }

    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(' ');
      buffer.write(capped[i]);
    }
    return buffer.toString();
  }

  /// Groups digits in threes from the right, so the last group is always full:
  /// `5551234567` → `5 551 234 567`.
  static String _groupFromRight(String digits) {
    final groups = <String>[];
    var end = digits.length;
    while (end > 3) {
      groups.insert(0, digits.substring(end - 3, end));
      end -= 3;
    }
    groups.insert(0, digits.substring(0, end));
    return groups.join(' ');
  }

  /// `tel:` URI for the dialer deep link.
  static Uri dialUri(String e164) => Uri(scheme: 'tel', path: e164);

  /// WhatsApp deep link — very widely used in Azerbaijan for trip logistics.
  static Uri whatsappUri(String e164) =>
      Uri.parse('https://wa.me/${e164.replaceAll('+', '')}');
}
