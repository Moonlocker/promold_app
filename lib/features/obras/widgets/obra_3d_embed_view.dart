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
class Obra3DEmbedView extends StatefulWidget {
  const Obra3DEmbedView({
    super.key,
    required this.obraId,
    this.onError,
  });

  final String obraId;
  final ValueChanged<String>? onError;

  @override
  State<Obra3DEmbedView> createState() => _Obra3DEmbedViewState();
}

class _Obra3DEmbedViewState extends State<Obra3DEmbedView> {
  WebViewController? _controller;
  bool _loading = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _abrir();
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
        _loading = false;
      });
      return;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEEF1F5))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (e) {
            widget.onError?.call(e.description);
            if (mounted && e.isForMainFrame == true) {
              setState(() {
                _erro = 'Falha ao carregar o editor 3D: ${e.description}';
                _loading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() {
      _controller = controller;
      _erro = null;
      _loading = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Stack(
      children: [
        if (controller != null && _erro == null)
          WebViewWidget(controller: controller),
        if (_erro != null)
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
                  _erro!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _abrir,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        if (_loading && _erro == null)
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
      ],
    );
  }
}
