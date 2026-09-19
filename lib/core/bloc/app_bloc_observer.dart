import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

/// Logs every bloc transition in debug builds.
///
/// Errors are logged unconditionally: a bloc that throws inside an event
/// handler swallows the stack trace otherwise, which is the single most
/// expensive thing to debug in this architecture.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    if (kDebugMode) {
      debugPrint('[${bloc.runtimeType}] ← ${event.runtimeType}');
    }
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    debugPrint('[${bloc.runtimeType}] ✖ $error\n$stackTrace');
    super.onError(bloc, error, stackTrace);
  }
}
