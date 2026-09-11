import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/superadmin_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Painel SuperAdmin da plataforma.
class SuperAdminScreen extends StatelessWidget {
  const SuperAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SuperAdmin'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Executivo'),
              Tab(text: 'Organizações'),
              Tab(text: 'Auditoria'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ExecutivoTab(),
            _OrganizacoesTab(),
            _AuditoriaTab(),
          ],
        ),
      ),
    );
  }
}

class _ExecutivoTab extends ConsumerWidget {
  const _ExecutivoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(saudeOrgsProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (orgs) {
        final ativas = orgs.where((o) => o.ativo).length;
        final m3 = orgs.fold<double>(0, (a, o) => a + o.m3Ultimos30);
        final atrasadas =
            orgs.fold<int>(0, (a, o) => a + o.faturasAtrasadas);
        final mediaHealth = orgs.isEmpty
            ? 0
            : (orgs.fold<int>(0, (a, o) => a + o.healthScore) / orgs.length)
                .round();
        final ordenadas = [...orgs]
          ..sort((a, b) => a.healthScore.compareTo(b.healthScore));

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(saudeOrgsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  _Kpi('Organizações', '${orgs.length}', AppColors.primary),
                  _Kpi('Ativas', '$ativas', AppColors.success),
                  _Kpi('m³ (30 dias)', Formatters.numero(m3, 1),
                      AppColors.info),
                  _Kpi('Faturas atrasadas', '$atrasadas',
                      AppColors.destructive),
                  _Kpi('Health médio', '$mediaHealth', AppColors.accent),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Organizações por saúde',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...ordenadas.map((o) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(o.nome,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${Formatters.numero(o.m3Ultimos30, 1)} m³/30d · '
                        '${o.obrasAtivas} obras · ${o.totalUsuarios} usuários',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: _HealthBadge(score: o.healthScore),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _OrganizacoesTab extends ConsumerStatefulWidget {
  const _OrganizacoesTab();

  @override
  ConsumerState<_OrganizacoesTab> createState() => _OrganizacoesTabState();
}

class _OrganizacoesTabState extends ConsumerState<_OrganizacoesTab> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(todasOrganizacoesProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (orgs) {
        final filtradas = orgs
            .where((o) =>
                (o['nome'] as String? ?? '')
                    .toLowerCase()
                    .contains(_busca.toLowerCase()))
            .toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                onChanged: (v) => setState(() => _busca = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'Buscar organização...',
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(todasOrganizacoesProvider);
                  ref.invalidate(saudeOrgsProvider);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: filtradas.length,
                  itemBuilder: (context, i) =>
                      _OrganizacaoCard(org: filtradas[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrganizacaoCard extends ConsumerWidget {
  const _OrganizacaoCard({required this.org});

  final Map<String, dynamic> org;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ativo = (org['ativo'] as bool?) ?? true;
    final bloqueado = (org['bloqueio_tipo'] as String?) != null;
    final nome = org['nome'] as String? ?? 'Organização';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(nome,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            'Plano: ${org['plano'] ?? '—'}',
            if (org['trial_fim'] != null)
              'Trial: ${Formatters.dataBr(DateTime.tryParse(org['trial_fim'] as String))}',
            if (bloqueado) 'Bloqueado: ${org['bloqueio_motivo'] ?? ''}',
          ].join(' · '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (v) async {
            final repo = ref.read(superAdminRepositoryProvider);
            switch (v) {
              case 'toggle_ativo':
                await repo.updateOrganizacao(
                    org['id'] as String, {'ativo': !ativo});
                ref.invalidate(todasOrganizacoesProvider);
                ref.invalidate(saudeOrgsProvider);
              case 'bloquear':
                await repo.updateOrganizacao(org['id'] as String, {
                  'bloqueio_tipo': 'manual',
                  'bloqueio_motivo': 'Bloqueado pelo SuperAdmin',
                });
                ref.invalidate(todasOrganizacoesProvider);
              case 'desbloquear':
                await repo.updateOrganizacao(org['id'] as String, {
                  'bloqueio_tipo': null,
                  'bloqueio_motivo': null,
                });
                ref.invalidate(todasOrganizacoesProvider);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'toggle_ativo',
              child: Text(ativo ? 'Desativar' : 'Ativar'),
            ),
            if (!bloqueado)
              const PopupMenuItem(
                  value: 'bloquear', child: Text('Bloquear acesso'))
            else
              const PopupMenuItem(
                  value: 'desbloquear', child: Text('Desbloquear')),
          ],
        ),
      ),
    );
  }
}

class _AuditoriaTab extends ConsumerWidget {
  const _AuditoriaTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auditLogsProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(
            child: Text('Nenhum registro de auditoria.',
                style: TextStyle(color: AppColors.mutedForeground)),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(auditLogsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: logs.length,
            itemBuilder: (context, i) {
              final l = logs[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(l.acao,
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                  title: Text(l.alvoDescricao ?? l.alvoTipo ?? '—',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${l.atorEmail ?? '—'} · ${l.createdAt != null ? Formatters.dataHoraBr(DateTime.tryParse(l.createdAt!)) : ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.valor, this.cor);

  final String label;
  final String valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.mutedForeground)),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(valor,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: cor)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final cor = score >= 70
        ? AppColors.success
        : score >= 40
            ? AppColors.warning
            : AppColors.destructive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$score',
          style: TextStyle(
              fontWeight: FontWeight.w700, color: cor, fontSize: 13)),
    );
  }
}
