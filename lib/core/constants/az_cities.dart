import 'dart:math' as math;

/// A city / district centre in Azerbaijan.
///
/// The API is the authority on which cities exist and what their ids are
/// (`GET /cities`), and it returns Azerbaijani names only. This table is the
/// local companion to that list: it supplies the Russian and English names for
/// the picker and the coordinates the price hint and the arrival estimate need,
/// neither of which the API exposes. Rows are matched to API cities by name,
/// via [AzCities.byName], so [id] never has to agree with a server id.
class AzCity {
  const AzCity({
    required this.id,
    required this.az,
    required this.ru,
    required this.en,
    required this.lat,
    required this.lng,
    this.isPopular = false,
  });

  final String id;
  final String az;
  final String ru;
  final String en;
  final double lat;
  final double lng;

  /// Surfaced first in the picker and on the search home screen.
  final bool isPopular;

  String nameFor(String languageCode) => switch (languageCode) {
    'ru' => ru,
    'en' => en,
    _ => az,
  };

  /// Lowercased, diacritic-free haystack used by the city search field so that
  /// "gence", "gəncə" and "Гянджа" all match.
  String searchHaystack(String languageCode) =>
      '${_fold(az)} ${_fold(ru)} ${_fold(en)} ${_fold(nameFor(languageCode))}';

