import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/superadmin_providers.dart';
import '../../../providers/supabase_providers.dart';

/// SuperAdmin — aba Inadimplência (faturas SaaS vencidas).
class SuperAdminInadimplenciaTab extends ConsumerStatefulWidget {
  const SuperAdminInadimplenciaTab({super.key});

  @override
  ConsumerState<SuperAdminInadimplenciaTab> createState() =>
      _SuperAdminInadimplenciaTabState();
}

class _SuperAdminInadimplenciaTabState
    extends ConsumerState<SuperAdminInadimplenciaTab> {
  final Set<String> _selecionadas = {};

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(faturasVencidasProvider);
    final orgs = ref.watch(todasOrganizacoesProvider).value ?? const [];
    final orgNome = <String, String>{
      for (final o in orgs) (o['id'] as String): (o['nome'] as String? ?? ''),
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _selecionadas.isEmpty ? null : _barra(orgNome),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (faturas) {
          if (faturas.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Sem inadimplência',
              message: 'Nenhuma fatura vencida no momento.',
            );
          }
          final total = faturas.fold<double>(
              0, (a, f) => a + ((f['valor_total'] as num?)?.toDouble() ?? 0));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(faturasVencidasProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Faturas vencidas',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.mutedForeground)),
                              Text('${faturas.length}',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.destructive)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Valor em atraso',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.mutedForeground)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(Formatters.moeda(total),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.warning)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...faturas.map((f) {
                  final id = f['id'] as String;
                  final orgId = f['organizacao_id'] as String? ?? '';
                  final venc = DateTime.tryParse(
                      (f['data_vencimento'] as String?) ?? '');
                  final dias = venc == null
                      ? 0
                      : DateTime.now().difference(venc).inDays;
                  final valor = (f['valor_total'] as num?)?.toDouble() ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      value: _selecionadas.contains(id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selecionadas.add(id);
                        } else {
                          _selecionadas.remove(id);
                        }
                      }),
                      title: Text(orgNome[orgId] ?? 'Organização',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${f['ano']}/${f['mes']} · venceu ${Formatters.dataBr(venc)} ($dias dias) · ${f['status']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      secondary: Text(Formatters.moeda(valor),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.destructive)),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _barra(Map<String, String> orgNome) {
    return Material(
      color: AppColors.foreground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text('${_selecionadas.length} selecionada(s)',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _lembrete(orgNome),
                icon: const Icon(Icons.notifications_outlined,
                    size: 16, color: Colors.white),
                label: const Text('Lembrete',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: _marcarPagas,
                icon: const Icon(Icons.check, size: 16, color: Colors.white),
                label: const Text('Pago',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: _suspender,
                icon: const Icon(Icons.block,
                    size: 16, color: AppColors.destructive),
                label: const Text('Suspender',
                    style:
                        TextStyle(color: AppColors.destructive, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _marcarPagas() async {
    final ids = _selecionadas.toList();
    await ref.read(superAdminRepositoryProvider).marcarFaturasPagas(ids);
    setState(_selecionadas.clear);
    ref.invalidate(faturasVencidasProvider);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Faturas marcadas pagas')));
    }
  }

  Future<void> _suspender() async {
    final faturas = ref.read(faturasVencidasProvider).value ?? const [];
    final orgIds = faturas
        .where((f) => _selecionadas.contains(f['id']))
        .map((f) => f['organizacao_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (orgIds.isEmpty) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspender acesso'),
        content: Text('Suspender ${orgIds.length} organização(ões)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Suspender'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await ref
        .read(superAdminRepositoryProvider)
        .suspenderOrganizacoes(orgIds, 'Pagamento pendente');
    setState(_selecionadas.clear);
    ref.invalidate(todasOrganizacoesProvider);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Organizações suspensas')));
    }
  }

  Future<void> _lembrete(Map<String, String> orgNome) async {
    final faturas = ref.read(faturasVencidasProvider).value ?? const [];
    final selecionadas =
        faturas.where((f) => _selecionadas.contains(f['id'])).toList();
    final repo = ref.read(superAdminRepositoryProvider);
    for (final f in selecionadas) {
      final orgId = f['organizacao_id'] as String?;
      if (orgId == null) continue;
      final valor = (f['valor_total'] as num?)?.toDouble() ?? 0;
      await repo.criarNotificacaoOrg(
        organizacaoId: orgId,
        titulo: 'Fatura em atraso',
        descricao:
            'Sua fatura de ${Formatters.moeda(valor)} está vencida. Regularize para evitar a suspensão do acesso.',
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${selecionadas.length} lembrete(s) enviado(s) no app')),
      );
    }
  }
}
