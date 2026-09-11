import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/capacidade.dart';
import '../../../providers/capacidade_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Aba Capacidade Fábrica: áreas produtivas e capacidade diária/semanal.
class CapacidadeFabricaTab extends ConsumerWidget {
  const CapacidadeFabricaTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areasAsync = ref.watch(areasProdutivasProvider);
    final capsAsync = ref.watch(capacidadesFabricaProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _novaArea(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nova Área'),
      ),
      body: areasAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (areas) {
          final caps = capsAsync.value ?? const <CapacidadeFabrica>[];
          if (areas.isEmpty) {
            return const EmptyState(
              icon: Icons.factory_outlined,
              title: 'Nenhuma área produtiva',
              message: 'Cadastre as áreas e suas capacidades de produção.',
            );
          }
          final totalDiaria = caps
              .where((c) => c.ativa)
              .fold<double>(0, (a, c) => a + c.capacidadeDiaria);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(areasProdutivasProvider);
              ref.invalidate(capacidadesFabricaProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.factory_outlined,
                        color: AppColors.primary),
                    title: const Text('Capacidade diária total'),
                    trailing: Text(
                      '${Formatters.numero(totalDiaria, 0)} peças/dia',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...areas.map((area) {
                  final cap =
                      caps.where((c) => c.areaId == area.id).firstOrNull;
                  return _AreaCard(
                    area: area,
                    capacidade: cap,
                    onChanged: () {
                      ref.invalidate(areasProdutivasProvider);
                      ref.invalidate(capacidadesFabricaProvider);
                    },
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _novaArea(BuildContext context, WidgetRef ref) async {
    final nome = TextEditingController();
    final descricao = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova Área Produtiva'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nome,
              decoration: const InputDecoration(labelText: 'Nome *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descricao,
              decoration: const InputDecoration(labelText: 'Descrição'),
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
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (ok == true && nome.text.trim().isNotEmpty) {
      await ref.read(capacidadeRepositoryProvider).createArea({
        'nome': nome.text.trim(),
        'descricao':
            descricao.text.trim().isEmpty ? null : descricao.text.trim(),
        'ativa': true,
      });
      ref.invalidate(areasProdutivasProvider);
    }
    nome.dispose();
    descricao.dispose();
  }
}

class _AreaCard extends ConsumerWidget {
  const _AreaCard({
    required this.area,
    required this.capacidade,
    required this.onChanged,
  });

  final AreaProdutiva area;
  final CapacidadeFabrica? capacidade;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cap = capacidade;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(area.nome,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          cap == null
              ? 'Sem capacidade definida'
              : '${Formatters.numero(cap.capacidadeDiaria, 0)}/dia'
                  '${cap.capacidadeSemanal != null ? ' · ${Formatters.numero(cap.capacidadeSemanal, 0)}/semana' : ''}',
          style: const TextStyle(fontSize: 12.5),
        ),
        onTap: () => _editarCapacidade(context, ref),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            final repo = ref.read(capacidadeRepositoryProvider);
            switch (v) {
              case 'capacidade':
                await _editarCapacidade(context, ref);
              case 'excluir':
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Excluir área'),
                    content: Text('Excluir "${area.nome}"?'),
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
                if (ok == true) {
                  await repo.deleteArea(area.id);
                  onChanged();
                }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'capacidade', child: Text('Definir capacidade')),
            PopupMenuItem(
                value: 'excluir',
                child: Text('Excluir',
                    style: TextStyle(color: AppColors.destructive))),
          ],
        ),
      ),
    );
  }

  Future<void> _editarCapacidade(BuildContext context, WidgetRef ref) async {
    final diaria = TextEditingController(
        text: capacidade?.capacidadeDiaria.toStringAsFixed(0) ?? '');
    final semanal = TextEditingController(
        text: capacidade?.capacidadeSemanal?.toStringAsFixed(0) ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Capacidade · ${area.nome}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: diaria,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Capacidade diária (peças)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: semanal,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Capacidade semanal (opcional)'),
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
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(capacidadeRepositoryProvider).saveCapacidade(
            areaId: area.id,
            capacidadeDiaria:
                double.tryParse(diaria.text.replaceAll(',', '.')) ?? 0,
            capacidadeSemanal: semanal.text.trim().isEmpty
                ? null
                : double.tryParse(semanal.text.replaceAll(',', '.')),
          );
      onChanged();
    }
    diaria.dispose();
    semanal.dispose();
  }
}