  static String _fold(String input) {
    const map = {
      'ə': 'e',
      'Ə': 'e',
      'ğ': 'g',
      'Ğ': 'g',
      'ı': 'i',
      'I': 'i',
      'İ': 'i',
      'ö': 'o',
      'Ö': 'o',
      'ü': 'u',
      'Ü': 'u',
      'ç': 'c',
      'Ç': 'c',
      'ş': 's',
      'Ş': 's',
    };
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(map[ch] ?? ch.toLowerCase());
    }
    return buffer.toString();
  }

  /// Normalises a user query the same way [searchHaystack] normalises names.
  static String foldQuery(String input) => _fold(input.trim());

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AzCity && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Every city and district centre the app knows about.
abstract final class AzCities {
  static const List<AzCity> all = <AzCity>[
    AzCity(
      id: 'baku',
      az: 'Bakı',
      ru: 'Баку',
      en: 'Baku',
      lat: 40.4093,
      lng: 49.8671,
      isPopular: true,
    ),
    AzCity(
      id: 'ganja',
      az: 'Gəncə',
      ru: 'Гянджа',
      en: 'Ganja',
      lat: 40.6828,
      lng: 46.3606,
      isPopular: true,
    ),
    AzCity(
      id: 'sumqayit',
      az: 'Sumqayıt',
      ru: 'Сумгаит',
      en: 'Sumqayit',
      lat: 40.5897,
      lng: 49.6686,
      isPopular: true,
    ),
    AzCity(
      id: 'mingachevir',
      az: 'Mingəçevir',
      ru: 'Мингечевир',
      en: 'Mingachevir',
      lat: 40.7700,
      lng: 47.0489,
      isPopular: true,
    ),
    AzCity(
      id: 'lankaran',
      az: 'Lənkəran',
      ru: 'Лянкяран',
      en: 'Lankaran',
      lat: 38.7529,
      lng: 48.8475,
      isPopular: true,
    ),
    AzCity(
      id: 'sheki',
      az: 'Şəki',
      ru: 'Шеки',
      en: 'Sheki',
      lat: 41.1919,
      lng: 47.1706,
      isPopular: true,
    ),
    AzCity(
      id: 'qabala',
      az: 'Qəbələ',
      ru: 'Габала',
      en: 'Gabala',
      lat: 40.9814,
      lng: 47.8481,
      isPopular: true,
    ),
    AzCity(
      id: 'quba',
      az: 'Quba',
      ru: 'Губа',
      en: 'Quba',
      lat: 41.3606,
      lng: 48.5128,
      isPopular: true,
    ),
    AzCity(
      id: 'naxcivan',
      az: 'Naxçıvan',
      ru: 'Нахчыван',
      en: 'Nakhchivan',
      lat: 39.2090,
      lng: 45.4122,
      isPopular: true,
    ),
    AzCity(
      id: 'shirvan',
      az: 'Şirvan',
      ru: 'Ширван',
      en: 'Shirvan',
      lat: 39.9308,
      lng: 48.9292,
      isPopular: true,
    ),
    AzCity(
      id: 'yevlax',
      az: 'Yevlax',
      ru: 'Евлах',
      en: 'Yevlakh',
      lat: 40.6172,
      lng: 47.1500,
      isPopular: true,
    ),
    AzCity(
      id: 'shamakhi',
      az: 'Şamaxı',
      ru: 'Шемаха',
      en: 'Shamakhi',
      lat: 40.6319,
      lng: 48.6417,
      isPopular: true,
    ),

    AzCity(
      id: 'xirdalan',
      az: 'Xırdalan',
      ru: 'Хырдалан',
      en: 'Khirdalan',
      lat: 40.4536,
      lng: 49.7553,
    ),
    AzCity(
      id: 'agdam',
      az: 'Ağdam',
      ru: 'Агдам',
      en: 'Aghdam',
      lat: 39.9910,
      lng: 46.9295,
    ),
    AzCity(
      id: 'agdash',
      az: 'Ağdaş',
      ru: 'Агдаш',
      en: 'Aghdash',
      lat: 40.6500,
      lng: 47.4747,
    ),
    AzCity(
      id: 'agjabadi',
      az: 'Ağcabədi',
      ru: 'Агджабеди',
      en: 'Aghjabadi',
      lat: 40.0531,
      lng: 47.4597,
    ),
    AzCity(
      id: 'agstafa',
      az: 'Ağstafa',
      ru: 'Агстафа',
      en: 'Aghstafa',
      lat: 41.1194,
      lng: 45.4536,
    ),
    AzCity(
      id: 'agsu',
      az: 'Ağsu',
      ru: 'Агсу',
      en: 'Aghsu',
      lat: 40.5717,
      lng: 48.4022,
    ),
    AzCity(
      id: 'astara',
      az: 'Astara',
      ru: 'Астара',
      en: 'Astara',
      lat: 38.4558,
      lng: 48.8747,
    ),
    AzCity(
      id: 'babek',
      az: 'Babək',
      ru: 'Бабек',
      en: 'Babek',
      lat: 39.1522,
      lng: 45.4472,
    ),
    AzCity(
      id: 'balakan',
      az: 'Balakən',
      ru: 'Балакен',
      en: 'Balakan',
      lat: 41.7264,
      lng: 46.4053,
    ),
    AzCity(
      id: 'barda',
      az: 'Bərdə',
      ru: 'Барда',
      en: 'Barda',
      lat: 40.3744,
      lng: 47.1264,
    ),
    AzCity(
      id: 'beylagan',
      az: 'Beyləqan',
      ru: 'Бейлаган',
      en: 'Beylagan',
      lat: 39.7728,
      lng: 47.6156,
    ),
    AzCity(
      id: 'bilasuvar',
      az: 'Biləsuvar',
      ru: 'Билясувар',
      en: 'Bilasuvar',
      lat: 39.4597,
      lng: 48.5497,
    ),
    AzCity(
      id: 'jabrayil',
      az: 'Cəbrayıl',
      ru: 'Джебраил',
      en: 'Jabrayil',
      lat: 39.3989,
      lng: 47.0258,
    ),
    AzCity(
      id: 'jalilabad',
      az: 'Cəlilabad',
      ru: 'Джалилабад',
      en: 'Jalilabad',
      lat: 39.2058,
      lng: 48.5072,
    ),
    AzCity(
      id: 'julfa',
      az: 'Culfa',
      ru: 'Джульфа',
      en: 'Julfa',
      lat: 38.9542,
      lng: 45.6294,
    ),
    AzCity(
      id: 'dashkasan',
      az: 'Daşkəsən',
      ru: 'Дашкесан',
      en: 'Dashkasan',
      lat: 40.5203,
      lng: 46.0781,
    ),
    AzCity(
      id: 'fuzuli',
      az: 'Füzuli',
      ru: 'Физули',
      en: 'Fuzuli',
      lat: 39.5994,
      lng: 47.1436,
    ),
    AzCity(
      id: 'gadabay',
      az: 'Gədəbəy',
      ru: 'Гедабей',
      en: 'Gadabay',
      lat: 40.5700,
      lng: 45.8156,
    ),
    AzCity(
      id: 'goranboy',
      az: 'Goranboy',
      ru: 'Геранбой',
      en: 'Goranboy',
      lat: 40.6103,
      lng: 46.7889,
    ),
    AzCity(
      id: 'goychay',
      az: 'Göyçay',
      ru: 'Гёйчай',
      en: 'Goychay',
      lat: 40.6531,
      lng: 47.7403,
    ),
    AzCity(
      id: 'goygol',
      az: 'Göygöl',
      ru: 'Гёйгёль',
      en: 'Goygol',
      lat: 40.5872,
      lng: 46.3197,
    ),
    AzCity(
      id: 'hajigabul',
      az: 'Hacıqabul',
      ru: 'Гаджигабул',
      en: 'Hajigabul',
      lat: 40.0361,
      lng: 48.9203,
    ),
    AzCity(
      id: 'imishli',
      az: 'İmişli',
      ru: 'Имишли',
      en: 'Imishli',
      lat: 39.8697,
      lng: 48.0611,
    ),
    AzCity(
      id: 'ismayilli',
      az: 'İsmayıllı',
      ru: 'Исмаиллы',
      en: 'Ismayilli',
      lat: 40.7864,
      lng: 48.1531,
    ),
    AzCity(
      id: 'kalbajar',
      az: 'Kəlbəcər',
      ru: 'Кельбаджар',
      en: 'Kalbajar',
      lat: 40.1053,
      lng: 46.0364,
    ),
    AzCity(
      id: 'kangarli',
      az: 'Kəngərli',
      ru: 'Кенгерли',
      en: 'Kangarli',
      lat: 39.3894,
      lng: 45.1728,
    ),
    AzCity(
      id: 'kurdamir',
      az: 'Kürdəmir',
      ru: 'Кюрдамир',
      en: 'Kurdamir',
      lat: 40.3494,
      lng: 48.1644,
    ),
    AzCity(
      id: 'gakh',
      az: 'Qax',
      ru: 'Гах',
      en: 'Gakh',
      lat: 41.4206,
      lng: 46.9297,
    ),
    AzCity(
      id: 'gazakh',
      az: 'Qazax',
      ru: 'Казах',
      en: 'Gazakh',
      lat: 41.0922,
      lng: 45.3661,
    ),
    AzCity(
      id: 'gobustan',
      az: 'Qobustan',
      ru: 'Гобустан',
      en: 'Gobustan',
      lat: 40.5333,
      lng: 48.9264,
    ),
    AzCity(
      id: 'gubadli',
      az: 'Qubadlı',
      ru: 'Губадлы',
      en: 'Gubadli',
      lat: 39.3444,
      lng: 46.5797,
    ),
    AzCity(
      id: 'gusar',
      az: 'Qusar',
      ru: 'Гусар',
      en: 'Gusar',
      lat: 41.4272,
      lng: 48.4306,
    ),
    AzCity(
      id: 'lachin',
      az: 'Laçın',
      ru: 'Лачин',
      en: 'Lachin',
      lat: 39.6383,
      lng: 46.5464,
    ),
    AzCity(
      id: 'lerik',
      az: 'Lerik',
      ru: 'Лерик',
      en: 'Lerik',
      lat: 38.7744,
      lng: 48.4153,
    ),
    AzCity(
      id: 'masalli',
      az: 'Masallı',
      ru: 'Масаллы',
      en: 'Masalli',
      lat: 39.0342,
      lng: 48.6597,
    ),
    AzCity(
      id: 'naftalan',
      az: 'Naftalan',
      ru: 'Нафталан',
      en: 'Naftalan',
      lat: 40.5072,
      lng: 46.8233,
    ),
    AzCity(
      id: 'neftchala',
      az: 'Neftçala',
      ru: 'Нефтечала',
      en: 'Neftchala',
      lat: 39.3778,
      lng: 49.2419,
    ),
    AzCity(
      id: 'oghuz',
      az: 'Oğuz',
      ru: 'Огуз',
      en: 'Oghuz',
      lat: 41.0714,
      lng: 47.4636,
    ),
    AzCity(
      id: 'ordubad',
      az: 'Ordubad',
      ru: 'Ордубад',
      en: 'Ordubad',
      lat: 38.9053,
      lng: 46.0231,
    ),
    AzCity(
      id: 'saatli',
      az: 'Saatlı',
      ru: 'Саатлы',
      en: 'Saatli',
      lat: 39.9308,
      lng: 48.3653,
    ),
    AzCity(
      id: 'sabirabad',
      az: 'Sabirabad',
      ru: 'Сабирабад',
      en: 'Sabirabad',
      lat: 40.0089,
      lng: 48.4694,
    ),
    AzCity(
      id: 'salyan',
      az: 'Salyan',
      ru: 'Сальян',
      en: 'Salyan',
      lat: 39.5964,
      lng: 48.9794,
    ),
    AzCity(
      id: 'samukh',
      az: 'Samux',
      ru: 'Самух',
      en: 'Samukh',
      lat: 40.7614,
      lng: 46.4083,
    ),
    AzCity(
      id: 'sadarak',
      az: 'Sədərək',
      ru: 'Садарак',
      en: 'Sadarak',
      lat: 39.7108,
      lng: 44.8833,
    ),
    AzCity(
      id: 'siyazan',
      az: 'Siyəzən',
      ru: 'Сиазань',
      en: 'Siyazan',
      lat: 41.0781,
      lng: 49.1114,
    ),
    AzCity(
      id: 'shabran',
      az: 'Şabran',
      ru: 'Шабран',
      en: 'Shabran',
      lat: 41.2211,
      lng: 48.9908,
    ),
    AzCity(
      id: 'shahbuz',
      az: 'Şahbuz',
      ru: 'Шахбуз',
      en: 'Shahbuz',
      lat: 39.4058,
      lng: 45.5708,
    ),
    AzCity(
      id: 'shamkir',
      az: 'Şəmkir',
      ru: 'Шамкир',
      en: 'Shamkir',
      lat: 40.8294,
      lng: 46.0186,
    ),
    AzCity(
      id: 'sharur',
      az: 'Şərur',
      ru: 'Шарур',
      en: 'Sharur',
      lat: 39.5539,
      lng: 44.9847,
    ),
    AzCity(
      id: 'shusha',
      az: 'Şuşa',
      ru: 'Шуша',
      en: 'Shusha',
      lat: 39.7597,
      lng: 46.7494,
    ),
    AzCity(
      id: 'tartar',
      az: 'Tərtər',
      ru: 'Тертер',
      en: 'Tartar',
      lat: 40.3444,
      lng: 46.9350,
    ),
    AzCity(
      id: 'tovuz',
      az: 'Tovuz',
      ru: 'Товуз',
      en: 'Tovuz',
      lat: 40.9925,
      lng: 45.6167,
    ),
    AzCity(
      id: 'ujar',
      az: 'Ucar',
      ru: 'Уджар',
      en: 'Ujar',
      lat: 40.5081,
      lng: 47.6494,
    ),
    AzCity(
      id: 'khachmaz',
      az: 'Xaçmaz',
      ru: 'Хачмаз',
      en: 'Khachmaz',
      lat: 41.4642,
      lng: 48.8022,
    ),
    AzCity(
      id: 'khizi',
      az: 'Xızı',
      ru: 'Хызы',
      en: 'Khizi',
      lat: 40.9106,
      lng: 49.0728,
    ),
    AzCity(
      id: 'yardimli',
      az: 'Yardımlı',
      ru: 'Ярдымлы',
      en: 'Yardimli',
      lat: 38.9061,
      lng: 48.2472,
    ),
    AzCity(
      id: 'zaqatala',
      az: 'Zaqatala',
      ru: 'Закаталы',
      en: 'Zaqatala',
      lat: 41.6317,
      lng: 46.6433,
    ),
    AzCity(
      id: 'zangilan',
      az: 'Zəngilan',
      ru: 'Зангилан',
      en: 'Zangilan',
      lat: 39.0869,
      lng: 46.6522,
    ),
    AzCity(
      id: 'zardab',
      az: 'Zərdab',
      ru: 'Зардаб',
      en: 'Zardab',
      lat: 40.2172,
      lng: 47.7108,
    ),
  ];

