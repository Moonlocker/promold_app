import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/peca_calc.dart';
import '../../../core/logic/status_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/peca_status_chip.dart';
import '../../../models/obra_peca.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../widgets/add_pecas_sheet.dart';
import '../widgets/obra_peca_edit_sheet.dart';
import '../../../services/etiquetas_service.dart';

/// Aba "Peças" — gestão das peças individuais da obra.
class ObraPecasTab extends ConsumerStatefulWidget {
  const ObraPecasTab({super.key, required this.obraId});

  final String obraId;

  @override
  ConsumerState<ObraPecasTab> createState() => _ObraPecasTabState();
}

class _ObraPecasTabState extends ConsumerState<ObraPecasTab> {
  final _busca = TextEditingController();
  String _categoria = 'all';
  bool _ocultarConcluidas = false;
  final Set<String> _selecionadas = {};

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pecasAsync = ref.watch(obrasPecasProvider(widget.obraId));
    final statusCfg =
        ref.watch(statusConfigProvider).value ?? StatusConfig.defaults;
    final filtroStatus = ref.watch(obraPecasFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final pecas = pecasAsync.value ?? const <ObraPeca>[];
          final ok = await showAddPecasSheet(
            context,
            ref,
            obraId: widget.obraId,
            existentes: pecas,
          );
          if (ok == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Peças adicionadas!')),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
      bottomNavigationBar:
          _selecionadas.isEmpty ? null : _barraSelecao(),
      body: pecasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (todas) {
          final termo = _busca.text.trim().toLowerCase();
          final filtradas = todas.where((p) {
            if (_ocultarConcluidas && p.status == 'montada') return false;
            if (_categoria != 'all' && p.pecaCatalogo?.categoriaId != _categoria) {
              return false;
            }
            if (filtroStatus != null &&
                normalizarStatus(p.status) != filtroStatus) {
              return false;
            }
            if (termo.isNotEmpty &&
                !p.nomePeca.toLowerCase().contains(termo) &&
                !p.identificador.toLowerCase().contains(termo)) {
              return false;
            }
            return true;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _busca,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Buscar peça ou código',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: _abrirFiltros,
                          icon: Badge(
                            isLabelVisible: filtroStatus != null ||
                                _categoria != 'all' ||
                                _ocultarConcluidas,
                            child: const Icon(Icons.tune),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${filtradas.length} de ${todas.length} peças',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const Spacer(),
                        if (filtroStatus != null)
                          ActionChip(
                            label: Text(statusLabel(filtroStatus)),
                            onPressed: () => ref
                                .read(obraPecasFilterProvider.notifier)
                                .set(null),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtradas.isEmpty
                    ? const EmptyState(
                        icon: Icons.extension_outlined,
                        title: 'Nenhuma peça encontrada',
                        message: 'Ajuste os filtros ou adicione peças.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(obrasPecasProvider(widget.obraId)),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          children: _agrupar(filtradas, statusCfg, todas),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _agrupar(
    List<ObraPeca> pecas,
    StatusConfig statusCfg,
    List<ObraPeca> todas,
  ) {
    final porCategoria = <String, List<ObraPeca>>{};
    for (final p in pecas) {
      final key = p.pecaCatalogo?.categoria?.nome ?? 'Sem categoria';
      porCategoria.putIfAbsent(key, () => []).add(p);
    }

    final widgets = <Widget>[];
    final categoriasOrdenadas = porCategoria.keys.toList()..sort();

    for (final cat in categoriasOrdenadas) {
      final lista = porCategoria[cat]!;
      final somaPeso = lista.fold<double>(
          0, (acc, p) => acc + statusCfg.weightOf(p.status));
      final pct = lista.isEmpty ? 0 : (somaPeso / lista.length).round();

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  cat.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              Text('${lista.length} · $pct%',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground)),
            ],
          ),
        ),
      );

      for (final p in lista) {
        widgets.add(
          _PecaCard(
            peca: p,
            statusCfg: statusCfg,
            selecionada: _selecionadas.contains(p.id),
            onToggleSelecao: () => setState(() {
              if (!_selecionadas.add(p.id)) _selecionadas.remove(p.id);
            }),
            onEditar: () => showPecaEditSheet(
              context,
              ref,
              peca: p,
              todas: todas,
            ),
            onAlterarStatus: (novo) => _alterarStatus(p, novo),
            onExcluir: () => _excluir(p),
            onEtiqueta: () => _imprimirEtiqueta(p),
          ),
        );
        widgets.add(const SizedBox(height: 10));
      }
    }
    return widgets;
  }

  Future<void> _alterarStatus(ObraPeca peca, String novoStatus) async {
    final update = _statusUpdate(peca, novoStatus);
    try {
      await ref.read(obrasRepositoryProvider).updatePeca(peca.id, update);
      ref.invalidate(obrasPecasProvider(widget.obraId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _excluir(ObraPeca peca) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir peça'),
        content: Text(
            'Deseja excluir a peça ${peca.identificador.isEmpty ? peca.nomePeca : peca.identificador}? Esta ação é permanente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ref.read(obrasRepositoryProvider).deletePeca(peca.id);
      ref.invalidate(obrasPecasProvider(widget.obraId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  List<ObraPeca> get _pecasSelecionadas {
    final todas = ref.read(obrasPecasProvider(widget.obraId)).value ?? const [];
    return todas.where((p) => _selecionadas.contains(p.id)).toList();
  }

  Map<String, dynamic> _statusUpdate(ObraPeca peca, String status) {
    final hoje = DateTime.now().toIso8601String().split('T').first;
    final update = <String, dynamic>{'status': status};
    void preencher(String campo, DateTime? atual) {
      if (atual == null) update[campo] = hoje;
    }

    switch (status) {
      case 'armada':
        preencher('data_armacao', peca.dataArmacao);
      case 'concretada':
        preencher('data_concretagem', peca.dataConcretagem);
      case 'em_estoque':
        preencher('data_concretagem', peca.dataConcretagem);
        preencher('data_estoque', peca.dataEstoque);
      case 'carregada':
        preencher('data_carregamento', peca.dataCarregamento);
      case 'montada':
        preencher('data_concretagem', peca.dataConcretagem);
        preencher('data_montagem', peca.dataMontagem);
    }
    return update;
  }

  Widget _barraSelecao() {
    return Material(
      color: AppColors.sidebar,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _selecionadas.clear()),
              ),
              Text(
                '${_selecionadas.length} selecionada(s)',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Alterar status',
                icon: const Icon(Icons.flag_outlined, color: Colors.white),
                onPressed: _bulkAlterarStatus,
              ),
              IconButton(
                tooltip: 'Editar campo',
                icon: const Icon(Icons.edit_note, color: Colors.white),
                onPressed: _bulkEditarCampo,
              ),
              IconButton(
                tooltip: 'Etiquetas QR',
                icon: const Icon(Icons.qr_code, color: Colors.white),
                onPressed: _bulkEtiquetas,
              ),
              IconButton(
                tooltip: 'Excluir',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: _bulkExcluir,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _escolherStatus() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Alterar status das peças',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ...statusSelecionaveis.map(
              (s) => ListTile(
                leading: CircleAvatar(
                  radius: 6,
                  backgroundColor:
                      (ref.read(statusConfigProvider).value ??
                              StatusConfig.defaults)
                          .colorOf(s),
                ),
                title: Text(statusLabel(s)),
                onTap: () => Navigator.pop(context, s),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bulkAlterarStatus() async {
    final status = await _escolherStatus();
    if (status == null) return;
    final repo = ref.read(obrasRepositoryProvider);
    for (final p in _pecasSelecionadas) {
      await repo.updatePeca(p.id, _statusUpdate(p, status));
    }
    ref.invalidate(obrasPecasProvider(widget.obraId));
    setState(() => _selecionadas.clear());
  }

  Future<void> _bulkEditarCampo() async {
    const campos = {
      'comprimento': 'Comprimento (m)',
      'largura': 'Largura (m)',
      'altura': 'Altura (m)',
      'volume_concreto_por_metro': 'Volume/m (m³/m)',
      'kg_aco_por_metro': 'Aço (kg/m³)',
      'observacoes': 'Observações',
      'data_armacao': 'Data armação',
      'data_concretagem': 'Data concretagem',
      'data_estoque': 'Data estoque',
      'data_carregamento': 'Data carregamento',
      'data_montagem': 'Data montagem',
    };
    var campo = 'comprimento';
    final valor = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final isData = campo.startsWith('data_');
          return AlertDialog(
            title: const Text('Editar em massa'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: campo,
                  decoration: const InputDecoration(labelText: 'Campo'),
                  items: campos.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (v) => setDialog(() => campo = v ?? 'comprimento'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valor,
                  keyboardType: isData
                      ? TextInputType.datetime
                      : const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: isData ? 'Valor (AAAA-MM-DD)' : 'Valor',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmar != true) return;

    final texto = valor.text.trim();
    dynamic convertido;
    if (campo.startsWith('data_')) {
      convertido = texto.isEmpty ? null : texto;
    } else if (campo == 'observacoes') {
      convertido = texto.isEmpty ? null : texto;
    } else {
      convertido = double.tryParse(texto.replaceAll(',', '.'));
    }

    final repo = ref.read(obrasRepositoryProvider);
    for (final p in _pecasSelecionadas) {
      await repo.updatePeca(p.id, {campo: convertido});
    }
    ref.invalidate(obrasPecasProvider(widget.obraId));
    setState(() => _selecionadas.clear());
  }

  Future<void> _bulkEtiquetas() async {
    final pecas = _pecasSelecionadas;
    if (pecas.isEmpty) return;
    final obraNome =
        ref.read(obraProvider(widget.obraId)).value?.nome ?? 'Obra';
    final posicoes =
        await ref.read(obraPosicoesProvider(widget.obraId).future);
    await EtiquetasService.imprimir(
      obraNome: obraNome,
      pecas: pecas,
      posicoes: posicoes,
    );
  }

  Future<void> _imprimirEtiqueta(ObraPeca peca) async {
    final obraNome =
        ref.read(obraProvider(widget.obraId)).value?.nome ?? 'Obra';
    final posicoes =
        await ref.read(obraPosicoesProvider(widget.obraId).future);
    await EtiquetasService.imprimir(
      obraNome: obraNome,
      pecas: [peca],
      posicoes: posicoes,
    );
  }

  Future<void> _bulkExcluir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir peças'),
        content: Text(
            'Excluir ${_selecionadas.length} peça(s) permanentemente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final repo = ref.read(obrasRepositoryProvider);
    for (final p in _pecasSelecionadas) {
      await repo.deletePeca(p.id);
    }
    ref.invalidate(obrasPecasProvider(widget.obraId));
    setState(() => _selecionadas.clear());
  }

  Future<void> _abrirFiltros() async {
    final categorias = ref.read(categoriasPecaProvider).value ?? const [];
    var categoria = _categoria;
    var status = ref.read(obraPecasFilterProvider);
    var ocultar = _ocultarConcluidas;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtros',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              const Text('Categoria', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: categoria,
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('Todas')),
                  ...categorias.map((c) =>
                      DropdownMenuItem(value: c.id, child: Text(c.nome))),
                ],
                onChanged: (v) => setSheet(() => categoria = v ?? 'all'),
              ),
              const SizedBox(height: 16),
              const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: statusSelecionaveis.map((s) {
                  final selected = status == s;
                  return ChoiceChip(
                    label: Text(statusLabel(s)),
                    selected: selected,
                    onSelected: (_) => setSheet(() => status = selected ? null : s),
                  );
                }).toList(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ocultar montadas'),
                value: ocultar,
                onChanged: (v) => setSheet(() => ocultar = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setSheet(() {
                          categoria = 'all';
                          status = null;
                          ocultar = false;
                        });
                      },
                      child: const Text('Limpar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _categoria = categoria;
                          _ocultarConcluidas = ocultar;
                        });
                        ref.read(obraPecasFilterProvider.notifier).set(status);
                        Navigator.pop(context);
                      },
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PecaCard extends StatelessWidget {
  const _PecaCard({
    required this.peca,
    required this.statusCfg,
    required this.selecionada,
    required this.onToggleSelecao,
    required this.onEditar,
    required this.onAlterarStatus,
    required this.onExcluir,
    required this.onEtiqueta,
  });

  final ObraPeca peca;
  final StatusConfig statusCfg;
  final bool selecionada;
  final VoidCallback onToggleSelecao;
  final VoidCallback onEditar;
  final ValueChanged<String> onAlterarStatus;
  final VoidCallback onExcluir;
  final VoidCallback onEtiqueta;

  @override
  Widget build(BuildContext context) {
    final calc = calcularPeca(peca);
    final tipo = tipoCalculoDaPeca(peca);

    String dimensoes;
    if (tipo == 'cilindrica') {
      dimensoes = 'Ø${_n(peca.diametro)} × ${_n(peca.comprimento)}m';
    } else if (tipo == 'nao_linear') {
      dimensoes = '${_n(peca.comprimento)}m · ${_n(peca.volumeConcretoPorMetro)} m³/m';
    } else {
      dimensoes =
          '${_n(peca.largura)} × ${_n(peca.altura)} × ${_n(peca.comprimento)}m';
    }

    return Card(
      child: InkWell(
        onTap: onEditar,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: selecionada,
                      onChanged: (_) => onToggleSelecao(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    peca.identificador.isEmpty ? '—' : peca.identificador,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: peca.isProtendido
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      peca.tipoConcretoLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: peca.isProtendido
                            ? const Color(0xFF7C3AED)
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _mostrarMenuStatus(context),
                    child: PecaStatusChip(
                      status: peca.status,
                      colors: statusCfg.colors,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) {
                      if (v == 'editar') onEditar();
                      if (v == 'etiqueta') onEtiqueta();
                      if (v == 'excluir') onExcluir();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(
                          value: 'etiqueta', child: Text('Etiqueta QR')),
                      PopupMenuItem(
                        value: 'excluir',
                        child: Text('Excluir',
                            style: TextStyle(color: AppColors.destructive)),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                peca.nomePeca,
                style: const TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _info(Icons.straighten, dimensoes),
                  if (calc.volume > 0)
                    _info(Icons.view_in_ar_outlined,
                        '${round3(calc.volume).toStringAsFixed(3)} m³'),
                  if (calc.aco > 0)
                    _info(Icons.construction_outlined,
                        '${calc.aco.toStringAsFixed(1)} kg'),
                  if (calc.peso > 0)
                    _info(
                      Icons.scale_outlined,
                      calc.peso >= 1000
                          ? '${(calc.peso / 1000).toStringAsFixed(2)} t'
                          : '${calc.peso.toStringAsFixed(0)} kg',
                    ),
                ],
              ),
              if (_dataStatus() != null) ...[
                const SizedBox(height: 6),
                _info(Icons.event_outlined, Formatters.dataBr(_dataStatus())),
              ],
            ],
          ),
        ),
      ),
    );
  }

  DateTime? _dataStatus() {
    return switch (normalizarStatus(peca.status)) {
      'armada' => peca.dataArmacao,
      'concretada' => peca.dataConcretagem,
      'em_estoque' => peca.dataEstoque,
      'carregada' => peca.dataCarregamento,
      'montada' => peca.dataMontagem,
      _ => null,
    };
  }

  static String _n(num? v) => v == null ? '—' : v.toString();

  Widget _info(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.mutedForeground),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.mutedForeground)),
      ],
    );
  }

  void _mostrarMenuStatus(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Alterar status',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ...statusSelecionaveis.map((s) {
              final selected = normalizarStatus(peca.status) == s;
              return ListTile(
                leading: CircleAvatar(
                  radius: 6,
                  backgroundColor: statusCfg.colorOf(s),
                ),
                title: Text(statusLabel(s)),
                trailing: selected ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.pop(context);
                  if (!selected) onAlterarStatus(s);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
