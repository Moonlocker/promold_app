import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/superadmin_providers.dart';
import '../../../providers/supabase_providers.dart';

/// SuperAdmin — aba Planos.
class SuperAdminPlanosTab extends ConsumerWidget {
  const SuperAdminPlanosTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(planosAdminProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Novo plano'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (planos) {
          if (planos.isEmpty) {
            return const EmptyState(
                icon: Icons.workspace_premium_outlined,
                title: 'Nenhum plano');
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(planosAdminProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: planos.length,
              itemBuilder: (context, i) {
                final p = planos[i];
                final valor =
                    (p['valor_base_mensal'] as num?)?.toDouble() ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _PlanoDetalheScreen(plano: p),
                      ),
                    ),
                    title: Text(p['nome'] as String? ?? 'Plano',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${Formatters.moeda(valor)}/mês · '
                      '${p['m3_inclusos'] ?? 0} m³ · '
                      '${(p['ativo'] as bool?) == true ? 'ativo' : 'inativo'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (v) async {
                        if (v == 'editar') {
                          await _form(context, ref, plano: p);
                        } else if (v == 'excluir') {
                          await ref
                              .read(superAdminRepositoryProvider)
                              .deletePlano(p['id'] as String);
                          ref.invalidate(planosAdminProvider);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'editar', child: Text('Editar')),
                        PopupMenuItem(
                            value: 'excluir',
                            child: Text('Excluir',
                                style: TextStyle(
                                    color: AppColors.destructive))),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _form(
    BuildContext context,
    WidgetRef ref, {
    Map<String, dynamic>? plano,
  }) async {
    final nome = TextEditingController(text: plano?['nome'] as String? ?? '');
    final descricao =
        TextEditingController(text: plano?['descricao'] as String? ?? '');
    final valorBase = TextEditingController(
        text: ((plano?['valor_base_mensal'] as num?)?.toDouble() ?? 0)
            .toStringAsFixed(2));
    final m3 = TextEditingController(
        text: ((plano?['m3_inclusos'] as num?) ?? 0).toString());
    final maxUsuarios = TextEditingController(
        text: ((plano?['max_usuarios'] as num?) ?? 0).toString());
    final maxObras = TextEditingController(
        text: ((plano?['max_obras_ativas'] as num?) ?? 0).toString());
    final trial = TextEditingController(
        text: ((plano?['trial_dias'] as num?) ?? 0).toString());
    final ordem = TextEditingController(
        text: ((plano?['ordem'] as num?) ?? 0).toString());
    bool ativo = (plano?['ativo'] as bool?) ?? true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(plano == null ? 'Novo plano' : 'Editar plano',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                _f(nome, 'Nome *'),
                _f(descricao, 'Descrição'),
                _f(valorBase, 'Valor base mensal (R\$)', number: true),
                Row(children: [
                  Expanded(child: _f(m3, 'm³ inclusos', number: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _f(ordem, 'Ordem', number: true)),
                ]),
                Row(children: [
                  Expanded(child: _f(maxUsuarios, 'Máx. usuários', number: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _f(maxObras, 'Máx. obras', number: true)),
                ]),
                _f(trial, 'Trial (dias)', number: true),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ativo'),
                  value: ativo,
                  onChanged: (v) => setSheet(() => ativo = v),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    if (nome.text.trim().isEmpty) return;
                    await ref.read(superAdminRepositoryProvider).savePlano({
                      'nome': nome.text.trim(),
                      'descricao':
                          descricao.text.trim().isEmpty ? null : descricao.text.trim(),
                      'valor_base_mensal': double.tryParse(
                              valorBase.text.replaceAll(',', '.')) ??
                          0,
                      'm3_inclusos': int.tryParse(m3.text) ?? 0,
                      'max_usuarios': int.tryParse(maxUsuarios.text) ?? 0,
                      'max_obras_ativas': int.tryParse(maxObras.text) ?? 0,
                      'trial_dias': int.tryParse(trial.text) ?? 0,
                      'ordem': int.tryParse(ordem.text) ?? 0,
                      'ativo': ativo,
                    }, id: plano?['id'] as String?);
                    ref.invalidate(planosAdminProvider);
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (final c in [
      nome,
      descricao,
      valorBase,
      m3,
      maxUsuarios,
      maxObras,
      trial,
      ordem
    ]) {
      c.dispose();
    }
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Plano salvo')));
    }
  }

  static Widget _f(TextEditingController c, String label,
      {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType:
            number ? const TextInputType.numberWithOptions(decimal: true) : null,
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }
}

class _PlanoDetalheScreen extends StatelessWidget {
  const _PlanoDetalheScreen({required this.plano});

  final Map<String, dynamic> plano;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(plano['nome'] as String? ?? 'Plano'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Dados'),
              Tab(text: 'Faixas m³'),
              Tab(text: 'Módulos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DadosTab(plano: plano),
            _FaixasTab(planoId: plano['id'] as String),
            _ModulosPlanoTab(planoId: plano['id'] as String),
          ],
        ),
      ),
    );
  }
}

class _DadosTab extends StatelessWidget {
  const _DadosTab({required this.plano});

  final Map<String, dynamic> plano;

  @override
  Widget build(BuildContext context) {
    final itens = <List<String>>[
      ['Valor base mensal',
        Formatters.moeda((plano['valor_base_mensal'] as num?)?.toDouble() ?? 0)],
      ['m³ inclusos', '${plano['m3_inclusos'] ?? 0}'],
      ['Máx. usuários', '${plano['max_usuarios'] ?? 0}'],
      ['Máx. obras ativas', '${plano['max_obras_ativas'] ?? 0}'],
      ['Trial (dias)', '${plano['trial_dias'] ?? 0}'],
      ['Ordem', '${plano['ordem'] ?? 0}'],
      ['Ativo', (plano['ativo'] as bool?) == true ? 'Sim' : 'Não'],
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if ((plano['descricao'] as String?)?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(plano['descricao'] as String),
          ),
        ...itens.map((it) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 160,
                    child: Text(it[0],
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.mutedForeground)),
                  ),
                  Expanded(child: Text(it[1],
                      style: const TextStyle(fontWeight: FontWeight.w600))),
                ],
              ),
            )),
      ],
    );
  }
}

