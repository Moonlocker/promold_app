import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/estoque.dart';
import '../../../providers/estoque_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../../../repositories/estoque_repository.dart';
import '../../../services/etiquetas_service.dart';
import '../widgets/estoque_form_sheet.dart';
import '../widgets/estoque_visual_editor.dart';
import '../widgets/vincular_peca_sheet.dart';

/// Módulo Estoque: cadastro de locais e mapa visual.
class EstoqueScreen extends ConsumerStatefulWidget {
  const EstoqueScreen({super.key});

  @override
  ConsumerState<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends ConsumerState<EstoqueScreen> {
  String _obraFiltro = 'all';
  String _pecaFiltro = 'all';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Estoque'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Cadastro'),
              Tab(text: 'Mapa'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _cadastroTab(),
            _mapaTab(),
          ],
        ),
      ),
    );
  }

  Widget _cadastroTab() {
    final estoquesAsync = ref.watch(estoquesProvider);
    final pecasAsync = ref.watch(pecasEmEstoqueProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await showEstoqueFormSheet(context, ref);
          if (ok == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Estoque cadastrado!')),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Estoque'),
      ),
      body: estoquesAsync.when(
        loading: () => const LoadingView(message: 'Carregando estoques...'),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (estoques) {
          final pecas = pecasAsync.value ?? const <PecaEmEstoque>[];
          final porEstoque = <String, List<PecaEmEstoque>>{};
          for (final p in pecas) {
            if (p.estoqueId == null) continue;
            porEstoque.putIfAbsent(p.estoqueId!, () => []).add(p);
          }

          final obras = <String, String>{};
          final tipos = <String, String>{};
          for (final p in pecas) {
            obras[p.obraId] = p.obraNome;
            tipos[p.pecaCatalogoId ?? ''] = p.pecaNome;
          }

          if (estoques.isEmpty) {
            return const EmptyState(
              icon: Icons.warehouse_outlined,
              title: 'Nenhum estoque cadastrado',
              message: 'Cadastre os locais de armazenamento da fábrica.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(estoquesProvider);
              ref.invalidate(pecasEmEstoqueProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _obraFiltro,
                        isDense: true,
                        decoration: const InputDecoration(
                            labelText: 'Filtrar por obra', isDense: true),
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('Todas')),
                          ...obras.entries.map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value,
                                    overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => _obraFiltro = v ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _pecaFiltro,
                        isDense: true,
                        decoration: const InputDecoration(
                            labelText: 'Filtrar por peça', isDense: true),
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('Todas')),
                          ...tipos.entries.map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value,
                                    overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => _pecaFiltro = v ?? 'all'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...estoques.map((e) => _EstoqueCard(
                      estoque: e,
                      pecas: (porEstoque[e.id] ?? const []).where((p) {
                        if (_obraFiltro != 'all' && p.obraId != _obraFiltro) {
                          return false;
                        }
                        if (_pecaFiltro != 'all' &&
                            p.pecaCatalogoId != _pecaFiltro) {
                          return false;
                        }
                        return true;
                      }).toList(),
                      onChanged: () {
                        ref.invalidate(estoquesProvider);
                        ref.invalidate(pecasEmEstoqueProvider);
                      },
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _mapaTab() {
    final estoquesAsync = ref.watch(estoquesProvider);
    final pecasAsync = ref.watch(pecasEmEstoqueProvider);
    final systemAsync = ref.watch(systemEstoqueIdProvider);

    return estoquesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (estoques) {
        if (estoques.isEmpty) {
          return const EmptyState(
            icon: Icons.map_outlined,
            title: 'Cadastre um estoque primeiro',
            message: 'O mapa usa os estoques cadastrados.',
          );
        }
        final pecas = pecasAsync.value ?? const <PecaEmEstoque>[];
        final porEstoque = <String, List<PecaEmEstoque>>{};
        for (final p in pecas) {
          if (p.estoqueId == null) continue;
          porEstoque.putIfAbsent(p.estoqueId!, () => []).add(p);
        }
        final alocadas = pecas.where((p) => p.estoqueId != null).length;

        return systemAsync.when(
          loading: () => const LoadingView(message: 'Carregando mapa...'),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (systemId) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Chip(label: Text('Em estoque: ${pecas.length}')),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('Alocadas: $alocadas'),
                      backgroundColor: AppColors.muted,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: EstoqueVisualEditor(
                  estoqueId: systemId,
                  estoques: estoques,
                  pecasByEstoque: porEstoque,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EstoqueCard extends ConsumerWidget {
  const _EstoqueCard({
    required this.estoque,
    required this.pecas,
    required this.onChanged,
  });

  final Estoque estoque;
  final List<PecaEmEstoque> pecas;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = pecas.length;
    final cap = estoque.capacidade;
    final ocupacao = (cap != null && cap > 0)
        ? ((count / cap) * 100).clamp(0, 100).toDouble()
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (estoque.imagemUrl != null)
                  GestureDetector(
                    onTap: () => _verImagem(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        estoque.imagemUrl!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 52,
                          height: 52,
                          color: AppColors.muted,
                          child: const Icon(Icons.warehouse_outlined),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warehouse_outlined,
                        color: AppColors.mutedForeground),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(estoque.nome,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      if (estoque.descricaoLimpa.isNotEmpty)
                        Text(estoque.descricaoLimpa,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.mutedForeground)),
                      const SizedBox(height: 6),
                      Text(
                        cap != null
                            ? '$count/$cap peças (${ocupacao!.round()}%)'
                            : '$count peças',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      if (ocupacao != null) ...[
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: ocupacao / 100,
                            minHeight: 6,
                            backgroundColor: AppColors.muted,
                            color: ocupacao > 90
                                ? AppColors.destructive
                                : ocupacao > 70
                                    ? AppColors.warning
                                    : AppColors.success,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => _acao(context, ref, v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'vincular', child: Text('Vincular peça')),
                    PopupMenuItem(value: 'qr', child: Text('QR Code')),
                    PopupMenuItem(value: 'imagem', child: Text('Imagem de referência')),
                    PopupMenuItem(value: 'duplicar', child: Text('Duplicar')),
                    PopupMenuItem(value: 'editar', child: Text('Editar')),
                    PopupMenuItem(
                      value: 'excluir',
                      child: Text('Excluir',
                          style: TextStyle(color: AppColors.destructive)),
                    ),
                  ],
                ),
              ],
            ),
            if (pecas.isNotEmpty) ...[
              const Divider(height: 20),
              ...pecas.take(8).map((p) => _pecaLinha(context, ref, p)),
              if (pecas.length > 8)
                TextButton(
                  onPressed: () => _verTodasPecas(context, ref),
                  child: Text('Ver todas (${pecas.length} peças)'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pecaLinha(BuildContext context, WidgetRef ref, PecaEmEstoque p) {
    final cor = p.obraCor != null ? _hex(p.obraCor!) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (cor != null)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
            ),
          Text(p.identificador,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(p.pecaNome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5)),
          ),
          Text(p.obraNome,
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.mutedForeground)),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Desvincular',
            onPressed: () async {
              await ref.read(estoqueRepositoryProvider).unlinkPeca(p.id);
              ref.invalidate(pecasEmEstoqueProvider);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _acao(BuildContext context, WidgetRef ref, String acao) async {
    final repo = ref.read(estoqueRepositoryProvider);
    switch (acao) {
      case 'vincular':
        final ok = await showVincularPecaSheet(context, ref, estoque: estoque);
        if (ok == true) onChanged();
      case 'qr':
        await EtiquetasService.imprimirQrEstoque(
          nome: estoque.nome,
          estoqueId: estoque.id,
        );
      case 'imagem':
        await _escolherImagem(context, ref, repo);
      case 'duplicar':
        await repo.duplicateEstoque(estoque);
        onChanged();
      case 'editar':
        final ok = await showEstoqueFormSheet(context, ref, estoque: estoque);
        if (ok == true) onChanged();
      case 'excluir':
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir estoque'),
            content: Text(
                'Excluir "${estoque.nome}"? As peças serão desvinculadas.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.destructive),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        );
        if (confirmar == true) {
          await repo.deleteEstoque(estoque.id);
          onChanged();
        }
    }
  }

  Future<void> _escolherImagem(
    BuildContext context,
    WidgetRef ref,
    EstoqueRepository repo,
  ) async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    try {
      final bytes = await files.first.readAsBytes();
      final ext = files.first.extension ?? 'jpg';
      final url = await repo.uploadImagemEstoque(
        estoqueId: estoque.id,
        bytes: bytes,
        extensao: ext,
      );
      await repo.setImagemEstoque(estoque.id, url, estoque.descricaoLimpa);
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  void _verImagem(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(estoque.imagemUrl!),
        ),
      ),
    );
  }

  void _verTodasPecas(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${estoque.nome} · ${pecas.length} peças'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: pecas
                .map((p) => ListTile(
                      dense: true,
                      title: Text('${p.identificador} · ${p.pecaNome}'),
                      subtitle: Text(p.obraNome,
                          style: const TextStyle(fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () async {
                          await ref
                              .read(estoqueRepositoryProvider)
                              .unlinkPeca(p.id);
                          ref.invalidate(pecasEmEstoqueProvider);
                        },
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  static Color? _hex(String hex) {
    final h = hex.replaceFirst('#', '');
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }
}
