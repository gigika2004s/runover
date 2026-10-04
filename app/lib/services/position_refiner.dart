import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Aguarda uma leitura melhor quando a primeira posição é aproximada.
class PositionRefiner {
  void Function()? _stop;
  bool _disposed = false;

  Future<Position> refine(Position initial) async {
    if (_disposed || (_knownAccuracy(initial) && initial.accuracy <= 50)) {
      return initial;
    }
    _stop?.call();
    var best = initial;
    final result = Completer<Position>();
    void finish() {
      if (!result.isCompleted) result.complete(best);
    }

    _stop = finish;
    // Prazo total: novas leituras não podem prolongar a busca indefinidamente.
    final timer = Timer(const Duration(seconds: 15), finish);
    StreamSubscription<Position>? subscription;
    try {
      subscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 0,
            ),
          ).listen(
            (position) {
              if (result.isCompleted || !_usable(position)) return;
              if (!_knownAccuracy(best) || position.accuracy < best.accuracy) {
                best = position;
              }
              if (best.accuracy <= 50) finish();
            },
            onError: (Object _) => finish(),
            onDone: finish,
          );
      return await result.future;
    } catch (_) {
      return best;
    } finally {
      timer.cancel();
      unawaited(subscription?.cancel().catchError((Object _) {}));
      if (identical(_stop, finish)) _stop = null;
    }
  }

  static bool _knownAccuracy(Position p) =>
      p.accuracy.isFinite && p.accuracy > 0;

  static bool _usable(Position p) =>
      _knownAccuracy(p) &&
      p.latitude.isFinite &&
      p.longitude.isFinite &&
      p.latitude.abs() <= 90 &&
      p.longitude.abs() <= 180 &&
      DateTime.now().difference(p.timestamp) <= const Duration(minutes: 2);

  void dispose() {
    _disposed = true;
    _stop?.call();
  }
}
