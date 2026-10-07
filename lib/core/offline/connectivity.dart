import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Estado de conectividade global do aplicativo.
///
/// É um singleton simples (sem Riverpod) para poder ser consultado por
/// camadas de dados (repositórios/serviços) que não têm acesso ao `ref`.
/// A UI observa o mesmo estado via `onlineProvider`.
///
/// Importante: o `connectivity_plus` reporta apenas o estado do link
/// (Wi‑Fi/dados), que pode estar "conectado" mesmo sem internet. Por isso
/// confirmamos a conectividade com uma consulta DNS real antes de dizer que
/// estamos online. Assim, ao abrir o app sem internet, o cache local é usado
/// imediatamente em vez de aguardar o timeout das requisições remotas.
class AppConnectivity {
  AppConnectivity._();
  static final AppConnectivity instance = AppConnectivity._();

  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool _online = true;
  bool get isOnline => _online;

  Stream<bool> get stream => _controller.stream;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _verificando = false;

  /// Começa a observar mudanças de conectividade. Idempotente.
  Future<void> start() async {
    if (_sub != null) return;
    final connectivity = Connectivity();
    await _verificar(connectivity);
    _sub = connectivity.onConnectivityChanged.listen((_) {
      _verificar(connectivity);
    });
  }

  Future<void> _verificar(Connectivity connectivity) async {
    if (_verificando) return;
    _verificando = true;
    try {
      List<ConnectivityResult> result;
      try {
        result = await connectivity.checkConnectivity();
      } catch (_) {
        // Se a checagem falhar, assume link disponível e confirma via DNS.
        result = const [ConnectivityResult.wifi];
      }
      final linkAtivo = !result.contains(ConnectivityResult.none);
      final temInternet = linkAtivo && await _temInternet();
      _set(temInternet);
    } finally {
      _verificando = false;
    }
  }

  /// Consulta DNS real (com timeout curto) para confirmar acesso à internet.
  Future<bool> _temInternet() async {
    try {
      final lookup = await InternetAddress.lookup('supabase.co')
          .timeout(const Duration(seconds: 4));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Força a reavaliação da conectividade (ex.: após uma requisição remota
  /// falhar/suceder). Idempotente e não bloqueante.
  void recheck() {
    _verificar(Connectivity());
  }

  /// Atualiza o estado online a partir do resultado de uma operação remota.
  /// Permite detectar queda de internet em redes que mantêm o link ativo.
  void reportOnline(bool value) => _set(value);

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
