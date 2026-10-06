import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';

/// Editor 3D do sistema web embutido via WebView.
///
/// Carrega a rota `/embed/obra-3d/:obraId` do webapp, injetando a sessão do
/// usuário (access/refresh token) no hash da URL. Assim o editor 3D fica
/// exatamente igual ao web — grupos, cores, seleção de peças, ferramentas,
/// comentários, ocultar/mostrar, etc.
///
/// Se a página não sinalizar prontidão (ex.: site desatualizado → 404), mostra
/// um aviso e oferece o visualizador simplificado via [onFallback].
class Obra3DEmbedView extends StatefulWidget {
  const Obra3DEmbedView({
    super.key,
    required this.obraId,
    this.onError,
    this.onFallback,
  });

  final String obraId;
  final ValueChanged<String>? onError;

  /// Chamado quando o editor não puder ser carregado e o usuário optar pelo
  /// visualizador simples (IFC nativo).
  final VoidCallback? onFallback;

  @override
  State<Obra3DEmbedView> createState() => _Obra3DEmbedViewState();
}

class _Obra3DEmbedViewState extends State<Obra3DEmbedView> {
  WebViewController? _controller;
  Timer? _timer;
  bool _ready = false;
  bool _timedOut = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String? _montarUrl() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return null;
    final base = Env.webBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final at = Uri.encodeComponent(session.accessToken);
    final rt = Uri.encodeComponent(session.refreshToken ?? '');
    return '$base/embed/obra-3d/${widget.obraId}#access_token=$at&refresh_token=$rt';
  }

  void _abrir() {
    final url = _montarUrl();
    if (url == null) {
      setState(() {
        _erro = 'Sessão não encontrada. Faça login novamente.';
      });
      return;
    }

    _timer?.cancel();
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEEF1F5))
      ..addJavaScriptChannel(
        'EmbedBridge',
        onMessageReceived: (message) {
          if (message.message == 'ready' && mounted) {
            _timer?.cancel();
            setState(() {
              _ready = true;
              _timedOut = false;
            });
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (e) {
            if (mounted && e.isForMainFrame == true) {
              _timer?.cancel();
              setState(() {
                _erro = 'Falha ao carregar o editor 3D: ${e.description}';
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() {
      _controller = controller;
      _erro = null;
      _ready = false;
      _timedOut = false;
    });

    // Se não ficar pronto em 18s, provavelmente o site ainda não tem a rota.
    _timer = Timer(const Duration(seconds: 18), () {
      if (mounted && !_ready && _erro == null) {
        setState(() => _timedOut = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final mostrarOverlay = !_ready && (_erro != null || _timedOut);
    return Stack(
      children: [
        if (controller != null) WebViewWidget(controller: controller),
        if (!_ready && !mostrarOverlay)
          const ColoredBox(
            color: AppColors.background,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Carregando editor 3D…',
                      style: TextStyle(color: AppColors.mutedForeground)),
                ],
              ),
            ),
          ),
        if (mostrarOverlay)
          Container(
            color: AppColors.background,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 40,
                    color: AppColors.mutedForeground),
                const SizedBox(height: 12),
                Text(
                  _erro ??
                      'Não foi possível abrir o editor 3D.\n'
                          'O sistema web pode estar desatualizado '
                          '(é preciso publicar a versão com o editor 3D).',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _abrir,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                    if (widget.onFallback != null)
                      OutlinedButton.icon(
                        onPressed: widget.onFallback,
                        icon: const Icon(Icons.view_in_ar_outlined),
                        label: const Text('Usar visualizador simples'),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