class _FaixasTab extends ConsumerWidget {
  const _FaixasTab({required this.planoId});

  final String planoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(planoFaixasProvider(planoId));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nova faixa'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (faixas) {
          if (faixas.isEmpty) {
            return const EmptyState(
                icon: Icons.straighten_outlined, title: 'Nenhuma faixa');
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: faixas.length,
            itemBuilder: (context, i) {
              final f = faixas[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    '${f['m3_min'] ?? 0} – ${f['m3_max'] ?? '∞'} m³',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Fixo ${Formatters.moeda((f['valor_adicional'] as num?)?.toDouble() ?? 0)}'
                    ' · ${Formatters.moeda((f['valor_por_m3'] as num?)?.toDouble() ?? 0)}/m³'
                    '${(f['descricao'] as String?)?.isNotEmpty == true ? ' · ${f['descricao']}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) async {
                      if (v == 'editar') {
                        await _form(context, ref, faixa: f);
                      } else if (v == 'excluir') {
                        await ref
                            .read(superAdminRepositoryProvider)
                            .deletePlanoFaixa(f['id'] as String);
                        ref.invalidate(planoFaixasProvider(planoId));
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(
                          value: 'excluir',
                          child: Text('Excluir',
                              style:
                                  TextStyle(color: AppColors.destructive))),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _form(
    BuildContext context,
    WidgetRef ref, {
    Map<String, dynamic>? faixa,
  }) async {
    final min = TextEditingController(
        text: ((faixa?['m3_min'] as num?) ?? 0).toString());
    final max = TextEditingController(
        text: (faixa?['m3_max'] as num?)?.toString() ?? '');
    final fixo = TextEditingController(
        text: ((faixa?['valor_adicional'] as num?)?.toDouble() ?? 0)
            .toStringAsFixed(2));
    final porM3 = TextEditingController(
        text: ((faixa?['valor_por_m3'] as num?)?.toDouble() ?? 0)
            .toStringAsFixed(2));
    final descricao =
        TextEditingController(text: faixa?['descricao'] as String? ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(faixa == null ? 'Nova faixa' : 'Editar faixa',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _f(min, 'm³ mínimo', number: true)),
                const SizedBox(width: 10),
                Expanded(child: _f(max, 'm³ máximo (vazio = ∞)', number: true)),
              ]),
              Row(children: [
                Expanded(child: _f(fixo, 'Valor fixo (R\$)', number: true)),
                const SizedBox(width: 10),
                Expanded(child: _f(porM3, 'R\$/m³', number: true)),
              ]),
              _f(descricao, 'Descrição'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  await ref.read(superAdminRepositoryProvider).savePlanoFaixa({
                    'plano_id': planoId,
                    'm3_min': int.tryParse(min.text) ?? 0,
                    'm3_max':
                        max.text.trim().isEmpty ? null : int.tryParse(max.text),
                    'valor_adicional':
                        double.tryParse(fixo.text.replaceAll(',', '.')) ?? 0,
                    'valor_por_m3':
                        double.tryParse(porM3.text.replaceAll(',', '.')) ?? 0,
                    'descricao': descricao.text.trim().isEmpty
                        ? null
                        : descricao.text.trim(),
                  }, id: faixa?['id'] as String?);
                  ref.invalidate(planoFaixasProvider(planoId));
                  if (context.mounted) Navigator.pop(context, true);
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
    for (final c in [min, max, fixo, porM3, descricao]) {
      c.dispose();
    }
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Faixa salva')));
    }
  }

  static Widget _f(TextEditingController c, String label,
      {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType:
            number ? const TextInputType.numberWithOptions(decimal: true) : null,
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }
}

class _ModulosPlanoTab extends ConsumerStatefulWidget {
  const _ModulosPlanoTab({required this.planoId});

  final String planoId;

  @override
  ConsumerState<_ModulosPlanoTab> createState() => _ModulosPlanoTabState();
}

class _ModulosPlanoTabState extends ConsumerState<_ModulosPlanoTab> {
  Set<String>? _selecionados;
  bool _salvando = false;

  @override
  Widget build(BuildContext context) {
    final modulosAsync = ref.watch(modulosAdminProvider);
    final selecionadosAsync = ref.watch(planoModulosProvider(widget.planoId));
    return modulosAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (modulos) {
        final atuais = selecionadosAsync.value ?? const <String>[];
        _selecionados ??= atuais.toSet();
        final lista = modulos
            .where((m) => (m['core'] as bool?) != true)
            .toList();
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: [
                  for (final m in lista)
                    CheckboxListTile(
                      value: _selecionados!.contains(m['id']),
                      title: Text(m['nome'] as String? ?? ''),
                      subtitle: Text(m['slug'] as String? ?? '',
                          style: const TextStyle(fontSize: 11)),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selecionados!.add(m['id'] as String);
                        } else {
                          _selecionados!.remove(m['id']);
                        }
                      }),
                    ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _salvando ? null : _salvar,
                    icon: const Icon(Icons.save, size: 18),
                    label: Text(_salvando ? 'Salvando...' : 'Salvar módulos'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await ref
          .read(superAdminRepositoryProvider)
          .setPlanoModulos(widget.planoId, _selecionados!.toList());
      ref.invalidate(planoModulosProvider(widget.planoId));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Módulos do plano salvos')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
}
