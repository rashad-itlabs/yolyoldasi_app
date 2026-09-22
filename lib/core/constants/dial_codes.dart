/// Dialling codes, so the sign-in screen is not limited to one country.
///
/// Hand-written rather than pulled from a package: the alternative is a
/// libphonenumber binding, which is megabytes of metadata and a platform
/// channel for what is, on this screen, a prefix and a length check.
///
/// **What this table does not do is validate.** Only Azerbaijan gets a real
/// rule ([Country.nationalLength]); everywhere else falls back to a permissive
/// range. That is deliberate — a wrong "invalid number" message stops a real
/// person from signing up, while a wrong-but-plausible number simply never
/// receives its SMS, which the user finds out one screen later and can fix.
library;

/// One country's dialling data.
class Country {
  const Country({
    required this.iso,
    required this.dialCode,
    required this.name,
    this.nationalLength,
  });

  /// ISO 3166-1 alpha-2, e.g. `AZ`. Also what the flag is derived from.
  final String iso;

  /// Without the `+`, e.g. `994`. Not unique — every NANP country is `1`.
  final String dialCode;

  /// English, and on purpose: translating two hundred country names into three
  /// locales is a lot of surface for a list people search by flag and code.
  final String name;

  /// Exactly how many digits the national part has, where we are sure.
  ///
  /// Null means "we do not know", and the field is null for every country but
  /// ours. Guessing here is how you lock a real user out.
  final int? nationalLength;

  /// The flag, built from the ISO code rather than stored.
  ///
  /// Regional indicator symbols are laid out so that `A` maps to U+1F1E6, so
  /// two letters become a flag with arithmetic — no emoji column to mistype.
  String get flag => String.fromCharCodes(
    iso.codeUnits.map((unit) => 0x1F1E6 + unit - 0x41),
  );

  String get prefix => '+$dialCode';

  /// Lowercased haystack for the picker's search box: name, code and dial code
  /// all match, because people reach for whichever they remember.
  String get searchHaystack => '${name.toLowerCase()} ${iso.toLowerCase()} $dialCode';

  @override
  String toString() => '$prefix ($iso)';
}

/// Every country the sign-in screen offers, sorted by name.
abstract final class Countries {
  /// The default, and the only one with a strict length rule.
  static const Country azerbaijan = Country(
    iso: 'AZ',
    dialCode: '994',
    name: 'Azerbaijan',
    nationalLength: 9,
  );

  /// Shown above the rest in the picker — the routes this app exists for.
  static const List<String> pinned = ['AZ', 'TR', 'RU', 'GE', 'IR'];

