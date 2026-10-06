import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/qr_scanner_view.dart';
import '../../providers/obra_providers.dart';
import '../../providers/supabase_providers.dart';
import '../../services/leitor_service.dart';
import '../../services/local_store.dart';
import 'leitor_configs.dart';

/// Tela genérica dos leitores de registro: Armada, Concretada e Montagem.
///
/// Fluxo idêntico ao webapp: um QR = uma peça; bloqueia se já estiver no
/// status-alvo; preenche a data correspondente apenas se estiver vazia.
///
/// Funciona offline: a leitura entra numa fila local e é sincronizada
/// automaticamente quando a conexão volta.
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
  bool _sincronizando = false;
  int _pending = 0;
  String? _erro;
  String? _sucesso;
  String? _flash;

  Map<String, dynamic>? _last;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
    _atualizarPendentes();
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

  Future<void> _atualizarPendentes() async {
    final total = await ref.read(leitorServiceProvider).pendingLeiturasCount();
    if (!mounted) return;
    setState(() => _pending = total);
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

  Future<void> _syncPendentes() async {
    if (_sincronizando || _pending == 0) return;
    setState(() => _sincronizando = true);
    final result = await ref.read(leitorServiceProvider).syncLeituras();
    await _atualizarPendentes();
    if (!mounted) return;
    setState(() => _sincronizando = false);
    if (result.ok > 0 || result.fail > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.ok} sincronizado(s), ${result.fail} pendente(s)',
          ),
        ),
      );
    }
  }

  Future<void> _registrar(String codigo) async {
    final service = ref.read(leitorServiceProvider);
    final online = ref.read(onlineProvider).value ?? true;

    if (!online) {
      await _salvarOffline(service, codigo);
      return;
    }

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
        setState(() => _erro =
            'Peça ${peca.identificador} já está ${widget.config.acaoLabel}');
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

      await _finalizarSucesso(
        service,
        pecaId: peca.id,
        identificador: peca.identificador,
        pecaNome: peca.pecaNome,
        obraNome: peca.obraNome,
      );
    } catch (e) {
      // Falha de rede no meio da operação: salva offline.
      await _salvarOffline(service, codigo);
    }
  }

  Future<void> _salvarOffline(LeitorService service, String codigo) async {
    await service.enqueueLeitura({
      'kind': 'status',
      'codigo': codigo,
      'status': widget.config.statusAlvo,
      'campoData': widget.config.campoData,
      'usuario': _usuario,
    });
    await _atualizarPendentes();

    final item = <String, dynamic>{
      'identificador': codigo,
      'pecaNome': codigo,
      'timestamp': DateTime.now().toIso8601String(),
      'usuario': _usuario,
      'offline': true,
    };
    final novaHist = [item, ..._history].take(50).toList();
    await LocalStore.setList(widget.config.chaveHistory, novaHist);

    HapticFeedback.mediumImpact();
    _piscar('green');
    if (mounted) {
      setState(() {
        _history = novaHist;
        _sucesso = 'Registrado offline — sincroniza ao reconectar';
      });
    }
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) {
      setState(() {
        _processando = false;
        _sucesso = null;
      });
    }
  }

  Future<void> _finalizarSucesso(
    LeitorService service, {
    required String pecaId,
    required String identificador,
    required String pecaNome,
    required String obraNome,
  }) async {
    final item = <String, dynamic>{
      'pecaId': pecaId,
      'identificador': identificador,
      'pecaNome': pecaNome.isEmpty ? identificador : pecaNome,
      'obraNome': obraNome,
      'timestamp': DateTime.now().toIso8601String(),
      'usuario': _usuario,
    };
    final novaHist = [item, ..._history].take(50).toList();
    await LocalStore.setMap(widget.config.chaveLast, item);
    await LocalStore.setList(widget.config.chaveHistory, novaHist);

    HapticFeedback.mediumImpact();
    _piscar('green');
    if (mounted) {
      setState(() {
        _last = item;
        _history = novaHist;
        _sucesso = '$identificador marcada como ${widget.config.acaoLabel}!';
      });
    }
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _processando = false;
        _sucesso = null;
      });
    }
  }

  Future<void> _onDetect(String codigo) async {
    if (_processando) return;
    setState(() {
      _processando = true;
      _erro = null;
      _sucesso = null;
    });
    await _registrar(codigo);
  }

  @override
  Widget build(BuildContext context) {
    final statusCfg =
        ref.watch(statusConfigProvider).value ?? StatusConfig.defaults;
    final cor = statusCfg.colorOf(widget.config.statusAlvo);
    final online = ref.watch(onlineProvider).value ?? true;

    ref.listen(onlineProvider, (previous, next) {
      if (next.value == true) _syncPendentes();
    });

    return Scaffold(
      appBar: AppBar(title: Text(widget.config.titulo)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (!online)
                _banner('Modo offline — leituras serão sincronizadas',
                    Icons.wifi_off, AppColors.warning),
              if (_pending > 0)
                _banner(
                  _sincronizando
                      ? 'Sincronizando...'
                      : '$_pending leitura(s) pendente(s)',
                  Icons.cloud_upload_outlined,
                  AppColors.info,
                  action: _sincronizando
                      ? null
                      : TextButton(
                          onPressed: _syncPendentes,
                          child: const Text('Sincronizar'),
                        ),
                ),
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

  Widget _banner(String texto, IconData icon, Color color, {Widget? action}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          ?action,
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
