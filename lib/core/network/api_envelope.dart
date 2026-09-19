import 'package:equatable/equatable.dart';

import '../types.dart';

/// Unwraps the `{ "data": ... }` wrapper every API resource comes in.
///
/// Some endpoints (`/auth/firebase`, `/notifications/unread-count`) answer with
/// a bare object instead, so a missing `data` key falls back to the body — that
/// keeps one code path for both shapes.
abstract final class Envelope {
  static Json object(Object? body) {
    if (body is! Map) return const {};
    final json = Json.from(body);
    final data = json['data'];
    return data is Map ? Json.from(data) : json;
  }

  static List<Json> list(Object? body) {
    if (body is List) return body.whereType<Map>().map(Json.from).toList();
    if (body is! Map) return const [];
    final data = Json.from(body)['data'];
    if (data is! List) return const [];
    return data.whereType<Map>().map(Json.from).toList();
  }
}

/// The `meta` block of a paginated response (API.md §1).
class PageMeta extends Equatable {
  const PageMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  /// The fallback describes a single full page, so a list endpoint that omits
  /// `meta` is simply treated as "everything you asked for, no more pages".
  static const PageMeta single = PageMeta(
    currentPage: 1,
    lastPage: 1,
    perPage: 0,
    total: 0,
  );

  factory PageMeta.fromJson(Json json) {
    int read(String key, int fallback) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    return PageMeta(
      currentPage: read('current_page', 1),
      lastPage: read('last_page', 1),
      perPage: read('per_page', 0),
      total: read('total', 0),
    );
  }

  bool get hasMore => currentPage < lastPage;
  int get nextPage => currentPage + 1;

  @override
  List<Object?> get props => [currentPage, lastPage, perPage, total];
}

/// One page of [T], plus enough metadata to ask for the next one.
class Paginated<T> extends Equatable {
  const Paginated({required this.items, required this.meta});

  final List<T> items;
  final PageMeta meta;

  const Paginated.empty() : items = const [], meta = PageMeta.single;

  bool get hasMore => meta.hasMore;
  int get nextPage => meta.nextPage;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// Appends [next]'s items to this page's, keeping [next]'s cursor. Used by
  /// the "load more" path in every paginated bloc.
  Paginated<T> concat(Paginated<T> next) =>
      Paginated(items: [...items, ...next.items], meta: next.meta);

  Paginated<T> replacingItems(List<T> value) =>
      Paginated(items: value, meta: meta);

  /// Parses a paginated body, mapping each element with [fromJson].
  factory Paginated.fromBody(Object? body, T Function(Json json) fromJson) {
    final items = Envelope.list(body).map(fromJson).toList(growable: false);
    final meta = (body is Map && body['meta'] is Map)
        ? PageMeta.fromJson(Json.from(body['meta'] as Map))
        : PageMeta.single;
    return Paginated(items: items, meta: meta);
  }

  @override
  List<Object?> get props => [items, meta];
}
