import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/qr_scanner_view.dart';
import '../../models/estoque.dart';
import '../../providers/obra_providers.dart';
import '../../providers/supabase_providers.dart';
import '../../services/local_store.dart';

const _kFixed = 'leitor_estoque_fixed';
const _kLast = 'leitor_estoque_last';
const _kHistory = 'leitor_estoque_history';
const _kOffline = 'leitor_estoque_offline';

enum _Step { scanEstoque, estoqueOk, scanPeca, done }

/// Leitor de Estoque: passo 1 (estoque) + passo 2 (peça), com estoque fixável,
/// seleção manual e fila offline.
class LeitorEstoqueScreen extends ConsumerStatefulWidget {
  const LeitorEstoqueScreen({super.key});

  @override
  ConsumerState<LeitorEstoqueScreen> createState() =>
      _LeitorEstoqueScreenState();
}

class _LeitorEstoqueScreenState extends ConsumerState<LeitorEstoqueScreen> {
  _Step _step = _Step.scanEstoque;
  bool _manual = false;
  bool _fixed = false;
  bool _processando = false;
  bool _isOnline = true;
  bool _sincronizando = false;

  String? _estoqueId;
  String _estoqueNome = '';
  String? _erro;
  String? _sucesso;
  String? _flash;

  Map<String, dynamic>? _last;
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _offline = [];

  // Manual
  List<Estoque> _estoques = [];
  String? _selEstoque;
  List<Map<String, dynamic>> _obras = [];
  String? _selObra;
  List<Map<String, dynamic>> _pecas = [];
  String? _selPeca;

  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _fixed = await LocalStore.getBool(_kFixed);
    _last = await LocalStore.getMap(_kLast);
    _history = await LocalStore.getList(_kHistory);
    _offline = await LocalStore.getList(_kOffline);

    final connectivity = Connectivity();
    final inicial = await connectivity.checkConnectivity();
    _isOnline = !inicial.contains(ConnectivityResult.none);
    _connSub = connectivity.onConnectivityChanged.listen((result) {
      final online = !result.contains(ConnectivityResult.none);
      if (mounted) setState(() => _isOnline = online);
      if (online) _sync();
    });

    if (mounted) setState(() {});
    if (_isOnline) _sync();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
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

