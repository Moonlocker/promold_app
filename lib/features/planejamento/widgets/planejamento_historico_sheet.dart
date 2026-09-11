import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/supabase_providers.dart';

/// Abre a folha de histórico e ocorrências do planejamento da obra.
Future<void> showPlanejamentoHistoricoSheet(
  BuildContext context, {
  required String obraId,
  required String tipo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PlanejamentoHistoricoSheet(obraId: obraId, tipo: tipo),
  );
}

const _acaoLabel = {
  'criado': 'Criado',
  'movido': 'Movido',
  'reagendado_peca': 'Peça reagendada',
  'data_alterada': 'Data alterada',
  'excluido': 'Excluído',
  'editado': 'Editado',
  'ocorrencia': 'Ocorrência',
};

const _tipoLabel = {
  'armacao': 'Armação',
  'producao': 'Produção',
  'montagem': 'Montagem',
};

class _PlanejamentoHistoricoSheet extends ConsumerStatefulWidget {
  const _PlanejamentoHistoricoSheet({
    required this.obraId,
    required this.tipo,
  });

  final String obraId;
  final String tipo;

  @override
  ConsumerState<_PlanejamentoHistoricoSheet> createState() =>
      _PlanejamentoHistoricoSheetState();
}

class _PlanejamentoHistoricoSheetState
    extends ConsumerState<_PlanejamentoHistoricoSheet> {
  final _ocorrencia = TextEditingController();
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _ocorrencia.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final logs = await ref
          .read(producaoRepositoryProvider)
          .listPlanejamentoLogs(obraId: widget.obraId, tipo: widget.tipo);
      if (mounted) setState(() => _logs = logs);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _adicionar() async {
    if (_ocorrencia.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(producaoRepositoryProvider).addPlanejamentoLog(
            tipo: widget.tipo,
            obraId: widget.obraId,
            acao: 'ocorrencia',
            descricao: _ocorrencia.text.trim(),
          );
      _ocorrencia.clear();
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Histórico · ${_tipoLabel[widget.tipo] ?? widget.tipo}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _logs.isEmpty
                      ? const Center(
                          child: Text('Sem registros para esta obra.',
                              style: TextStyle(
                                  color: AppColors.mutedForeground)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _logs.length,
                          itemBuilder: (context, i) {
                            final l = _logs[i];
                            final acao = l['acao'] as String? ?? '';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _acaoLabel[acao] ?? acao,
                                      style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if ((l['descricao'] as String?)
                                                ?.isNotEmpty ==
                                            true)
                                          Text(l['descricao'] as String,
                                              style: const TextStyle(
                                                  fontSize: 12.5)),
                                        Text(
                                          l['created_at'] != null
                                              ? Formatters.dataHoraBr(
                                                  DateTime.tryParse(
                                                      l['created_at'] as String))
                                              : '',
                                          style: const TextStyle(
                                              fontSize: 10.5,
                                              color:
                                                  AppColors.mutedForeground),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 16,
                                        color: AppColors.destructive),
                                    onPressed: () async {
                                      await ref
                                          .read(producaoRepositoryProvider)
                                          .deletePlanejamentoLog(
                                              l['id'] as String);
                                      await _carregar();
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Adicionar ocorrência',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _ocorrencia,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          hintText: 'Chuva, queda de energia, acidente...'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _saving ? null : _adicionar,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                          _saving ? 'Salvando...' : 'Registrar ocorrência'),
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
