import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/xlsx_import_sheet.dart';
import '../../../models/cliente.dart';
import '../../../providers/cadastros_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../widgets/cliente_form_sheet.dart';

/// Módulo Clientes: cadastro centralizado.
class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          if (ref.podeCriar('clientes'))
            IconButton(
              tooltip: 'Importar XLSX',
              icon: const Icon(Icons.upload_file_outlined),
              onPressed: _importar,
            ),
        ],
      ),
      floatingActionButton: ref.podeCriar('clientes')
          ? FloatingActionButton.extended(
              onPressed: () => showClienteFormSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Novo Cliente'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _busca = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Buscar por nome, documento, e-mail...',
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: clientesAsync.when(
              loading: () => const LoadingView(message: 'Carregando...'),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (clientes) {
                final s = _busca.toLowerCase();
                final filtrados = clientes.where((c) {
                  return c.nome.toLowerCase().contains(s) ||
                      (c.cpfCnpj ?? '').toLowerCase().contains(s) ||
                      (c.email ?? '').toLowerCase().contains(s) ||
                      (c.cidade ?? '').toLowerCase().contains(s);
                }).toList();
                if (filtrados.isEmpty) {
                  return const EmptyState(
                    icon: Icons.person_outline,
                    title: 'Nenhum cliente',
                    message: 'Cadastre clientes para vincular às obras.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(clientesListProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: filtrados.length,
                    itemBuilder: (context, i) => _ClienteCard(
                      cliente: filtrados[i],
                      onChanged: () => ref.invalidate(clientesListProvider),
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

  Future<void> _importar() async {
    final ok = await showXlsxImportSheet(
      context,
      title: 'Importar Clientes',
      templateName: 'clientes',
      columns: const [
        XlsxImportColumn(
            key: 'nome',
            label: 'Nome',
            required: true,
            example: 'Cliente Exemplo'),
        XlsxImportColumn(key: 'tipo_pessoa', label: 'Tipo (PF/PJ)', example: 'PJ'),
        XlsxImportColumn(
            key: 'cpf_cnpj', label: 'CPF/CNPJ', example: '00.000.000/0001-00'),
        XlsxImportColumn(
            key: 'email', label: 'E-mail', example: 'contato@exemplo.com'),
        XlsxImportColumn(
            key: 'telefone', label: 'Telefone', example: '(11) 99999-9999'),
        XlsxImportColumn(key: 'cidade', label: 'Cidade', example: 'São Paulo'),
        XlsxImportColumn(key: 'uf', label: 'UF', example: 'SP'),
      ],
      onImport: (rows) async {
        final normalizadas = rows.map((r) {
          final map = Map<String, dynamic>.from(r);
          final tipo = (map['tipo_pessoa'] as String?)?.toUpperCase();
          map['tipo_pessoa'] = (tipo == 'PF' || tipo == 'PJ') ? tipo : 'PJ';
          final uf = map['uf'] as String?;
          if (uf != null && uf.isNotEmpty) map['uf'] = uf.toUpperCase();
          return map;
        }).toList();
        return ref
            .read(clientesRepositoryProvider)
            .createMany(normalizadas);
      },
    );
    if (ok == true) ref.invalidate(clientesListProvider);
  }
}

class _ClienteCard extends ConsumerWidget {
  const _ClienteCard({required this.cliente, required this.onChanged});

  final Cliente cliente;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: ref.podeEditar('clientes')
            ? () async {
                final ok = await showClienteFormSheet(context, cliente: cliente);
                if (ok == true) onChanged();
              }
            : null,
        title: Row(
          children: [
            Flexible(
              child: Text(
                cliente.nome,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            _Tag(
              label: cliente.tipoPessoa,
              color: cliente.isPessoaFisica
                  ? AppColors.info
                  : AppColors.primary,
            ),
            if (!cliente.ativo) ...[
              const SizedBox(width: 6),
              const _Tag(label: 'Inativo', color: AppColors.mutedForeground),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((cliente.cpfCnpj ?? '').isNotEmpty)
              Text(cliente.cpfCnpj!),
            if ((cliente.telefone ?? '').isNotEmpty ||
                (cliente.cidade ?? '').isNotEmpty)
              Text(
                [
                  if ((cliente.telefone ?? '').isNotEmpty) cliente.telefone,
                  if ((cliente.cidade ?? '').isNotEmpty)
                    '${cliente.cidade}${(cliente.uf ?? '').isNotEmpty ? '/${cliente.uf}' : ''}',
                ].join(' · '),
                style: const TextStyle(fontSize: 12.5),
              ),
          ],
        ),
        trailing: ref.podeExcluir('clientes')
            ? PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'excluir') {
                    final confirmar = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Excluir cliente'),
                        content: Text('Excluir "${cliente.nome}"?'),
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
                          .read(clientesRepositoryProvider)
                          .delete(cliente.id);
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
