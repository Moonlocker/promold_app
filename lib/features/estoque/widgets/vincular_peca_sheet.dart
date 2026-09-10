import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/estoque.dart';
import '../../../providers/estoque_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Seleciona uma peça sem local para vincular ao estoque informado.
Future<bool?> showVincularPecaSheet(
  BuildContext context,
  WidgetRef ref, {
  required Estoque estoque,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _VincularPecaSheet(estoque: estoque),
  );
}

class _VincularPecaSheet extends ConsumerStatefulWidget {
  const _VincularPecaSheet({required this.estoque});

  final Estoque estoque;

  @override
  ConsumerState<_VincularPecaSheet> createState() => _VincularPecaSheetState();
}

class _VincularPecaSheetState extends ConsumerState<_VincularPecaSheet> {
  final _busca = TextEditingController();
  String _obra = 'all';
  String _peca = 'all';
  bool _salvando = false;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pecasAsync = ref.watch(pecasEmEstoqueProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final height = MediaQuery.of(context).size.height * 0.85;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 12 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Vincular peça · ${widget.estoque.nome}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _busca,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Buscar identificador ou peça',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            pecasAsync.when(
              loading: () => const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Expanded(child: Center(child: Text('Erro: $e'))),
              data: (todas) {
                final disponiveis =
                    todas.where((p) => p.estoqueId == null).toList();
                final obras = <String, String>{};
                final pecas = <String, String>{};
                for (final p in disponiveis) {
                  obras[p.obraId] = p.obraNome;
                  pecas[p.pecaCatalogoId ?? ''] = p.pecaNome;
                }
                final termo = _busca.text.trim().toLowerCase();
                final filtradas = disponiveis.where((p) {
                  if (_obra != 'all' && p.obraId != _obra) return false;
                  if (_peca != 'all' && p.pecaCatalogoId != _peca) return false;
                  if (widget.estoque.categoriasPermitidas != null &&
                      widget.estoque.categoriasPermitidas!.isNotEmpty &&
                      !widget.estoque.categoriasPermitidas!
                          .contains(p.categoriaId)) {
                    return false;
                  }
                  if (widget.estoque.pecasPermitidas != null &&
                      widget.estoque.pecasPermitidas!.isNotEmpty &&
                      !widget.estoque.pecasPermitidas!
                          .contains(p.pecaCatalogoId)) {
                    return false;
                  }
                  if (termo.isEmpty) return true;
                  return p.identificador.toLowerCase().contains(termo) ||
                      p.pecaNome.toLowerCase().contains(termo);
                }).toList();

                return Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _obra,
                              isDense: true,
                              decoration:
                                  const InputDecoration(labelText: 'Obra'),
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
                                  setState(() => _obra = v ?? 'all'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _peca,
                              isDense: true,
                              decoration:
                                  const InputDecoration(labelText: 'Peça'),
                              items: [
                                const DropdownMenuItem(
                                    value: 'all', child: Text('Todas')),
                                ...pecas.entries.map((e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value,
                                          overflow: TextOverflow.ellipsis),
                                    )),
                              ],
                              onChanged: (v) =>
                                  setState(() => _peca = v ?? 'all'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtradas.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nenhuma peça disponível para vincular',
                                  style: TextStyle(
                                      color: AppColors.mutedForeground),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtradas.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final p = filtradas[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      '${p.identificador} · ${p.pecaNome}',
                                    ),
                                    subtitle: Text(
                                      p.obraNome,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onTap: _salvando
                                        ? null
                                        : () => _vincular(p.id),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _vincular(String pecaId) async {
    setState(() => _salvando = true);
    try {
      await ref
          .read(estoqueRepositoryProvider)
          .linkPeca(pecaId, widget.estoque.id);
      ref.invalidate(pecasEmEstoqueProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }
}
