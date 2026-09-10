import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/obra_peca.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Abre o seletor de peças do catálogo para adicionar à obra.
Future<bool?> showAddPecasSheet(
  BuildContext context,
  WidgetRef ref, {
  required String obraId,
  required List<ObraPeca> existentes,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AddPecasSheet(obraId: obraId, existentes: existentes),
  );
}

class _AddPecasSheet extends ConsumerStatefulWidget {
  const _AddPecasSheet({required this.obraId, required this.existentes});

  final String obraId;
  final List<ObraPeca> existentes;

  @override
  ConsumerState<_AddPecasSheet> createState() => _AddPecasSheetState();
}

class _AddPecasSheetState extends ConsumerState<_AddPecasSheet> {
  final _busca = TextEditingController();
  final Map<String, int> _selecionadas = {};
  String _categoria = 'all';
  bool _saving = false;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  int _proximoSequencial(String prefixo) {
    final regex = RegExp('^${RegExp.escape(prefixo)}-?(\\d+)\$');
    var max = 0;
    for (final p in widget.existentes) {
      final m = regex.firstMatch(p.identificador);
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > max) max = n;
      }
    }
    return max;
  }

  Future<void> _salvar() async {
    if (_selecionadas.isEmpty) return;
    setState(() => _saving = true);

    final catalogo = await ref.read(pecasCatalogoProvider.future);
    final rows = <Map<String, dynamic>>[];

    for (final entry in _selecionadas.entries) {
      final pc = catalogo.firstWhere((c) => c.id == entry.key);
      final prefixo =
          (pc.identificadorPadrao?.trim().isNotEmpty ?? false)
              ? pc.identificadorPadrao!.trim()
              : 'P';
      var seq = _proximoSequencial(prefixo);
      final isLinear = (pc.larguraPadrao ?? 0) > 0 || (pc.alturaPadrao ?? 0) > 0;

      for (var i = 0; i < entry.value; i++) {
        seq++;
        final row = <String, dynamic>{
          'obra_id': widget.obraId,
          'peca_catalogo_id': pc.id,
          'identificador': '$prefixo-${seq.toString().padLeft(2, '0')}',
          'status': 'pendente',
        };
        if (isLinear) {
          row['largura'] = pc.larguraPadrao;
          row['altura'] = pc.alturaPadrao;
          row['comprimento'] = pc.comprimentoPadrao;
        } else {
          row['comprimento'] = pc.comprimentoPadrao;
          row['volume_concreto_por_metro'] = pc.volumeConcretoPorMetro;
        }
        if (pc.kgAcoPorMetro != null) row['kg_aco_por_metro'] = pc.kgAcoPorMetro;
        rows.add(row);
      }
    }

    try {
      await ref.read(obrasRepositoryProvider).createPecas(rows);
      ref.invalidate(obrasPecasProvider(widget.obraId));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao adicionar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogoAsync = ref.watch(pecasCatalogoProvider);
    final categoriasAsync = ref.watch(categoriasPecaProvider);
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
                const Text(
                  'Adicionar peças',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
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
                hintText: 'Buscar peça do catálogo',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            categoriasAsync.maybeWhen(
              data: (cats) => DropdownButtonFormField<String>(
                initialValue: _categoria,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('Todas')),
                  ...cats.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.nome),
                      )),
                ],
                onChanged: (v) => setState(() => _categoria = v ?? 'all'),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: catalogoAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro: $e')),
                data: (catalogo) {
                  final termo = _busca.text.trim().toLowerCase();
                  final filtrado = catalogo.where((c) {
                    if (!c.ativa) return false;
                    if (_categoria != 'all' && c.categoriaId != _categoria) {
                      return false;
                    }
                    if (termo.isNotEmpty &&
                        !c.nome.toLowerCase().contains(termo)) {
                      return false;
                    }
                    return true;
                  }).toList();

                  if (filtrado.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhuma peça encontrada',
                        style: TextStyle(color: AppColors.mutedForeground),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtrado.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final pc = filtrado[index];
                      final qtd = _selecionadas[pc.id] ?? 0;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(pc.nome),
                        subtitle: Text(
                          '${pc.categoria?.nome ?? 'Sem categoria'} · ${pc.tipoConcretoLabel}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: qtd == 0
                            ? OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => setState(
                                        () => _selecionadas[pc.id] = 1),
                                child: const Text('Adicionar'),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: _saving
                                        ? null
                                        : () => setState(() {
                                              if (qtd <= 1) {
                                                _selecionadas.remove(pc.id);
                                              } else {
                                                _selecionadas[pc.id] = qtd - 1;
                                              }
                                            }),
                                  ),
                                  Text('$qtd',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: _saving
                                        ? null
                                        : () => setState(
                                            () => _selecionadas[pc.id] = qtd + 1),
                                  ),
                                ],
                              ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed:
                  (_saving || _selecionadas.isEmpty) ? null : _salvar,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Adicionar ${_selecionadas.values.fold(0, (a, b) => a + b)} peça(s)'),
            ),
          ],
        ),
      ),
    );
  }
}
