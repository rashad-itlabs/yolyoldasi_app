import 'dart:async';

/// Emits whenever either source emits, once both have produced a first value.
///
/// Used where a screen needs two live queries joined — e.g. "bookings I made"
/// plus "bookings on my rides" — without pulling in an Rx dependency.
Stream<R> combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A a, B b) combine,
) {
  late StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;

  A? latestA;
  B? latestB;
  var hasA = false;
  var hasB = false;

  void emit() {
    if (hasA && hasB) controller.add(combine(latestA as A, latestB as B));
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a.listen((value) {
        latestA = value;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = b.listen((value) {
        latestB = value;
        hasB = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
      await controller.close();
    },
  );

  return controller.stream;
}

Stream<R> combineLatest3<A, B, C, R>(
  Stream<A> a,
  Stream<B> b,
  Stream<C> c,
  R Function(A a, B b, C c) combine,
) {
  return combineLatest2<({A a, B b}), C, R>(
    combineLatest2<A, B, ({A a, B b})>(a, b, (x, y) => (a: x, b: y)),
    c,
    (pair, third) => combine(pair.a, pair.b, third),
  );
}
