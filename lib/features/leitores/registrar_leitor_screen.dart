import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/qr_scanner_view.dart';
import '../../providers/obra_providers.dart';
import '../../providers/supabase_providers.dart';
import '../../services/local_store.dart';
import 'leitor_configs.dart';

/// Tela genérica dos leitores de registro: Armada, Concretada e Montagem.
///
/// Fluxo idêntico ao webapp: um QR = uma peça; bloqueia se já estiver no
/// status-alvo; preenche a data correspondente apenas se estiver vazia.
class RegistrarLeitorScreen extends ConsumerStatefulWidget {
  const RegistrarLeitorScreen({super.key, required this.config});

  final LeitorRegistrarConfig config;

  @override
  ConsumerState<RegistrarLeitorScreen> createState() =>
      _RegistrarLeitorScreenState();
}

class _RegistrarLeitorScreenState
    extends ConsumerState<RegistrarLeitorScreen> {
  bool _processando = false;
  String? _erro;
  String? _sucesso;
  String? _flash;

  Map<String, dynamic>? _last;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  Future<void> _carregarHistorico() async {
    final last = await LocalStore.getMap(widget.config.chaveLast);
    final hist = await LocalStore.getList(widget.config.chaveHistory);
    if (!mounted) return;
    setState(() {
      _last = last;
      _history = hist;
    });
  }

  String get _usuario {
    final email = ref.read(authServiceProvider).currentUser?.email ?? '';
    final nome = email.split('@').first;
    return nome.isEmpty ? 'Sistema' : nome;
  }

  void _piscar(String cor) {
    setState(() => _flash = cor);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  Future<void> _onDetect(String codigo) async {
    if (_processando) return;
    setState(() {
      _processando = true;
      _erro = null;
      _sucesso = null;
    });

    final service = ref.read(leitorServiceProvider);
    try {
      final peca = await service.buscarPeca(
        codigo,
        campoData: widget.config.campoData,
      );

      if (peca == null) {
        HapticFeedback.heavyImpact();
        _piscar('red');
        setState(() => _erro = 'Peça não encontrada');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _processando = false);
        return;
      }

      if (peca.status == widget.config.statusAlvo) {
        HapticFeedback.heavyImpact();
        _piscar('red');
        setState(() =>
            _erro = 'Peça ${peca.identificador} já está ${widget.config.acaoLabel}');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _processando = false);
        return;
      }

      await service.marcarStatus(
        pecaId: peca.id,
        status: widget.config.statusAlvo,
        campoData: widget.config.campoData,
        dataAtual: peca.dataReferencia,
      );

      final item = <String, dynamic>{
        'pecaId': peca.id,
        'identificador': peca.identificador,
        'pecaNome': peca.pecaNome.isEmpty ? peca.identificador : peca.pecaNome,
        'obraNome': peca.obraNome,
        'timestamp': DateTime.now().toIso8601String(),
        'usuario': _usuario,
      };
      final novaHist = [item, ..._history].take(50).toList();
      await LocalStore.setMap(widget.config.chaveLast, item);
      await LocalStore.setList(widget.config.chaveHistory, novaHist);

      HapticFeedback.mediumImpact();
      _piscar('green');
      setState(() {
        _last = item;
        _history = novaHist;
        _sucesso = '${peca.identificador} marcada como ${widget.config.acaoLabel}!';
      });

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          _processando = false;
          _sucesso = null;
        });
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      _piscar('red');
      if (mounted) {
        setState(() => _erro = 'Erro ao registrar: $e');
      }
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _processando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusCfg =
        ref.watch(statusConfigProvider).value ?? StatusConfig.defaults;
    final cor = statusCfg.colorOf(widget.config.statusAlvo);

    return Scaffold(
      appBar: AppBar(title: Text(widget.config.titulo)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                widget.config.subtitulo,
                style: const TextStyle(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: _erro != null
                          ? AppColors.destructive
                          : _sucesso != null
                              ? AppColors.success
                              : cor,
                      child: Text(
                        _erro ??
                            _sucesso ??
                            'Escaneie o QR Code da peça',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    QrScannerView(
                      paused: _processando,
                      onDetected: _onDetect,
                      hint: _processando
                          ? 'Processando...'
                          : 'Aponte para o QR Code da peça',
                    ),
                  ],
                ),
              ),
              if (_last != null) ...[
                const SizedBox(height: 16),
                _lastCard(_last!),
              ],
              if (_history.length > 1) ...[
                const SizedBox(height: 16),
                _historyCard(),
              ],
            ],
          ),
          if (_flash != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: 0.28,
                  duration: const Duration(milliseconds: 150),
                  child: ColoredBox(
                    color: _flash == 'green'
                        ? AppColors.success
                        : AppColors.destructive,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lastCard(Map<String, dynamic> item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: AppColors.success, size: 18),
                const SizedBox(width: 6),
                const Text('Último registro',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  Formatters.dataHoraBr(
                      DateTime.tryParse(item['timestamp'] ?? '')),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.mutedForeground),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${item['identificador']} · ${item['pecaNome']}',
              style: const TextStyle(fontSize: 13.5),
            ),
            if ((item['obraNome'] ?? '').toString().isNotEmpty)
              Text(item['obraNome'],
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground)),
            Text('por ${item['usuario']}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.mutedForeground)),
          ],
        ),
      ),
    );
  }

  Widget _historyCard() {
    final agora = DateTime.now();
    final recentes = _history.where((h) {
      final t = DateTime.tryParse(h['timestamp'] ?? '');
      return t != null && agora.difference(t).inHours < 24;
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Últimas 24h (${recentes.length})',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...recentes.take(20).map(
                  (h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${h['identificador']} · ${h['pecaNome']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        Text(
                          Formatters.dataHoraBr(
                              DateTime.tryParse(h['timestamp'] ?? '')),
                          style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
