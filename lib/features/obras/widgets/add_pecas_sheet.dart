import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/obra_peca.dart';
import '../../../models/peca_catalogo.dart';
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
  final Set<String> _fechadas = {};
  String _categoria = 'all';
  bool _saving = false;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  int _totalSelecionado() =>
      _selecionadas.values.fold(0, (a, b) => a + b);

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
      final isLinear =
          (pc.larguraPadrao ?? 0) > 0 || (pc.alturaPadrao ?? 0) > 0;

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

  void _add(String id) => setState(() {
        _selecionadas[id] = (_selecionadas[id] ?? 0) + 1;
      });

  void _remove(String id) => setState(() {
        final q = _selecionadas[id] ?? 0;
        if (q <= 1) {
          _selecionadas.remove(id);
        } else {
          _selecionadas[id] = q - 1;
        }
      });

  @override
  Widget build(BuildContext context) {
    final catalogoAsync = ref.watch(pecasCatalogoProvider);
    final categoriasAsync = ref.watch(categoriasPecaProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final height = MediaQuery.of(context).size.height * 0.9;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 12 + bottom + safeBottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Adicionar peças',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
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
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('Todas')),
                  ...cats.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.nome, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) => setState(() => _categoria = v ?? 'all'),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: catalogoAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro: $e')),
                data: (catalogo) => _lista(catalogo),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: (_saving || _selecionadas.isEmpty) ? null : _salvar,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text('Adicionar ${_totalSelecionado()} peça(s)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista(List<PecaCatalogo> catalogo) {
    final termo = _busca.text.trim().toLowerCase();
    final filtrado = catalogo.where((c) {
      if (!c.ativa) return false;
      if (_categoria != 'all' && c.categoriaId != _categoria) return false;
      if (termo.isNotEmpty && !c.nome.toLowerCase().contains(termo)) {
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

    final porCategoria = <String, List<PecaCatalogo>>{};
    for (final c in filtrado) {
      final key = c.categoria?.nome ?? 'Sem categoria';
      porCategoria.putIfAbsent(key, () => []).add(c);
    }
    final cats = porCategoria.keys.toList()..sort();

    return ListView(
      children: [
        for (final cat in cats) ...[
          _grupoHeader(cat, porCategoria[cat]!.length),
          if (!_fechadas.contains(cat))
            for (final pc in porCategoria[cat]!) _item(pc),
        ],
      ],
    );
  }

  Widget _grupoHeader(String cat, int total) {
    final aberta = !_fechadas.contains(cat);
    return InkWell(
      onTap: () => setState(() {
        if (aberta) {
          _fechadas.add(cat);
        } else {
          _fechadas.remove(cat);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(aberta ? Icons.expand_more : Icons.chevron_right,
                size: 20, color: AppColors.mutedForeground),
            const SizedBox(width: 4),
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
            Text('$total',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.mutedForeground)),
          ],
        ),
      ),
    );
  }

  Widget _item(PecaCatalogo pc) {
    final qtd = _selecionadas[pc.id] ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pc.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pc.categoria?.nome ?? 'Sem categoria'} · ${pc.tipoConcretoLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (qtd == 0)
            OutlinedButton(
              onPressed: _saving ? null : () => _add(pc.id),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Adicionar'),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _saving ? null : () => _remove(pc.id),
                ),
                Text('$qtd',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _saving ? null : () => _add(pc.id),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