  static final Map<String, AzCity> _byId = {for (final c in all) c.id: c};

  /// Every spelling this table knows, folded, pointing at its row. Built once
  /// so enriching a 54-city API response stays O(n).
  static final Map<String, AzCity> _byFoldedName = {
    for (final c in all) ...{
      AzCity.foldQuery(c.az): c,
      AzCity.foldQuery(c.ru): c,
      AzCity.foldQuery(c.en): c,
    },
  };

  static AzCity? byId(String? id) => id == null ? null : _byId[id];

  /// Finds the local row for a city name returned by `GET /cities`.
  ///
  /// Returns `null` for a city the API knows about and this table does not —
  /// the caller then falls back to the API's own name and goes without
  /// coordinates, which only costs the distance estimate.
  static AzCity? byName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    return _byFoldedName[AzCity.foldQuery(name)];
  }

  static List<AzCity> get popular =>
      all.where((c) => c.isPopular).toList(growable: false);

  /// Whether [name] is one of the routes the home screen surfaces first.
  static bool isPopularName(String? name) => byName(name)?.isPopular ?? false;

  /// Straight-line distance in km — good enough to show an approximate route
  /// length and to sanity-check prices without a maps API.
  static double distanceKm(AzCity a, AzCity b) {
    const earthRadiusKm = 6371.0;
    double toRad(double deg) => deg * math.pi / 180;
    final dLat = toRad(b.lat - a.lat);
    final dLng = toRad(b.lng - a.lng);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(a.lat)) *
            math.cos(toRad(b.lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  /// Rough driving time, assuming ~70 km/h average on Azerbaijani highways and
  /// a 1.25 road-winding factor over the straight-line distance.
  static Duration estimatedDrive(AzCity a, AzCity b) {
    final km = distanceKm(a, b) * 1.25;
    return Duration(minutes: (km / 70 * 60).round().clamp(10, 24 * 60));
  }
}
