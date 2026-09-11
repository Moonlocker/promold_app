import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/peca_calc.dart';
import '../../../core/logic/status_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/peca_status_chip.dart';
import '../../../models/obra_peca.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/planejamento_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Abre a folha "Adicionar ao Planejamento". Retorna `true` se salvou.
Future<bool?> showPlanejarSheet(
  BuildContext context,
  WidgetRef ref, {
  required String tipo,
  required DateTime diaInicial,
  String? obraIdInicial,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PlanejarSheet(
      tipo: tipo,
      diaInicial: diaInicial,
      obraIdInicial: obraIdInicial,
    ),
  );
}

class _PlanejarSheet extends ConsumerStatefulWidget {
  const _PlanejarSheet({
    required this.tipo,
    required this.diaInicial,
    this.obraIdInicial,
  });

  final String tipo;
  final DateTime diaInicial;
  final String? obraIdInicial;

  @override
  ConsumerState<_PlanejarSheet> createState() => _PlanejarSheetState();
}

class _PlanejarSheetState extends ConsumerState<_PlanejarSheet> {
  late DateTime _dia = widget.diaInicial;
  String? _obraId;
  late String _statusFiltro = widget.tipo == 'armacao' ? 'pendente' : 'armada';
  String _busca = '';
  final Set<String> _selecionadas = {};
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _obraId = widget.obraIdInicial;
  }

  @override
  Widget build(BuildContext context) {
    final obras = ref.watch(obrasListProvider).value ?? const [];
    final obrasAtivas = obras.where((o) => o.status == 'ativa').toList();
    final diaStr = Formatters.iso(_dia);
    final existentes =
        ref
            .watch(planejamentoDiaExistenteProvider((diaStr, widget.tipo)))
            .value ??
        const <String>{};
    final pecasAsync = _obraId != null
        ? ref.watch(obrasPecasProvider(_obraId!))
        : null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Adicionar ao Planejamento',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _DataSelector(
                    dia: _dia,
                    onTap: () async {
                      final escolhido = await showDatePicker(
                        context: context,
                        initialDate: _dia,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        locale: const Locale('pt', 'BR'),
                      );
                      if (escolhido != null) {
                        setState(() {
                          _dia = escolhido;
                          _selecionadas.clear();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _obraId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Obra',
                      isDense: true,
                    ),
                    items: [
                      for (final o in obrasAtivas)
                        DropdownMenuItem(value: o.id, child: Text(o.nome)),
                    ],
                    onChanged: (v) => setState(() {
                      _obraId = v;
                      _selecionadas.clear();
                    }),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          children: [
                            for (final s in const [
                              'pendente',
                              'armada',
                              'todas',
                            ])
                              ChoiceChip(
                                label: Text(
                                  s == 'todas' ? 'Todas' : statusLabel(s),
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                                selected: _statusFiltro == s,
                                onSelected: (_) =>
                                    setState(() => _statusFiltro = s),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _busca = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 20),
                      hintText: 'Buscar peça...',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_obraId == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Selecione uma obra para listar as peças.',
                          style: TextStyle(color: AppColors.mutedForeground),
                        ),
                      ),
                    )
                  else
                    pecasAsync!.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: Text('Erro: $e')),
                      ),
                      data: (pecas) => _ListaPecas(
                        pecas: pecas,
                        existentes: existentes,
                        statusFiltro: _statusFiltro,
                        busca: _busca,
                        selecionadas: _selecionadas,
                        onToggle: (id, marcado) => setState(() {
                          if (marcado) {
                            _selecionadas.add(id);
                          } else {
                            _selecionadas.remove(id);
                          }
                        }),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton.icon(
                  onPressed: (_selecionadas.isEmpty || _salvando)
                      ? null
                      : () => _salvar(pecasAsync),
                  icon: _salvando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _salvando
                        ? 'Salvando...'
                        : 'Planejar (${_selecionadas.length})',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvar(AsyncValue<List<ObraPeca>>? pecasAsync) async {
    final pecas = pecasAsync?.value;
    if (pecas == null || _obraId == null) return;
    setState(() => _salvando = true);
    final repo = ref.read(producaoRepositoryProvider);
    final diaStr = Formatters.iso(_dia);
    try {
      for (final id in _selecionadas) {
        ObraPeca? piece;
        for (final p in pecas) {
          if (p.id == id) {
            piece = p;
            break;
          }
        }
        if (piece == null || piece.pecaCatalogoId == null) continue;
        await repo.criarPlanejamento(
          data: diaStr,
          obraId: _obraId!,
          pecaCatalogoId: piece.pecaCatalogoId!,
          obraPecaId: piece.id,
          tipo: widget.tipo,
        );
      }
      ref.invalidate(planejamentoDadosProvider);
      ref.invalidate(planejamentoDiaExistenteProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao planejar: $e')));
      }
    }
  }
}

class _DataSelector extends StatelessWidget {
  const _DataSelector({required this.dia, required this.onTap});

  final DateTime dia;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                Formatters.dataBr(dia),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
      ),
    );
  }
}

class _ListaPecas extends StatelessWidget {
  const _ListaPecas({
    required this.pecas,
    required this.existentes,
    required this.statusFiltro,
    required this.busca,
    required this.selecionadas,
    required this.onToggle,
  });

  final List<ObraPeca> pecas;
  final Set<String> existentes;
  final String statusFiltro;
  final String busca;
  final Set<String> selecionadas;
  final void Function(String id, bool marcado) onToggle;

  bool _statusOk(String status) {
    if (statusFiltro == 'todas') {
      return status == 'pendente' || status == 'armada';
    }
    return status == statusFiltro;
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = pecas.where((p) {
      if (existentes.contains(p.id)) return false;
      if (!_statusOk(p.status)) return false;
      if (busca.trim().isNotEmpty) {
        final q = busca.toLowerCase();
        final ok =
            p.identificador.toLowerCase().contains(q) ||
            (p.pecaCatalogo?.nome.toLowerCase().contains(q) ?? false);
        if (!ok) return false;
      }
      return true;
    }).toList();

    if (filtradas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'Nenhuma peça disponível com esses filtros.',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final p in filtradas)
          CheckboxListTile(
            value: selecionadas.contains(p.id),
            onChanged: (v) => onToggle(p.id, v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Text(
                  p.identificador.isEmpty ? '—' : p.identificador,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.pecaCatalogo?.nome ?? 'Peça',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  PecaStatusChip(status: p.status, compact: true),
                  const SizedBox(width: 8),
                  Text(_dims(p), style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _dims(ObraPeca p) {
    final calc = calcularPeca(p);
    return '${Formatters.numero(calc.volume, 3)} m³';
  }
}