  Future<void> _sync() async {
    if (_offline.isEmpty || _sincronizando || !_isOnline) return;
    setState(() => _sincronizando = true);
    final service = ref.read(leitorServiceProvider);
    final restantes = <Map<String, dynamic>>[];
    var ok = 0;
    var fail = 0;
    for (final item in _offline) {
      try {
        final peca = await service.buscarPeca(
          item['pecaId']?.toString() ?? '',
          campoData: 'data_concretagem',
        );
        if (peca == null) {
          fail++;
          restantes.add(item);
          continue;
        }
        await service.vincularEstoque(
          pecaId: peca.id,
          estoqueId: item['estoqueId'] as String,
          dataConcretagem: peca.dataReferencia,
        );
        ok++;
      } catch (_) {
        fail++;
        restantes.add(item);
      }
    }
    await LocalStore.setList(_kOffline, restantes);
    if (!mounted) return;
    setState(() {
      _offline = restantes;
      _sincronizando = false;
    });
    if (ok > 0 || fail > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$ok sincronizado(s), $fail falha(s)')),
      );
    }
  }

  Future<void> _onDetect(String codigo) async {
    if (_processando) return;
    if (_step == _Step.scanEstoque) {
      await _resolverEstoque(codigo);
    } else {
      await _resolverPeca(codigo);
    }
  }

  Future<void> _resolverEstoque(String codigo) async {
    setState(() {
      _processando = true;
      _erro = null;
    });
    try {
      final estoque =
          await ref.read(leitorServiceProvider).resolverEstoque(codigo);
      if (estoque == null) {
        HapticFeedback.heavyImpact();
        _piscar('red');
        setState(() => _erro = 'Estoque não encontrado');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _processando = false);
        return;
      }
      HapticFeedback.mediumImpact();
      _piscar('green');
      setState(() {
        _estoqueId = estoque.id;
        _estoqueNome = estoque.nome;
        _step = _Step.estoqueOk;
        _sucesso = 'Estoque: ${estoque.nome}';
      });
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {
          _sucesso = null;
          _step = _Step.scanPeca;
          _processando = false;
        });
      }
    } catch (e) {
      _piscar('red');
      if (mounted) setState(() => _erro = 'Erro: $e');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _resolverPeca(String codigo) async {
    if (_estoqueId == null) {
      setState(() => _erro = 'Selecione um estoque primeiro');
      return;
    }
    setState(() {
      _processando = true;
      _erro = null;
    });

    if (!_isOnline) {
      final item = <String, dynamic>{
        'estoqueId': _estoqueId,
        'estoqueNome': _estoqueNome,
        'pecaId': codigo,
        'timestamp': DateTime.now().toIso8601String(),
        'usuario': _usuario,
      };
      final novaFila = [..._offline, item];
      await LocalStore.setList(_kOffline, novaFila);
      HapticFeedback.mediumImpact();
      _piscar('green');
      if (mounted) {
        setState(() {
          _offline = novaFila;
          _sucesso = 'Vínculo salvo offline';
        });
      }
      await Future.delayed(const Duration(milliseconds: 1200));
      _reset();
      return;
    }

    try {
      final service = ref.read(leitorServiceProvider);
      final peca = await service.buscarPeca(
        codigo,
        campoData: 'data_concretagem',
      );
      if (peca == null) {
        HapticFeedback.heavyImpact();
        _piscar('red');
        setState(() => _erro = 'Peça não encontrada');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _processando = false);
        return;
      }

      await service.vincularEstoque(
        pecaId: peca.id,
        estoqueId: _estoqueId!,
        dataConcretagem: peca.dataReferencia,
      );

      final item = <String, dynamic>{
        'pecaId': peca.identificador,
        'identificador': peca.identificador,
        'pecaNome': peca.pecaNome.isEmpty ? peca.identificador : peca.pecaNome,
        'obraNome': peca.obraNome,
        'estoqueNome': _estoqueNome,
        'timestamp': DateTime.now().toIso8601String(),
        'usuario': _usuario,
      };
      final novaHist = [item, ..._history].take(50).toList();
      await LocalStore.setMap(_kLast, item);
      await LocalStore.setList(_kHistory, novaHist);

      HapticFeedback.mediumImpact();
      _piscar('green');
      if (mounted) {
        setState(() {
          _last = item;
          _history = novaHist;
          _sucesso = '${peca.identificador} → $_estoqueNome';
          _step = _Step.done;
        });
      }
      await Future.delayed(const Duration(milliseconds: 1400));
      _reset();
    } catch (e) {
      HapticFeedback.heavyImpact();
      _piscar('red');
      if (mounted) setState(() => _erro = 'Erro ao vincular: $e');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _processando = false);
    }
  }

  void _reset() {
    if (!mounted) return;
    if (_fixed && _estoqueId != null) {
      setState(() {
        _processando = false;
        _sucesso = null;
        _erro = null;
        _step = _Step.scanPeca;
        _selObra = null;
        _selPeca = null;
      });
      return;
    }
    setState(() {
      _estoqueId = null;
      _estoqueNome = '';
      _processando = false;
      _sucesso = null;
      _erro = null;
      _step = _Step.scanEstoque;
      _selEstoque = null;
      _selObra = null;
      _selPeca = null;
      _pecas = [];
    });
  }

  // -------------------------------------------------------------- Manual
  Future<void> _carregarManual() async {
    final service = ref.read(leitorServiceProvider);
    final estoques = await service.listEstoquesAtivos();
    final obras = await service.listObrasAtivas();
    if (!mounted) return;
    setState(() {
      _estoques = estoques;
      _obras = obras;
    });
  }

  Future<void> _confirmarEstoqueManual() async {
    if (_selEstoque == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um estoque')),
      );
      return;
    }
    final est = _estoques.firstWhere((e) => e.id == _selEstoque);
    setState(() {
      _estoqueId = est.id;
      _estoqueNome = est.nome;
      _step = _Step.estoqueOk;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _step = _Step.scanPeca);
  }

  Future<void> _carregarPecasManual() async {
    if (_selObra == null || _estoqueId == null) {
      setState(() => _pecas = []);
      return;
    }
    final est = _estoques.firstWhere((e) => e.id == _estoqueId);
    final service = ref.read(leitorServiceProvider);
    var pecas = await service.listPecasDaObra(_selObra!);
    if (est.pecasPermitidas != null && est.pecasPermitidas!.isNotEmpty) {
      pecas = pecas
          .where((p) => est.pecasPermitidas!.contains(p['peca_catalogo_id']))
          .toList();
    }
    if (est.categoriasPermitidas != null &&
        est.categoriasPermitidas!.isNotEmpty) {
      pecas = pecas.where((p) {
        final cat = p['pecas_catalogo'];
        final catId = cat is Map ? cat['categoria_id'] : null;
        return catId != null && est.categoriasPermitidas!.contains(catId);
      }).toList();
    }
    if (mounted) setState(() => _pecas = pecas);
  }

  @override
  Widget build(BuildContext context) {
    final statusCfg =
        ref.watch(statusConfigProvider).value ?? StatusConfig.defaults;
    final cor = statusCfg.colorOf('em_estoque');

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Peça em Estoque')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (!_isOnline) _banner('Modo offline',
                  Icons.wifi_off, AppColors.warning),
              if (_offline.isNotEmpty && _isOnline)
                _banner(
                  _sincronizando
                      ? 'Sincronizando...'
                      : '${_offline.length} pendente(s)',
                  Icons.wifi,
                  AppColors.info,
                  action: _sincronizando
                      ? null
                      : TextButton(
                          onPressed: _sync, child: const Text('Sincronizar')),
                ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      icon: Icon(Icons.qr_code),
                      label: Text('QR Code')),
                  ButtonSegment(
                      value: true,
                      icon: Icon(Icons.keyboard),
                      label: Text('Manual')),
                ],
                selected: {_manual},
                onSelectionChanged: (s) {
                  setState(() {
                    _manual = s.first;
                    _reset();
                  });
                  if (_manual) _carregarManual();
                },
              ),
              if (_estoqueId != null) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fixar estoque'),
                  subtitle: Text(
                    _fixed
                        ? '$_estoqueNome — escaneie apenas peças'
                        : 'Ative para leitura em lote',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _fixed,
                  onChanged: (v) async {
                    setState(() => _fixed = v);
                    await LocalStore.setBool(_kFixed, v);
                  },
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _etapa('1. Estoque', _estoqueId == null, AppColors.primary),
                  const SizedBox(width: 8),
                  _etapa('2. Peça', _estoqueId != null, AppColors.info),
                ],
              ),
              const SizedBox(height: 12),
              if (!_manual) _scannerCard(cor),
              if (_manual) _manualCard(),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _erro = null;
                      _processando = false;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
              if (_last != null) ...[
                const SizedBox(height: 16),
                _lastCard(),
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
                child: ColoredBox(
                  color: (_flash == 'green'
                          ? AppColors.success
                          : AppColors.destructive)
                      .withValues(alpha: 0.28),
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
          Text(texto,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          ?action,
        ],
      ),
    );
  }

  Widget _etapa(String label, bool ativo, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ativo ? cor.withValues(alpha: 0.10) : AppColors.muted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: ativo ? cor : AppColors.border, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ativo ? cor : AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }

  Widget _scannerCard(Color cor) {
    final scanEstoque = _step == _Step.scanEstoque;
    final cabecalho = _erro != null
        ? _erro!
        : _sucesso != null
            ? _sucesso!
            : scanEstoque
                ? 'Escaneie o Estoque'
                : 'Escaneie a Peça${_estoqueNome.isNotEmpty ? ' · $_estoqueNome' : ''}';
    return Card(
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
            child: Row(
              children: [
                Icon(scanEstoque ? Icons.warehouse_outlined : Icons.inventory_2_outlined,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cabecalho,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          QrScannerView(
            paused: _processando,
            onDetected: _onDetect,
            hint: scanEstoque
                ? 'Aponte para o QR Code do estoque'
                : 'Aponte para o QR Code da peça',
          ),
        ],
      ),
    );
  }

  Widget _manualCard() {
    final etapa1 = _estoqueId == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: etapa1
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Selecione o Estoque',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selEstoque,
                    decoration:
                        const InputDecoration(labelText: 'Estoque'),
                    items: _estoques
                        .map((e) => DropdownMenuItem(
                            value: e.id, child: Text(e.nome)))
                        .toList(),
                    onChanged: (v) => setState(() => _selEstoque = v),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _confirmarEstoqueManual,
                    child: const Text('Confirmar Estoque'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Peça para: $_estoqueNome',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.rotate_left),
                        onPressed: _reset,
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _selObra,
                    decoration: const InputDecoration(labelText: 'Obra'),
                    items: _obras
                        .map((o) => DropdownMenuItem(
                            value: o['id'] as String,
                            child: Text(o['nome'] as String)))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selObra = v;
                        _selPeca = null;
                      });
                      _carregarPecasManual();
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selPeca,
                    decoration: const InputDecoration(labelText: 'Peça'),
                    items: _pecas
                        .map((p) => DropdownMenuItem(
                              value: p['id'] as String,
                              child: Text(
                                  '${p['identificador']} - ${(p['pecas_catalogo'] is Map ? (p['pecas_catalogo'] as Map)['nome'] : '') ?? ''}'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selPeca = v),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: (_selPeca == null || _processando)
                        ? null
                        : () => _resolverPeca(_selPeca!),
                    child: const Text('Vincular Peça'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _lastCard() {
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
                const Text('Último vínculo',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  Formatters.dataHoraBr(
                      DateTime.tryParse(_last!['timestamp'] ?? '')),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.mutedForeground),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_last!['identificador']} → ${_last!['estoqueNome']}',
              style: const TextStyle(fontSize: 13.5),
            ),
            Text('por ${_last!['usuario']}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.mutedForeground)),
          ],
        ),
      ),
    );
  }

  Widget _historyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vínculos anteriores (${_history.length - 1})',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ..._history.skip(1).take(20).map(
                  (h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${h['identificador'] ?? h['pecaId']} → ${h['estoqueNome']}',
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
