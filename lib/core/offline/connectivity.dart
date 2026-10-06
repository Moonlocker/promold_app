import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Estado de conectividade global do aplicativo.
///
/// É um singleton simples (sem Riverpod) para poder ser consultado por
/// camadas de dados (repositórios/serviços) que não têm acesso ao `ref`.
/// A UI observa o mesmo estado via `onlineProvider`.
class AppConnectivity {
  AppConnectivity._();
  static final AppConnectivity instance = AppConnectivity._();

  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool _online = true;
  bool get isOnline => _online;

  Stream<bool> get stream => _controller.stream;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Começa a observar mudanças de conectividade. Idempotente.
  Future<void> start() async {
    if (_sub != null) return;
    final connectivity = Connectivity();
    try {
      final result = await connectivity.checkConnectivity();
      _set(!result.contains(ConnectivityResult.none));
    } catch (_) {
      _set(true);
    }
    _sub = connectivity.onConnectivityChanged.listen((result) {
      _set(!result.contains(ConnectivityResult.none));
    });
  }

  void _set(bool value) {
    if (_online == value) return;
    _online = value;
    if (!_controller.isClosed) _controller.add(value);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _controller.close();
  }
}
