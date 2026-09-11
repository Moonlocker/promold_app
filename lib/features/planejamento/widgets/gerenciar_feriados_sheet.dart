import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/feriado.dart';
import '../../../providers/feriados_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Abre a folha de gerenciamento de feriados.
Future<void> showGerenciarFeriadosSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _GerenciarFeriadosSheet(),
  );
}

class _GerenciarFeriadosSheet extends ConsumerStatefulWidget {
  const _GerenciarFeriadosSheet();

  @override
  ConsumerState<_GerenciarFeriadosSheet> createState() =>
      _GerenciarFeriadosSheetState();
}

class _GerenciarFeriadosSheetState
    extends ConsumerState<_GerenciarFeriadosSheet> {
  final _nome = TextEditingController();
  final _municipio = TextEditingController();
  String _tipo = 'nacional_pontual';
  DateTime? _data;
  bool _saving = false;

  bool get _recorrente =>
      _tipo == 'nacional_fixo' || _tipo == 'municipal';

  @override
  void dispose() {
    _nome.dispose();
    _municipio.dispose();
    super.dispose();
  }

  Future<void> _adicionar() async {
    if (_nome.text.trim().isEmpty || _data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe nome e data')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(feriadosRepositoryProvider).create({
        'nome': _nome.text.trim(),
        'data': Formatters.iso(_data!),
        'tipo': _tipo,
        'recorrente': _recorrente,
        'municipio':
            _tipo == 'municipal' && _municipio.text.trim().isNotEmpty
                ? _municipio.text.trim()
                : null,
      });
      _nome.clear();
      _municipio.clear();
      _data = null;
      ref.invalidate(feriadosProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feriado cadastrado')),
        );
      }
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
    final async = ref.watch(feriadosProvider);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
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
                  const Expanded(
                    child: Text('Gerenciar Feriados',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Feriados aparecem destacados no planejamento, mas não bloqueiam a produção.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.mutedForeground),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  TextField(
                    controller: _nome,
                    decoration: const InputDecoration(
                        labelText: 'Nome *', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _tipo,
                          isDense: true,
                          decoration: const InputDecoration(
                              labelText: 'Tipo', isDense: true),
                          items: const [
                            DropdownMenuItem(
                                value: 'nacional_fixo',
                                child: Text('Nacional (fixo)')),
                            DropdownMenuItem(
                                value: 'nacional_pontual',
                                child: Text('Nacional (pontual)')),
                            DropdownMenuItem(
                                value: 'municipal', child: Text('Municipal')),
                          ],
                          onChanged: (v) =>
                              setState(() => _tipo = v ?? 'nacional_pontual'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _data ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _data = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Data *',
                              isDense: true,
                              suffixIcon: Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18),
                            ),
                            child: Text(_data != null
                                ? Formatters.dataBr(_data)
                                : 'Selecionar'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_tipo == 'municipal') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _municipio,
                      decoration: const InputDecoration(
                          labelText: 'Município', isDense: true),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _adicionar,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Feriados cadastrados',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: () async {
                      final atuais = async.value ?? const <Feriado>[];
                      final n = await ref
                          .read(feriadosRepositoryProvider)
                          .importarNacionaisFixos(atuais);
                      ref.invalidate(feriadosProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(n == 0
                                  ? 'Todos já cadastrados'
                                  : '$n feriado(s) importado(s)')),
                        );
                      }
                    },
                    child: const Text('Importar nacionais'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const LoadingView(),
                error: (e, _) => Center(child: Text('Erro: $e')),
                data: (feriados) {
                  if (feriados.isEmpty) {
                    return const Center(
                      child: Text('Nenhum feriado cadastrado.',
                          style:
                              TextStyle(color: AppColors.mutedForeground)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: feriados.length,
                    itemBuilder: (context, i) {
                      final f = feriados[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            '${f.nome}${f.municipio != null ? ' — ${f.municipio}' : ''}',
                          ),
                          subtitle: Text(
                            '${Formatters.dataBr(DateTime.tryParse(f.data))}'
                            '${f.recorrente ? ' (todo ano)' : ''} · ${f.tipoLabel}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: AppColors.destructive),
                            onPressed: () async {
                              await ref
                                  .read(feriadosRepositoryProvider)
                                  .delete(f.id);
                              ref.invalidate(feriadosProvider);
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
