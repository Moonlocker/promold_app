import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/simple_form_sheet.dart';
import '../../../models/mapa_montagem.dart';
import '../../../models/obra_peca.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Aba "Visual": mapa de montagem 2D por vistas (grade de posições).
class ObraVisualTab extends ConsumerWidget {
  const ObraVisualTab({super.key, required this.obraId});

  final String obraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(obraMapaVistasProvider(obraId));
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (vistas) {
        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _novaVista(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Nova Vista'),
          ),
          body: vistas.isEmpty
              ? const EmptyState(
                  icon: Icons.grid_view_outlined,
                  title: 'Nenhuma vista',
                  message:
                      'Crie uma vista para posicionar as peças no mapa de montagem.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: vistas.length,
                  itemBuilder: (context, i) {
                    final v = vistas[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.grid_view_outlined,
                              size: 18, color: AppColors.primary),
                        ),
                        title: Text(v.nome,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${v.linhas} × ${v.colunas}${v.descricao != null && v.descricao!.isNotEmpty ? ' · ${v.descricao}' : ''}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (a) async {
                            if (a == 'excluir') {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Excluir vista'),
                                  content: Text('Excluir "${v.nome}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                          backgroundColor:
                                              AppColors.destructive),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Excluir'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await ref
                                    .read(mapaMontagemRepositoryProvider)
                                    .deleteVista(v.id);
                                ref.invalidate(obraMapaVistasProvider(obraId));
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'excluir',
                                child: Text('Excluir',
                                    style: TextStyle(
                                        color: AppColors.destructive))),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _MapaEditorScreen(
                              obraId: obraId,
                              vista: v,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _novaVista(BuildContext context, WidgetRef ref) async {
    final result = await showSimpleFormSheet(
      context,
      title: 'Nova Vista',
      submitLabel: 'Criar',
      fields: const [
        SimpleField(key: 'nome', label: 'Nome *', required: true),
        SimpleField(
            key: 'linhas',
            label: 'Linhas',
            initial: '6',
            keyboardType: TextInputType.number),
        SimpleField(
            key: 'colunas',
            label: 'Colunas',
            initial: '6',
            keyboardType: TextInputType.number),
      ],
    );
    if (result == null) return;
    await ref.read(mapaMontagemRepositoryProvider).createVista(obraId, {
      'nome': result['nome'],
      'linhas': int.tryParse(result['linhas'] ?? '') ?? 6,
      'colunas': int.tryParse(result['colunas'] ?? '') ?? 6,
      'tipo': 'grade',
    });
    ref.invalidate(obraMapaVistasProvider(obraId));
  }
}

class _MapaEditorScreen extends ConsumerStatefulWidget {
  const _MapaEditorScreen({required this.obraId, required this.vista});

  final String obraId;
  final MapaMontagemVista vista;

  @override
  ConsumerState<_MapaEditorScreen> createState() => _MapaEditorScreenState();
}

class _MapaEditorScreenState extends ConsumerState<_MapaEditorScreen> {
  final Map<String, MapaMontagemCelula> _celulas = {};
  bool _carregado = false;
  bool _salvando = false;

  String _key(int l, int c) => '$l:$c';

  @override
  Widget build(BuildContext context) {
    final pecasAsync = ref.watch(obrasPecasProvider(widget.obraId));
    final celulasAsync = ref.watch(obraMapaCelulasProvider(widget.vista.id));
    final statusConfig =
        ref.watch(statusConfigProvider).value ?? StatusConfig.defaults;
    final pecas = pecasAsync.value ?? const <ObraPeca>[];

    if (!_carregado && celulasAsync.hasValue) {
      for (final c in celulasAsync.value!) {
        _celulas[_key(c.linha, c.coluna)] = c;
      }
      _carregado = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vista.nome),
        actions: [
          TextButton(
            onPressed: _salvando ? null : _salvar,
            child: Text(_salvando ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
      body: pecasAsync.isLoading
          ? const LoadingView()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Toque em uma célula para posicionar uma peça.',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.mutedForeground),
                        ),
                      ),
                      Text('${_celulas.values.where((c) => !c.vazia).length} posicionadas',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: _grade(pecas, statusConfig),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _grade(List<ObraPeca> pecas, StatusConfig statusConfig) {
    final linhas = widget.vista.linhas;
    final colunas = widget.vista.colunas;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: linhas * colunas,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: colunas,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final l = index ~/ colunas;
        final c = index % colunas;
        final celula = _celulas[_key(l, c)];
        final peca = celula?.obraPecaId != null
            ? pecas.where((p) => p.id == celula!.obraPecaId).firstOrNull
            : null;
        final cor = peca != null
            ? statusConfig.colorOf(peca.status)
            : AppColors.muted;
        return InkWell(
          onTap: () => _escolher(l, c, pecas, statusConfig),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: peca != null
                  ? cor.withValues(alpha: 0.15)
                  : AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: peca != null ? cor : AppColors.border,
                width: peca != null ? 1.6 : 1,
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Center(
              child: Text(
                peca?.identificador ?? celula?.identificador ?? '+',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: peca != null
                      ? AppColors.foreground
                      : AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _escolher(
    int linha,
    int coluna,
    List<ObraPeca> pecas,
    StatusConfig statusConfig,
  ) async {
    final atual = _celulas[_key(linha, coluna)];
    final selecionada = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PecaPicker(pecas: pecas, statusConfig: statusConfig),
    );
    if (selecionada == null) return;
    setState(() {
      if (selecionada == '__clear__') {
        _celulas.remove(_key(linha, coluna));
      } else {
        final peca = pecas.where((p) => p.id == selecionada).firstOrNull;
        if (peca == null) return;
        _celulas[_key(linha, coluna)] = MapaMontagemCelula(
          linha: linha,
          coluna: coluna,
          obraPecaId: peca.id,
          pecaCatalogoId: peca.pecaCatalogoId,
          identificador: peca.identificador,
          status: peca.status,
        );
      }
      if (atual != null && atual.obraPecaId == selecionada) return;
    });
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await ref.read(mapaMontagemRepositoryProvider).saveCelulas(
            widget.vista.id,
            widget.obraId,
            _celulas.values.toList(),
          );
      ref.invalidate(obraMapaCelulasProvider(widget.vista.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mapa salvo!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
}

class _PecaPicker extends StatefulWidget {
  const _PecaPicker({required this.pecas, required this.statusConfig});

  final List<ObraPeca> pecas;
  final StatusConfig statusConfig;

  @override
  State<_PecaPicker> createState() => _PecaPickerState();
}

class _PecaPickerState extends State<_PecaPicker> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final filtradas = widget.pecas
        .where((p) =>
            p.identificador.toLowerCase().contains(_busca.toLowerCase()) ||
            p.nomePeca.toLowerCase().contains(_busca.toLowerCase()))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Escolher peça',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, '__clear__'),
                  child: const Text('Limpar célula'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _busca = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Buscar peça...',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: filtradas.length,
              itemBuilder: (context, i) {
                final p = filtradas[i];
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 10,
                    height: 30,
                    decoration: BoxDecoration(
                      color: widget.statusConfig.colorOf(p.status),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  title: Text(p.identificador,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(p.nomePeca,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context, p.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
