import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_colors.dart';

/// Visualizador IFC real (Three.js + web-ifc) embutido em WebView.
///
/// Carrega a página `assets/viewer/ifc_viewer.html`, que baixa o arquivo IFC
/// informado e renderiza a geometria. As cores por status são aplicadas via
/// [statusColors] (mapa `globalId -> #RRGGBB`).
class ObraIfcViewer extends StatefulWidget {
  const ObraIfcViewer({
    super.key,
    required this.url,
    this.statusColors = const {},
    this.onSelect,
    this.onError,
  });

  final String url;
  final Map<String, String> statusColors;

  /// Recebe `{expressId, globalId, name}` ou `null` quando clica no vazio.
  final ValueChanged<Map<String, dynamic>?>? onSelect;
  final ValueChanged<String>? onError;

  @override
  State<ObraIfcViewer> createState() => _ObraIfcViewerState();
}

class _ObraIfcViewerState extends State<ObraIfcViewer> {
  late final WebViewController _controller;
  bool _loading = true;
  String _status = 'Preparando visualizador…';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEEF1F5))
      ..addJavaScriptChannel('IfcBridge', onMessageReceived: _onMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            // Aguarda o módulo JS inicializar e injeta a URL do IFC.
            for (var i = 0; i < 20 && !_ready; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 150));
              try {
                final r = await _controller.runJavaScriptReturningResult(
                    'window.__ready === true');
                if (r == true || r.toString() == 'true') {
                  _ready = true;
                  break;
                }
              } catch (_) {}
            }
            await _controller.runJavaScript(
                'window.__setIfc(${jsonEncode(widget.url)});');
          },
          onWebResourceError: (e) {
            widget.onError?.call(e.description);
          },
        ),
      )
      ..loadFlutterAsset('assets/viewer/ifc_viewer.html');
  }

  @override
  void didUpdateWidget(covariant ObraIfcViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statusColors != widget.statusColors) {
      _applyColors();
    }
  }

  void _applyColors() {
    _controller.runJavaScript(
        'window.setStatusColors(${jsonEncode(widget.statusColors)});');
  }

  void _onMessage(JavaScriptMessage message) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (data['type']) {
      case 'loaded':
        setState(() => _loading = false);
        _applyColors();
      case 'select':
        if (data['expressId'] == null) {
          widget.onSelect?.call(null);
        } else {
          widget.onSelect?.call(data);
        }
      case 'error':
        setState(() {
          _loading = false;
          _status = 'Erro: ${data['message'] ?? 'falha ao carregar'}';
        });
        widget.onError?.call('${data['message']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          Container(
            color: AppColors.background,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(_status,
                      style: const TextStyle(
                          color: AppColors.mutedForeground)),
                ],
              ),
            ),
          ),
        Positioned(
          right: 10,
          bottom: 10,
          child: Column(
            children: [
              _BotaoIcone(
                icon: Icons.center_focus_strong,
                tooltip: 'Recentralizar',
                onTap: () =>
                    _controller.runJavaScript('window.resetView();'),
              ),
              _BotaoIcone(
                icon: Icons.view_in_ar_outlined,
                tooltip: 'Vista 3D',
                onTap: () => _controller.runJavaScript('window.viewIso();'),
              ),
              _BotaoIcone(
                icon: Icons.grid_on_outlined,
                tooltip: 'Planta',
                onTap: () => _controller.runJavaScript('window.viewTop();'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BotaoIcone extends StatelessWidget {
  const _BotaoIcone({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: AppColors.sidebar.withValues(alpha: 0.85),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
