import 'package:intl/intl.dart';

import '../localization/app_strings.dart';

/// Locale-aware formatting for dates, money, durations and ratings.
///
/// Reach for it through `context.fmt` rather than constructing it per widget.
class AppFormat {
  const AppFormat(this.strings);

  final AppStrings strings;

  String get _locale => strings.languageCode;

  // ----------------------------------------------------------------- dates
  /// `12 sentyabr` / `12 сентября` / `12 September`
  String dayMonth(DateTime date) => DateFormat('d MMMM', _locale).format(date);

  /// `12 sen` — compact form for dense list rows.
  String dayMonthShort(DateTime date) =>
      DateFormat('d MMM', _locale).format(date);

  /// `12 sentyabr 2026`
  String fullDate(DateTime date) =>
      DateFormat('d MMMM y', _locale).format(date);

  /// `sentyabr 2026` — month pickers and "member since".
  String monthYear(DateTime date) => DateFormat('MMMM y', _locale).format(date);

  /// `Ç.a` / `Пн` / `Mon`
  String weekdayShort(DateTime date) => DateFormat('E', _locale).format(date);

  /// 24-hour clock — the norm in Azerbaijan.
  String time(DateTime date) => DateFormat('HH:mm', _locale).format(date);

  /// "Bu gün", "Sabah", "Dünən" or the date. Used on every ride card.
  String dayLabel(DateTime date) {
    final today = _dateOnly(DateTime.now());
    final target = _dateOnly(date);
    final diff = target.difference(today).inDays;
    return switch (diff) {
      0 => strings.today,
      1 => strings.tomorrow,
      -1 => strings.yesterday,
      _ => dayMonth(date),
    };
  }

  /// "Sabah, 09:00" — the primary departure line.
  String dayLabelWithTime(DateTime date) => '${dayLabel(date)}, ${time(date)}';

  /// "Bu gün · 14:30" with a mid-dot, for tighter headers.
  String dayDotTime(DateTime date) => '${dayLabel(date)} · ${time(date)}';

  // ------------------------------------------------------------- durations
  /// `4 s 20 dəq` — estimated trip length.
  String duration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final (h, m) = switch (_locale) {
      'ru' => ('ч', 'мин'),
      'en' => ('h', 'min'),
      _ => ('s', 'dəq'),
    };
    if (hours == 0) return '$minutes $m';
    if (minutes == 0) return '$hours $h';
    return '$hours $h $minutes $m';
  }

  /// `01:23` — OTP resend countdown. Always two digits so it never jitters.
  String countdown(Duration d) {
    final total = d.isNegative ? Duration.zero : d;
    final minutes = total.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = total.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// "5 dəq əvvəl", "2 saat əvvəl", "12 sen" — chat and notification stamps.
  String relative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds.abs() < 60) return strings.now;

    final (min, hour, day) = switch (_locale) {
      'ru' => ('мин назад', 'ч назад', 'д назад'),
      'en' => ('min ago', 'h ago', 'd ago'),
      _ => ('dəq əvvəl', 'saat əvvəl', 'gün əvvəl'),
    };
    if (diff.inMinutes < 60) return '${diff.inMinutes} $min';
    if (diff.inHours < 24) return '${diff.inHours} $hour';
    if (diff.inDays < 7) return '${diff.inDays} $day';
    return dayMonthShort(date);
  }

  // ----------------------------------------------------------------- money
  /// `15 AZN` / `15,50 AZN` — trailing `,00` is dropped because prices in the
  /// app are almost always whole manats.
  String price(num amount) => '${priceValue(amount)} ${strings.currency}';

  /// Just the number, for layouts that place the currency separately.
  String priceValue(num amount) {
    final isWhole = amount == amount.roundToDouble();
    final pattern = isWhole ? '#,##0' : '#,##0.00';
    return NumberFormat(pattern, _locale).format(amount);
  }

  // ---------------------------------------------------------------- rating
  /// `4.8`, or a dash when the user has no ratings yet.
  String rating(double? value) =>
      value == null || value <= 0 ? '—' : value.toStringAsFixed(1);

  /// Word for a star value, shown under the star picker.
  String ratingWord(int stars) => switch (stars) {
    1 => strings.ratingPoor,
    2 => strings.ratingFair,
    3 => strings.ratingGood,
    4 => strings.ratingVeryGood,
    5 => strings.ratingExcellent,
    _ => '',
  };

  // ------------------------------------------------------------------ misc
  /// "R.Ə." — initials for the avatar fallback.
  String initials(String? fullName) {
    final parts = (fullName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters(1).toUpperCase();
    return (parts.first.characters(1) + parts[1].characters(1)).toUpperCase();
  }

  /// "Rəşad Ə." — surname is shortened everywhere a stranger sees the name.
  String shortName(String? fullName) {
    final parts = (fullName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return strings.anonymous;
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts[1].characters(1).toUpperCase()}.';
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

extension on String {
  String characters(int count) =>
      runes.length <= count ? this : String.fromCharCodes(runes.take(count));
}