  static const List<Country> all = <Country>[
    Country(iso: 'AF', dialCode: '93', name: 'Afghanistan'),
    Country(iso: 'AL', dialCode: '355', name: 'Albania'),
    Country(iso: 'DZ', dialCode: '213', name: 'Algeria'),
    Country(iso: 'AD', dialCode: '376', name: 'Andorra'),
    Country(iso: 'AO', dialCode: '244', name: 'Angola'),
    Country(iso: 'AR', dialCode: '54', name: 'Argentina'),
    Country(iso: 'AM', dialCode: '374', name: 'Armenia'),
    Country(iso: 'AU', dialCode: '61', name: 'Australia'),
    Country(iso: 'AT', dialCode: '43', name: 'Austria'),
    // The same instance as [azerbaijan], not a second one with the same code.
    // Two copies meant `byIso('AZ')` returned the one without the length rule,
    // so picking Azerbaijan from the list quietly turned its validation off.
    azerbaijan,
    Country(iso: 'BH', dialCode: '973', name: 'Bahrain'),
    Country(iso: 'BD', dialCode: '880', name: 'Bangladesh'),
    Country(iso: 'BY', dialCode: '375', name: 'Belarus'),
    Country(iso: 'BE', dialCode: '32', name: 'Belgium'),
    Country(iso: 'BJ', dialCode: '229', name: 'Benin'),
    Country(iso: 'BT', dialCode: '975', name: 'Bhutan'),
    Country(iso: 'BO', dialCode: '591', name: 'Bolivia'),
    Country(iso: 'BA', dialCode: '387', name: 'Bosnia and Herzegovina'),
    Country(iso: 'BW', dialCode: '267', name: 'Botswana'),
    Country(iso: 'BR', dialCode: '55', name: 'Brazil'),
    Country(iso: 'BN', dialCode: '673', name: 'Brunei'),
    Country(iso: 'BG', dialCode: '359', name: 'Bulgaria'),
    Country(iso: 'BF', dialCode: '226', name: 'Burkina Faso'),
    Country(iso: 'BI', dialCode: '257', name: 'Burundi'),
    Country(iso: 'KH', dialCode: '855', name: 'Cambodia'),
    Country(iso: 'CM', dialCode: '237', name: 'Cameroon'),
    Country(iso: 'CA', dialCode: '1', name: 'Canada'),
    Country(iso: 'CV', dialCode: '238', name: 'Cape Verde'),
    Country(iso: 'TD', dialCode: '235', name: 'Chad'),
    Country(iso: 'CL', dialCode: '56', name: 'Chile'),
    Country(iso: 'CN', dialCode: '86', name: 'China'),
    Country(iso: 'CO', dialCode: '57', name: 'Colombia'),
    Country(iso: 'CG', dialCode: '242', name: 'Congo'),
    Country(iso: 'CR', dialCode: '506', name: 'Costa Rica'),
    Country(iso: 'HR', dialCode: '385', name: 'Croatia'),
    Country(iso: 'CU', dialCode: '53', name: 'Cuba'),
    Country(iso: 'CY', dialCode: '357', name: 'Cyprus'),
    Country(iso: 'CZ', dialCode: '420', name: 'Czechia'),
    Country(iso: 'CD', dialCode: '243', name: 'DR Congo'),
    Country(iso: 'DK', dialCode: '45', name: 'Denmark'),
    Country(iso: 'DJ', dialCode: '253', name: 'Djibouti'),
    Country(iso: 'DO', dialCode: '1', name: 'Dominican Republic'),
    Country(iso: 'EC', dialCode: '593', name: 'Ecuador'),
    Country(iso: 'EG', dialCode: '20', name: 'Egypt'),
    Country(iso: 'SV', dialCode: '503', name: 'El Salvador'),
    Country(iso: 'ER', dialCode: '291', name: 'Eritrea'),
    Country(iso: 'EE', dialCode: '372', name: 'Estonia'),
    Country(iso: 'SZ', dialCode: '268', name: 'Eswatini'),
    Country(iso: 'ET', dialCode: '251', name: 'Ethiopia'),
    Country(iso: 'FO', dialCode: '298', name: 'Faroe Islands'),
    Country(iso: 'FJ', dialCode: '679', name: 'Fiji'),
    Country(iso: 'FI', dialCode: '358', name: 'Finland'),
    Country(iso: 'FR', dialCode: '33', name: 'France'),
    Country(iso: 'GA', dialCode: '241', name: 'Gabon'),
    Country(iso: 'GM', dialCode: '220', name: 'Gambia'),
    Country(iso: 'GE', dialCode: '995', name: 'Georgia'),
    Country(iso: 'DE', dialCode: '49', name: 'Germany'),
    Country(iso: 'GH', dialCode: '233', name: 'Ghana'),
    Country(iso: 'GI', dialCode: '350', name: 'Gibraltar'),
    Country(iso: 'GR', dialCode: '30', name: 'Greece'),
    Country(iso: 'GT', dialCode: '502', name: 'Guatemala'),
    Country(iso: 'GN', dialCode: '224', name: 'Guinea'),
    Country(iso: 'HT', dialCode: '509', name: 'Haiti'),
    Country(iso: 'HN', dialCode: '504', name: 'Honduras'),
    Country(iso: 'HK', dialCode: '852', name: 'Hong Kong'),
    Country(iso: 'HU', dialCode: '36', name: 'Hungary'),
    Country(iso: 'IS', dialCode: '354', name: 'Iceland'),
    Country(iso: 'IN', dialCode: '91', name: 'India'),
    Country(iso: 'ID', dialCode: '62', name: 'Indonesia'),
    Country(iso: 'IR', dialCode: '98', name: 'Iran'),
    Country(iso: 'IQ', dialCode: '964', name: 'Iraq'),
    Country(iso: 'IE', dialCode: '353', name: 'Ireland'),
    Country(iso: 'IL', dialCode: '972', name: 'Israel'),
    Country(iso: 'IT', dialCode: '39', name: 'Italy'),
    Country(iso: 'CI', dialCode: '225', name: 'Ivory Coast'),
    Country(iso: 'JM', dialCode: '1', name: 'Jamaica'),
    Country(iso: 'JP', dialCode: '81', name: 'Japan'),
    Country(iso: 'JO', dialCode: '962', name: 'Jordan'),
    Country(iso: 'KZ', dialCode: '7', name: 'Kazakhstan'),
    Country(iso: 'KE', dialCode: '254', name: 'Kenya'),
    Country(iso: 'XK', dialCode: '383', name: 'Kosovo'),
    Country(iso: 'KW', dialCode: '965', name: 'Kuwait'),
    Country(iso: 'KG', dialCode: '996', name: 'Kyrgyzstan'),
    Country(iso: 'LA', dialCode: '856', name: 'Laos'),
    Country(iso: 'LV', dialCode: '371', name: 'Latvia'),
    Country(iso: 'LB', dialCode: '961', name: 'Lebanon'),
    Country(iso: 'LS', dialCode: '266', name: 'Lesotho'),
    Country(iso: 'LR', dialCode: '231', name: 'Liberia'),
    Country(iso: 'LY', dialCode: '218', name: 'Libya'),
    Country(iso: 'LI', dialCode: '423', name: 'Liechtenstein'),
    Country(iso: 'LT', dialCode: '370', name: 'Lithuania'),
    Country(iso: 'LU', dialCode: '352', name: 'Luxembourg'),
    Country(iso: 'MO', dialCode: '853', name: 'Macao'),
    Country(iso: 'MG', dialCode: '261', name: 'Madagascar'),
    Country(iso: 'MW', dialCode: '265', name: 'Malawi'),
    Country(iso: 'MY', dialCode: '60', name: 'Malaysia'),
    Country(iso: 'MV', dialCode: '960', name: 'Maldives'),
    Country(iso: 'ML', dialCode: '223', name: 'Mali'),
    Country(iso: 'MT', dialCode: '356', name: 'Malta'),
    Country(iso: 'MR', dialCode: '222', name: 'Mauritania'),
    Country(iso: 'MU', dialCode: '230', name: 'Mauritius'),
    Country(iso: 'MX', dialCode: '52', name: 'Mexico'),
    Country(iso: 'MD', dialCode: '373', name: 'Moldova'),
    Country(iso: 'MC', dialCode: '377', name: 'Monaco'),
    Country(iso: 'MN', dialCode: '976', name: 'Mongolia'),
    Country(iso: 'ME', dialCode: '382', name: 'Montenegro'),
    Country(iso: 'MA', dialCode: '212', name: 'Morocco'),
    Country(iso: 'MZ', dialCode: '258', name: 'Mozambique'),
    Country(iso: 'MM', dialCode: '95', name: 'Myanmar'),
    Country(iso: 'NA', dialCode: '264', name: 'Namibia'),
    Country(iso: 'NP', dialCode: '977', name: 'Nepal'),
    Country(iso: 'NL', dialCode: '31', name: 'Netherlands'),
    Country(iso: 'NZ', dialCode: '64', name: 'New Zealand'),
    Country(iso: 'NI', dialCode: '505', name: 'Nicaragua'),
    Country(iso: 'NE', dialCode: '227', name: 'Niger'),
    Country(iso: 'NG', dialCode: '234', name: 'Nigeria'),
    Country(iso: 'MK', dialCode: '389', name: 'North Macedonia'),
    Country(iso: 'NO', dialCode: '47', name: 'Norway'),
    Country(iso: 'OM', dialCode: '968', name: 'Oman'),
    Country(iso: 'PK', dialCode: '92', name: 'Pakistan'),
    Country(iso: 'PS', dialCode: '970', name: 'Palestine'),
    Country(iso: 'PA', dialCode: '507', name: 'Panama'),
    Country(iso: 'PG', dialCode: '675', name: 'Papua New Guinea'),
    Country(iso: 'PY', dialCode: '595', name: 'Paraguay'),
    Country(iso: 'PE', dialCode: '51', name: 'Peru'),
    Country(iso: 'PH', dialCode: '63', name: 'Philippines'),
    Country(iso: 'PL', dialCode: '48', name: 'Poland'),
    Country(iso: 'PT', dialCode: '351', name: 'Portugal'),
    Country(iso: 'PR', dialCode: '1', name: 'Puerto Rico'),
    Country(iso: 'QA', dialCode: '974', name: 'Qatar'),
    Country(iso: 'RO', dialCode: '40', name: 'Romania'),
    Country(iso: 'RU', dialCode: '7', name: 'Russia'),
    Country(iso: 'RW', dialCode: '250', name: 'Rwanda'),
    Country(iso: 'WS', dialCode: '685', name: 'Samoa'),
    Country(iso: 'SM', dialCode: '378', name: 'San Marino'),
    Country(iso: 'SA', dialCode: '966', name: 'Saudi Arabia'),
    Country(iso: 'SN', dialCode: '221', name: 'Senegal'),
    Country(iso: 'RS', dialCode: '381', name: 'Serbia'),
    Country(iso: 'SC', dialCode: '248', name: 'Seychelles'),
    Country(iso: 'SL', dialCode: '232', name: 'Sierra Leone'),
    Country(iso: 'SG', dialCode: '65', name: 'Singapore'),
    Country(iso: 'SK', dialCode: '421', name: 'Slovakia'),
    Country(iso: 'SI', dialCode: '386', name: 'Slovenia'),
    Country(iso: 'SB', dialCode: '677', name: 'Solomon Islands'),
    Country(iso: 'SO', dialCode: '252', name: 'Somalia'),
    Country(iso: 'ZA', dialCode: '27', name: 'South Africa'),
    Country(iso: 'KR', dialCode: '82', name: 'South Korea'),
    Country(iso: 'SS', dialCode: '211', name: 'South Sudan'),
    Country(iso: 'ES', dialCode: '34', name: 'Spain'),
    Country(iso: 'LK', dialCode: '94', name: 'Sri Lanka'),
    Country(iso: 'SD', dialCode: '249', name: 'Sudan'),
    Country(iso: 'SE', dialCode: '46', name: 'Sweden'),
    Country(iso: 'CH', dialCode: '41', name: 'Switzerland'),
    Country(iso: 'SY', dialCode: '963', name: 'Syria'),
    Country(iso: 'TW', dialCode: '886', name: 'Taiwan'),
    Country(iso: 'TJ', dialCode: '992', name: 'Tajikistan'),
    Country(iso: 'TZ', dialCode: '255', name: 'Tanzania'),
    Country(iso: 'TH', dialCode: '66', name: 'Thailand'),
    Country(iso: 'TG', dialCode: '228', name: 'Togo'),
    Country(iso: 'TO', dialCode: '676', name: 'Tonga'),
    Country(iso: 'TN', dialCode: '216', name: 'Tunisia'),
    Country(iso: 'TR', dialCode: '90', name: 'Turkey'),
    Country(iso: 'TM', dialCode: '993', name: 'Turkmenistan'),
    Country(iso: 'UG', dialCode: '256', name: 'Uganda'),
    Country(iso: 'UA', dialCode: '380', name: 'Ukraine'),
    Country(iso: 'AE', dialCode: '971', name: 'United Arab Emirates'),
    Country(iso: 'GB', dialCode: '44', name: 'United Kingdom'),
    Country(iso: 'US', dialCode: '1', name: 'United States'),
    Country(iso: 'UY', dialCode: '598', name: 'Uruguay'),
    Country(iso: 'UZ', dialCode: '998', name: 'Uzbekistan'),
    Country(iso: 'VU', dialCode: '678', name: 'Vanuatu'),
    Country(iso: 'VE', dialCode: '58', name: 'Venezuela'),
    Country(iso: 'VN', dialCode: '84', name: 'Vietnam'),
    Country(iso: 'YE', dialCode: '967', name: 'Yemen'),
    Country(iso: 'ZM', dialCode: '260', name: 'Zambia'),
    Country(iso: 'ZW', dialCode: '263', name: 'Zimbabwe'),
  ];

  /// Lookup by ISO code; falls back to [azerbaijan].
  static Country byIso(String? iso) {
    if (iso == null) return azerbaijan;
    final upper = iso.toUpperCase();
    for (final country in all) {
      if (country.iso == upper) return country;
    }
    return azerbaijan;
  }

  /// The country an E.164 number belongs to, by longest matching dial code.
  ///
  /// Ambiguous for `+1`, where a dozen countries share the code — the first
  /// match wins, which is fine for the two things this is used for: picking
  /// the initial flag and choosing how to group the digits.
  static Country? forE164(String e164) {
    final digits = e164.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    Country? best;
    for (final country in all) {
      if (!digits.startsWith(country.dialCode)) continue;
      if (best == null || country.dialCode.length > best.dialCode.length) {
        best = country;
      }
    }
    return best;
  }
}
