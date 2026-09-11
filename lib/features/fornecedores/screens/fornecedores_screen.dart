import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/fornecedor.dart';
import '../../../providers/cadastros_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../widgets/fornecedor_form_sheet.dart';

/// MÃ³dulo Fornecedores.
class FornecedoresScreen extends ConsumerStatefulWidget {
  const FornecedoresScreen({super.key});

  @override
  ConsumerState<FornecedoresScreen> createState() => _FornecedoresScreenState();
}

class _FornecedoresScreenState extends ConsumerState<FornecedoresScreen> {
  String _busca = '';
  String _status = 'ativos';

  @override
  Widget build(BuildContext context) {
    final fornecedoresAsync = ref.watch(fornecedoresListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fornecedores')),
      floatingActionButton: ref.podeCriar('fornecedores')
          ? FloatingActionButton.extended(
              onPressed: () => showFornecedorFormSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Novo Fornecedor'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _busca = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 20),
                      hintText: 'Buscar fornecedor...',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _status,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'ativos', child: Text('Ativos')),
                    DropdownMenuItem(value: 'inativos', child: Text('Inativos')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'ativos'),
                ),
              ],
            ),
          ),
          Expanded(
            child: fornecedoresAsync.when(
              loading: () => const LoadingView(message: 'Carregando...'),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (fornecedores) {
                final s = _busca.toLowerCase();
                final filtrados = fornecedores.where((f) {
                  final ativo = f.ativo;
                  if (_status == 'ativos' && !ativo) return false;
                  if (_status == 'inativos' && ativo) return false;
                  return f.razaoSocial.toLowerCase().contains(s) ||
                      (f.nomeFantasia ?? '').toLowerCase().contains(s) ||
                      (f.cnpjCpf ?? '').toLowerCase().contains(s) ||
                      (f.email ?? '').toLowerCase().contains(s);
                }).toList();
                if (filtrados.isEmpty) {
                  return const EmptyState(
                    icon: Icons.store_outlined,
                    title: 'Nenhum fornecedor',
                    message: 'Cadastre fornecedores da operaÃ§Ã£o.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(fornecedoresListProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: filtrados.length,
                    itemBuilder: (context, i) => _FornecedorCard(
                      fornecedor: filtrados[i],
                      onChanged: () =>
                          ref.invalidate(fornecedoresListProvider),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FornecedorCard extends ConsumerWidget {
  const _FornecedorCard({required this.fornecedor, required this.onChanged});

  final Fornecedor fornecedor;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: ref.podeEditar('fornecedores')
            ? () async {
                final ok = await showFornecedorFormSheet(context,
                    fornecedor: fornecedor);
                if (ok == true) onChanged();
              }
            : null,
        title: Text(
          fornecedor.razaoSocial,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: fornecedor.ativo
                ? AppColors.foreground
                : AppColors.mutedForeground,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((fornecedor.nomeFantasia ?? '').isNotEmpty)
              Text(fornecedor.nomeFantasia!),
            Text(
              [
                fornecedor.isPessoaFisica ? 'PF' : 'PJ',
                if ((fornecedor.cnpjCpf ?? '').isNotEmpty) fornecedor.cnpjCpf,
                if ((fornecedor.cidade ?? '').isNotEmpty)
                  '${fornecedor.cidade}${(fornecedor.estado ?? '').isNotEmpty ? '/${fornecedor.estado}' : ''}',
              ].join(' Â· '),
              style: const TextStyle(fontSize: 12.5),
            ),
          ],
        ),
        trailing: (ref.podeEditar('fornecedores') ||
                ref.podeExcluir('fornecedores'))
            ? PopupMenuButton<String>(
                onSelected: (v) async {
                  final repo = ref.read(fornecedoresRepositoryProvider);
                  switch (v) {
                    case 'toggle':
                      await repo.toggleAtivo(fornecedor.id, !fornecedor.ativo);
                      onChanged();
                    case 'excluir':
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Excluir fornecedor'),
                          content: Text('Excluir "${fornecedor.razaoSocial}"?'),
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
                        await repo.delete(fornecedor.id);
                        onChanged();
                      }
                  }
                },
                itemBuilder: (_) => [
                  if (ref.podeEditar('fornecedores'))
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(fornecedor.ativo ? 'Desativar' : 'Ativar'),
                    ),
                  if (ref.podeExcluir('fornecedores'))
                    const PopupMenuItem(
                      value: 'excluir',
                      child: Text('Excluir',
                          style: TextStyle(color: AppColors.destructive)),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}
