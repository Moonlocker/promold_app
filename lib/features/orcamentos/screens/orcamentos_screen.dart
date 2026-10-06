import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_providers.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/simple_form_sheet.dart';
import '../../../models/sistema.dart';
import '../../../providers/sistema_providers.dart';
import '../../../providers/supabase_providers.dart';
import 'orcamento_detalhe_screen.dart';

/// Módulo Orçamentos: listagem e cadastro.
class OrcamentosScreen extends ConsumerStatefulWidget {
  const OrcamentosScreen({super.key});

  @override
  ConsumerState<OrcamentosScreen> createState() => _OrcamentosScreenState();
}

class _OrcamentosScreenState extends ConsumerState<OrcamentosScreen> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orcamentosListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Orçamentos')),
      floatingActionButton: ref.podeCriar('orcamentos')
          ? FloatingActionButton.extended(
              onPressed: () => _novo(),
              icon: const Icon(Icons.add),
              label: const Text('Novo'),
            )
          : null,
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (orcamentos) {
          final filtrados = orcamentos
              .where((o) => o.cliente.toLowerCase().contains(_busca.toLowerCase()))
              .toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(orcamentosListProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Buscar por cliente...',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                if (filtrados.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.request_quote_outlined,
                      title: 'Nenhum orçamento',
                    ),
                  )
                else
                  ...filtrados.map((o) => _OrcamentoCard(
                        orcamento: o,
                        onChanged: () => ref.invalidate(orcamentosListProvider),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _novo() async {
    final result = await showSimpleFormSheet(
      context,
      title: 'Novo Orçamento',
      submitLabel: 'Cadastrar',
      fields: const [
        SimpleField(key: 'cliente', label: 'Cliente *', required: true),
        SimpleField(key: 'endereco', label: 'Endereço'),
        SimpleField(key: 'contato_responsavel', label: 'Contato responsável'),
        SimpleField(key: 'telefone_contato', label: 'Telefone do contato'),
        SimpleField(key: 'prazo_estimado', label: 'Prazo estimado'),
        SimpleField(key: 'observacoes', label: 'Observações', maxLines: 3),
      ],
    );
    if (result == null) return;
    try {
      await ref.read(sistemaRepositoryProvider).createOrcamento({
        'cliente': result['cliente'],
        'endereco': (result['endereco'] ?? '').isEmpty ? null : result['endereco'],
        'contato_responsavel': (result['contato_responsavel'] ?? '').isEmpty
            ? null
            : result['contato_responsavel'],
        'telefone_contato': (result['telefone_contato'] ?? '').isEmpty
            ? null
            : result['telefone_contato'],
        'prazo_estimado':
            (result['prazo_estimado'] ?? '').isEmpty ? null : result['prazo_estimado'],
        'observacoes':
            (result['observacoes'] ?? '').isEmpty ? null : result['observacoes'],
        'status': 'rascunho',
      });
      ref.invalidate(orcamentosListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }
}

class _OrcamentoCard extends ConsumerWidget {
  const _OrcamentoCard({required this.orcamento, required this.onChanged});

  final Orcamento orcamento;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrcamentoDetalheScreen(orcamento: orcamento),
            ),
          );
          onChanged();
        },
        title: Text('Nº ${orcamento.numeroOrcamento} · ${orcamento.cliente}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${orcamento.status}'
          '${orcamento.dataCriacao != null ? ' · ${Formatters.dataBr(DateTime.tryParse(orcamento.dataCriacao!))}' : ''}',
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Formatters.moeda(orcamento.valorTotal ?? 0),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) {
                if (v == 'duplicar') _duplicar(context, ref);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'duplicar', child: Text('Duplicar')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _duplicar(BuildContext context, WidgetRef ref) async {
    try {
      final novoId = await ref
          .read(orcamentoComposicoesRepositoryProvider)
          .duplicarOrcamento(orcamento.id);
      ref.invalidate(orcamentosListProvider);
      final novo = await ref.read(sistemaRepositoryProvider).getOrcamento(novoId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orçamento duplicado')),
      );
      if (novo != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrcamentoDetalheScreen(orcamento: novo),
          ),
        );
        onChanged();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao duplicar: $e')));
      }
    }
  }
}
