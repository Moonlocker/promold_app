import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/obra.dart';
import '../../../providers/auth_providers.dart';

const _statusLabel = {
  'planejamento': 'Planejamento',
  'ativa': 'Ativa',
  'pausada': 'Pausada',
  'concluida': 'Concluída',
};

const _statusCor = {
  'planejamento': AppColors.info,
  'ativa': AppColors.success,
  'pausada': AppColors.warning,
  'concluida': AppColors.mutedForeground,
};

/// Status Geral: visão consolidada das obras.
class VisaoGeralScreen extends ConsumerStatefulWidget {
  const VisaoGeralScreen({super.key});

  @override
  ConsumerState<VisaoGeralScreen> createState() => _VisaoGeralScreenState();
}

class _VisaoGeralScreenState extends ConsumerState<VisaoGeralScreen> {
  String _status = 'todos';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(obrasListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Status Geral')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (obras) {
          final contagem = <String, int>{};
          for (final o in obras) {
            contagem[o.status] = (contagem[o.status] ?? 0) + 1;
          }
          final filtradas = obras
              .where((o) => _status == 'todos' || o.status == _status)
              .toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(obrasListProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Box(
                        label: 'Total',
                        valor: obras.length,
                        cor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Box(
                        label: 'Ativas',
                        valor: contagem['ativa'] ?? 0,
                        cor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Box(
                        label: 'Pausadas',
                        valor: contagem['pausada'] ?? 0,
                        cor: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Box(
                        label: 'Concluídas',
                        valor: contagem['concluida'] ?? 0,
                        cor: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  isDense: true,
                  decoration:
                      const InputDecoration(labelText: 'Status', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'todos', child: Text('Todos')),
                    DropdownMenuItem(
                        value: 'planejamento', child: Text('Planejamento')),
                    DropdownMenuItem(value: 'ativa', child: Text('Ativa')),
                    DropdownMenuItem(value: 'pausada', child: Text('Pausada')),
                    DropdownMenuItem(
                        value: 'concluida', child: Text('Concluída')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'todos'),
                ),
                const SizedBox(height: 12),
                if (filtradas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.visibility_outlined,
                      title: 'Nenhuma obra encontrada',
                    ),
                  )
                else
                  ...filtradas.map((o) => _ObraResumo(obra: o)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ObraResumo extends StatelessWidget {
  const _ObraResumo({required this.obra});

  final Obra obra;

  @override
  Widget build(BuildContext context) {
    final cor = _statusCor[obra.status] ?? AppColors.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => context.push(AppRoutes.obraDetalhe(obra.id)),
        title: Text(obra.nome,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${obra.cliente}'
          '${obra.dataPrevisao != null ? ' · Previsão ${Formatters.dataBr(obra.dataPrevisao)}' : ''}',
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _statusLabel[obra.status] ?? obra.status,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: cor),
          ),
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.label, required this.valor, required this.cor});

  final String label;
  final int valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text('$valor',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: cor)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.mutedForeground)),
          ],
        ),
      ),
    );
  }
}
