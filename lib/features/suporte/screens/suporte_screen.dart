import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/simple_form_sheet.dart';
import '../../../models/sistema.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/sistema_providers.dart';
import '../../../providers/supabase_providers.dart';
import 'ticket_detalhe_screen.dart';

/// Módulo Suporte: abertura e acompanhamento de tickets.
class SuporteScreen extends ConsumerStatefulWidget {
  const SuporteScreen({super.key});

  @override
  ConsumerState<SuporteScreen> createState() => _SuporteScreenState();
}

class _SuporteScreenState extends ConsumerState<SuporteScreen> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ticketsListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Suporte')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _novoTicket(),
        icon: const Icon(Icons.add),
        label: const Text('Abrir Ticket'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (tickets) {
          if (tickets.isEmpty) {
            return const EmptyState(
              icon: Icons.support_agent_outlined,
              title: 'Nenhum ticket',
              message: 'Abra um ticket para falar com o suporte.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ticketsListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: tickets.length,
              itemBuilder: (context, i) => _TicketCard(
                ticket: tickets[i],
                onChanged: () => ref.invalidate(ticketsListProvider),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _novoTicket() async {
    final result = await showSimpleFormSheet(
      context,
      title: 'Abrir Ticket',
      submitLabel: 'Enviar',
      fields: const [
        SimpleField(key: 'assunto', label: 'Assunto *', required: true),
        SimpleField(key: 'descricao', label: 'Descrição', maxLines: 4),
        SimpleField(
          key: 'categoria',
          label: 'Categoria',
          options: [
            SimpleOption('duvida', 'Dúvida'),
            SimpleOption('problema', 'Problema'),
            SimpleOption('sugestao', 'Sugestão'),
            SimpleOption('financeiro', 'Financeiro'),
            SimpleOption('outro', 'Outro'),
          ],
        ),
        SimpleField(
          key: 'prioridade',
          label: 'Prioridade',
          options: [
            SimpleOption('baixa', 'Baixa'),
            SimpleOption('media', 'Média'),
            SimpleOption('alta', 'Alta'),
            SimpleOption('urgente', 'Urgente'),
          ],
        ),
      ],
    );
    if (result == null) return;
    final user = await ref.read(appUserProvider.future);
    try {
      await ref.read(sistemaRepositoryProvider).createTicket({
        'assunto': result['assunto'],
        'descricao': (result['descricao'] ?? '').isEmpty
            ? null
            : result['descricao'],
        'categoria': result['categoria'],
        'prioridade': result['prioridade'],
        'status': 'aberto',
        'criado_por': user?.id,
      });
      ref.invalidate(ticketsListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }
}

class _TicketCard extends ConsumerWidget {
  const _TicketCard({required this.ticket, required this.onChanged});

  final SupportTicket ticket;
  final VoidCallback onChanged;

  Color get _statusCor => switch (ticket.status) {
        'resolvido' || 'fechado' => AppColors.success,
        'em_andamento' => AppColors.info,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TicketDetalheScreen(ticket: ticket),
            ),
          );
          onChanged();
        },
        title: Text(ticket.assunto,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '#${ticket.id.substring(0, 6)} · ${ticket.prioridade}'
          '${ticket.createdAt != null ? ' · ${Formatters.dataHoraBr(DateTime.tryParse(ticket.createdAt!))}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _statusCor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            ticket.status,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: _statusCor),
          ),
        ),
      ),
    );
  }
}
