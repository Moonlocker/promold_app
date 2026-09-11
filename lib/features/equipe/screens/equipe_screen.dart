import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/simple_form_sheet.dart';
import '../../../models/ausencia.dart';
import '../../../models/cargo.dart';
import '../../../models/funcionario.dart';
import '../../../models/setor.dart';
import '../../../providers/equipe_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../widgets/ausencia_form_sheet.dart';
import '../widgets/funcionario_form_sheet.dart';

/// MÃ³dulo Equipe: funcionÃ¡rios, setores, cargos e ausÃªncias.
class EquipeScreen extends StatelessWidget {
  const EquipeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Equipe'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Colaboradores'),
              Tab(text: 'Setores'),
              Tab(text: 'Cargos'),
              Tab(text: 'AusÃªncias'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FuncionariosTab(),
            _SetoresTab(),
            _CargosTab(),
            _AusenciasTab(),
          ],
        ),
      ),
    );
  }
}

// ============================================================ FuncionÃ¡rios

class _FuncionariosTab extends ConsumerStatefulWidget {
  const _FuncionariosTab();

  @override
  ConsumerState<_FuncionariosTab> createState() => _FuncionariosTabState();
}

class _FuncionariosTabState extends ConsumerState<_FuncionariosTab> {
  String _busca = '';
  String _setor = 'all';
  String _status = 'ativo';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(funcionariosListProvider);
    final setores = ref.watch(setoresListProvider).value ?? const <Setor>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: ref.podeCriar('equipe')
          ? FloatingActionButton.extended(
              onPressed: () async {
                final ok = await showFuncionarioFormSheet(context);
                if (ok == true) ref.invalidate(funcionariosListProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('Novo'),
            )
          : null,
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (funcionarios) {
          final resumo = (
            total: funcionarios.length,
            ativos: funcionarios.where((f) => f.ativo).length,
            inativos: funcionarios.where((f) => !f.ativo).length,
          );
          final filtrados = funcionarios.where((f) {
            if (!f.nome.toLowerCase().contains(_busca.toLowerCase())) {
              return false;
            }
            if (_setor != 'all' && f.setorId != _setor) return false;
            if (_status == 'ativo' && !f.ativo) return false;
            if (_status == 'inativo' && f.ativo) return false;
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(funcionariosListProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ResumoBox(
                        valor: resumo.total,
                        label: 'Total',
                        cor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ResumoBox(
                        valor: resumo.ativos,
                        label: 'Ativos',
                        cor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ResumoBox(
                        valor: resumo.inativos,
                        label: 'Inativos',
                        cor: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Buscar funcionÃ¡rio...',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _setor,
                        isDense: true,
                        decoration: const InputDecoration(
                            labelText: 'Setor', isDense: true),
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('Todos')),
                          ...setores.map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.nome,
                                    overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => _setor = v ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        isDense: true,
                        decoration: const InputDecoration(
                            labelText: 'Status', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'ativo', child: Text('Ativos')),
                          DropdownMenuItem(
                              value: 'inativo', child: Text('Inativos')),
                          DropdownMenuItem(value: 'all', child: Text('Todos')),
                        ],
                        onChanged: (v) =>
                            setState(() => _status = v ?? 'ativo'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (filtrados.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'Nenhum funcionÃ¡rio',
                    ),
                  )
                else
                  ...filtrados.map((f) => _FuncionarioCard(
                        funcionario: f,
                        onChanged: () =>
                            ref.invalidate(funcionariosListProvider),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FuncionarioCard extends ConsumerWidget {
  const _FuncionarioCard({required this.funcionario, required this.onChanged});

  final Funcionario funcionario;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: ref.podeEditar('equipe')
            ? () async {
                final ok = await showFuncionarioFormSheet(context,
                    funcionario: funcionario);
                if (ok == true) onChanged();
              }
            : null,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          backgroundImage: funcionario.fotoUrl != null
              ? NetworkImage(funcionario.fotoUrl!)
              : null,
          child: funcionario.fotoUrl == null
              ? Text(
                  funcionario.iniciais,
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                )
              : null,
        ),
        title: Text(
          funcionario.nome,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: funcionario.ativo
                ? AppColors.foreground
                : AppColors.mutedForeground,
          ),
        ),
        subtitle: Text(
          [
            funcionario.cargoNome ?? '-',
            funcionario.setorNome ?? '-',
          ].join(' Â· '),
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: ref.podeExcluir('equipe')
            ? PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'excluir') {
                    final confirmar = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Excluir funcionÃ¡rio'),
                        content: Text('Excluir "${funcionario.nome}"?'),
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
                    if (confirmar == true) {
                      await ref
                          .read(equipeRepositoryProvider)
                          .deleteFuncionario(funcionario.id);
                      onChanged();
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                ],
              )
            : null,
      ),
    );
  }
}

// ================================================================= Setores

class _SetoresTab extends ConsumerWidget {
  const _SetoresTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(setoresListProvider);
    final funcionarios = ref.watch(funcionariosListProvider).value ?? const [];
    final cargos = ref.watch(cargosListProvider).value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: ref.podeCriar('equipe')
          ? FloatingActionButton.extended(
              onPressed: () => _abrirForm(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Novo Setor'),
            )
          : null,
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (setores) {
          if (setores.isEmpty) {
            return const EmptyState(
              icon: Icons.business_outlined,
              title: 'Nenhum setor cadastrado',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(setoresListProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                ...setores.map((s) {
                  final nFunc = funcionarios
                      .where((f) => f.setorId == s.id && f.ativo)
                      .length;
                  final nCargos =
                      cargos.where((c) => c.setorId == s.id && c.ativo).length;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      onTap: ref.podeEditar('equipe')
                          ? () => _abrirForm(context, ref, setor: s)
                          : null,
                      title: Text(s.nome,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        s.descricao?.isNotEmpty == true
                            ? '${s.descricao}\n$nFunc funcionÃ¡rios Â· $nCargos cargos'
                            : '$nFunc funcionÃ¡rios Â· $nCargos cargos',
                      ),
                      isThreeLine: s.descricao?.isNotEmpty == true,
                      trailing: ref.podeExcluir('equipe')
                          ? PopupMenuButton<String>(
                              onSelected: (v) async {
                                final repo =
                                    ref.read(equipeRepositoryProvider);
                                if (v == 'excluir') {
                                  if (nFunc > 0 || nCargos > 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Setor possui funcionÃ¡rios/cargos vinculados'),
                                      ),
                                    );
                                    return;
                                  }
                                  final ok = await _confirmar(context, s.nome);
                                  if (ok == true) {
                                    await repo.deleteSetor(s.id);
                                    ref.invalidate(setoresListProvider);
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'excluir',
                                    child: Text('Excluir',
                                        style: TextStyle(
                                            color: AppColors.destructive))),
                              ],
                            )
                          : null,
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

  Future<void> _abrirForm(BuildContext context, WidgetRef ref,
      {Setor? setor}) async {
    final result = await showSimpleFormSheet(
      context,
      title: setor == null ? 'Novo Setor' : 'Editar Setor',
      submitLabel: setor == null ? 'Cadastrar' : 'Salvar',
      fields: [
        SimpleField(
            key: 'nome', label: 'Nome *', initial: setor?.nome, required: true),
        SimpleField(
            key: 'descricao',
            label: 'DescriÃ§Ã£o',
            initial: setor?.descricao,
            maxLines: 3),
      ],
    );
    if (result == null) return;
    final repo = ref.read(equipeRepositoryProvider);
    final payload = {
      'nome': result['nome'],
      'descricao':
          (result['descricao'] ?? '').isEmpty ? null : result['descricao'],
    };
    if (setor == null) {
      await repo.createSetor({...payload, 'ativo': true});
    } else {
      await repo.updateSetor(setor.id, payload);
    }
    ref.invalidate(setoresListProvider);
  }
}

// ================================================================== Cargos

class _CargosTab extends ConsumerWidget {
  const _CargosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cargosListProvider);
    final setores = ref.watch(setoresListProvider).value ?? const <Setor>[];
    final funcionarios = ref.watch(funcionariosListProvider).value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: ref.podeCriar('equipe')
          ? FloatingActionButton.extended(
              onPressed: () => _abrirForm(context, ref, setores: setores),
              icon: const Icon(Icons.add),
              label: const Text('Novo Cargo'),
            )
          : null,
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (cargos) {
          if (cargos.isEmpty) {
            return const EmptyState(
              icon: Icons.badge_outlined,
              title: 'Nenhum cargo cadastrado',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(cargosListProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                ...cargos.map((c) {
                  final nFunc =
                      funcionarios.where((f) => f.cargoId == c.id).length;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      onTap: ref.podeEditar('equipe')
                          ? () => _abrirForm(context, ref,
                              cargo: c, setores: setores)
                          : null,
                      title: Text(c.nome,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        [
                          c.setorNome ?? '-',
                          if (c.salario != null) Formatters.moeda(c.salario!),
                          '$nFunc func.',
                        ].join(' Â· '),
                      ),
                      trailing: ref.podeExcluir('equipe')
                          ? PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'excluir') {
                                  if (nFunc > 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Cargo possui funcionÃ¡rios vinculados')),
                                    );
                                    return;
                                  }
                                  final ok = await _confirmar(context, c.nome);
                                  if (ok == true) {
                                    await ref
                                        .read(equipeRepositoryProvider)
                                        .deleteCargo(c.id);
                                    ref.invalidate(cargosListProvider);
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'excluir',
                                    child: Text('Excluir',
                                        style: TextStyle(
                                            color: AppColors.destructive))),
                              ],
                            )
                          : null,
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

  Future<void> _abrirForm(
    BuildContext context,
    WidgetRef ref, {
    Cargo? cargo,
    required List<Setor> setores,
  }) async {
    final result = await showSimpleFormSheet(
      context,
      title: cargo == null ? 'Novo Cargo' : 'Editar Cargo',
      submitLabel: cargo == null ? 'Cadastrar' : 'Salvar',
      fields: [
        SimpleField(
            key: 'nome', label: 'Nome *', initial: cargo?.nome, required: true),
        SimpleField(
          key: 'setor_id',
          label: 'Setor *',
          initial: cargo?.setorId ?? (setores.isNotEmpty ? setores.first.id : null),
          options: setores
              .map((s) => SimpleOption(s.id, s.nome))
              .toList(growable: false),
        ),
        SimpleField(
            key: 'salario',
            label: 'SalÃ¡rio base (R\$)',
            initial: cargo?.salario?.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        SimpleField(
            key: 'descricao',
            label: 'DescriÃ§Ã£o',
            initial: cargo?.descricao,
            maxLines: 2),
      ],
    );
    if (result == null) return;
    final repo = ref.read(equipeRepositoryProvider);
    final payload = <String, dynamic>{
      'nome': result['nome'],
      'setor_id': (result['setor_id'] ?? '').isEmpty ? null : result['setor_id'],
      'salario': double.tryParse((result['salario'] ?? '').replaceAll(',', '.')),
      'descricao':
          (result['descricao'] ?? '').isEmpty ? null : result['descricao'],
    };
    if (cargo == null) {
      await repo.createCargo({...payload, 'ativo': true});
    } else {
      await repo.updateCargo(cargo.id, payload);
    }
    ref.invalidate(cargosListProvider);
  }
}

// =============================================================== AusÃªncias

class _AusenciasTab extends ConsumerStatefulWidget {
  const _AusenciasTab();

  @override
  ConsumerState<_AusenciasTab> createState() => _AusenciasTabState();
}

class _AusenciasTabState extends ConsumerState<_AusenciasTab> {
  String _busca = '';
  String _tipo = 'all';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ausenciasListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: ref.podeCriar('equipe')
          ? FloatingActionButton.extended(
              onPressed: () async {
                final ok = await showAusenciaFormSheet(context);
                if (ok == true) ref.invalidate(ausenciasListProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('Registrar'),
            )
          : null,
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (ausencias) {
          final filtradas = ausencias.where((a) {
            final nome = (a.funcionarioNome ?? '').toLowerCase();
            if (!nome.contains(_busca.toLowerCase())) return false;
            if (_tipo != 'all' && a.tipo != _tipo) return false;
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ausenciasListProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Buscar funcionÃ¡rio...',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _tipo,
                  isDense: true,
                  decoration:
                      const InputDecoration(labelText: 'Tipo', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todos')),
                    DropdownMenuItem(value: 'falta', child: Text('Falta')),
                    DropdownMenuItem(value: 'atestado', child: Text('Atestado')),
                    DropdownMenuItem(value: 'ferias', child: Text('FÃ©rias')),
                    DropdownMenuItem(value: 'licenca', child: Text('LicenÃ§a')),
                    DropdownMenuItem(value: 'outro', child: Text('Outro')),
                  ],
                  onChanged: (v) => setState(() => _tipo = v ?? 'all'),
                ),
                const SizedBox(height: 12),
                if (filtradas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.event_busy_outlined,
                      title: 'Nenhuma ausÃªncia registrada',
                    ),
                  )
                else
                  ...filtradas.map((a) => _AusenciaCard(
                        ausencia: a,
                        onChanged: () =>
                            ref.invalidate(ausenciasListProvider),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AusenciaCard extends ConsumerWidget {
  const _AusenciaCard({required this.ausencia, required this.onChanged});

  final Ausencia ausencia;
  final VoidCallback onChanged;

  Color get _cor => switch (ausencia.tipo) {
        'falta' => AppColors.destructive,
        'atestado' => AppColors.warning,
        'ferias' => AppColors.info,
        'licenca' => AppColors.primary,
        _ => AppColors.mutedForeground,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ini = DateTime.tryParse(ausencia.dataInicio);
    final fim = DateTime.tryParse(ausencia.dataFim);
    final periodo = Formatters.dataBr(ini) == Formatters.dataBr(fim)
        ? Formatters.dataBr(ini)
        : '${Formatters.dataBr(ini)} - ${Formatters.dataBr(fim)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: ref.podeEditar('equipe')
            ? () async {
                final ok =
                    await showAusenciaFormSheet(context, ausencia: ausencia);
                if (ok == true) onChanged();
              }
            : null,
        title: Text(
          ausencia.funcionarioNome ?? 'Desconhecido',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$periodo${(ausencia.motivo ?? '').isNotEmpty ? ' Â· ${ausencia.motivo}' : ''}',
        ),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            ausencia.tipoLabel,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: _cor),
          ),
        ),
        trailing: ref.podeExcluir('equipe')
            ? IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.destructive),
                onPressed: () async {
                  final ok = await _confirmar(
                    context,
                    ausencia.funcionarioNome ?? 'esta ausÃªncia',
                  );
                  if (ok == true) {
                    await ref
                        .read(equipeRepositoryProvider)
                        .deleteAusencia(ausencia.id);
                    onChanged();
                  }
                },
              )
            : null,
      ),
    );
  }
}

// =============================================================== Auxiliares

class _ResumoBox extends StatelessWidget {
  const _ResumoBox({
    required this.valor,
    required this.label,
    required this.cor,
  });

  final int valor;
  final String label;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            Text(
              '$valor',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: cor),
            ),
            Text(label,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.mutedForeground)),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirmar(BuildContext context, String nome) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmar exclusÃ£o'),
      content: Text('Excluir "$nome"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
}
