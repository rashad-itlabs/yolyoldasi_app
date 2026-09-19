/// Helpers for Azerbaijani mobile numbers (+994 XX XXX XX XX).
abstract final class PhoneNumbers {
  static const String countryCode = '+994';

  /// Mobile operator prefixes issued in Azerbaijan.
  static const Set<String> operatorCodes = {
    '50', '51', '55', '70', '77', // Azercell / Bakcell / Nar
    '99', '10', '60', // Naxtel, Azercell, Nar (newer ranges)
  };

  /// Strips everything but digits and returns the 9-digit national number,
  /// or `null` when the input cannot be a local mobile number.
  static String? nationalDigits(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00994')) digits = digits.substring(5);
    if (digits.startsWith('994')) digits = digits.substring(3);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return digits.isEmpty ? null : digits;
  }

  /// `true` when [input] is a complete, plausible Azerbaijani mobile number.
  static bool isValid(String input) {
    final digits = nationalDigits(input);
    if (digits == null || digits.length != 9) return false;
    return operatorCodes.contains(digits.substring(0, 2));
  }

  /// Canonical E.164 form used as the storage key: `+994501234567`.
  static String? toE164(String input) {
    if (!isValid(input)) return null;
    return '$countryCode${nationalDigits(input)}';
  }

  /// `+994 50 123 45 67` — used wherever the full number is shown.
  static String format(String e164OrRaw) {
    final digits = nationalDigits(e164OrRaw);
    if (digits == null || digits.length != 9) return e164OrRaw;
    return '$countryCode ${digits.substring(0, 2)} ${digits.substring(2, 5)} '
        '${digits.substring(5, 7)} ${digits.substring(7, 9)}';
  }

  /// `+994 50 *** ** 67` — shown before a booking is confirmed, so the
  /// passenger can still recognise their own number without leaking it.
  static String masked(String e164OrRaw) {
    final digits = nationalDigits(e164OrRaw);
    if (digits == null || digits.length != 9) return '•••';
    return '$countryCode ${digits.substring(0, 2)} ••• •• ${digits.substring(7, 9)}';
  }

  /// Progressive formatting for the login field as the user types:
  /// `50 123 45 67`.
  static String formatAsTyped(String input) {
    final digits = (nationalDigits(input) ?? '').padRight(0);
    final capped = digits.length > 9 ? digits.substring(0, 9) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 2 || i == 5 || i == 7) buffer.write(' ');
      buffer.write(capped[i]);
    }
    return buffer.toString();
  }

  /// `tel:` URI for the dialer deep link.
  static Uri dialUri(String e164) => Uri(scheme: 'tel', path: e164);

  /// WhatsApp deep link — very widely used in Azerbaijan for trip logistics.
  static Uri whatsappUri(String e164) =>
      Uri.parse('https://wa.me/${e164.replaceAll('+', '')}');
}
