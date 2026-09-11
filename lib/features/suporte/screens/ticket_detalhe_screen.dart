import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/sistema.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/sistema_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Detalhe de um ticket de suporte com conversa.
class TicketDetalheScreen extends ConsumerStatefulWidget {
  const TicketDetalheScreen({super.key, required this.ticket});

  final SupportTicket ticket;

  @override
  ConsumerState<TicketDetalheScreen> createState() =>
      _TicketDetalheScreenState();
}

class _TicketDetalheScreenState extends ConsumerState<TicketDetalheScreen> {
  final _mensagem = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _mensagem.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _mensagem.text.trim();
    if (texto.isEmpty) return;
    setState(() => _sending = true);
    final user = await ref.read(appUserProvider.future);
    try {
      await ref.read(sistemaRepositoryProvider).sendMessage({
        'ticket_id': widget.ticket.id,
        'mensagem': texto,
        'autor_id': user?.id,
        'autor_nome': user?.displayName,
        'is_superadmin': false,
      });
      _mensagem.clear();
      ref.invalidate(ticketMessagesProvider(widget.ticket.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ticketMessagesProvider(widget.ticket.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticket.assunto),
        actions: [
          if (widget.ticket.status != 'resolvido')
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Marcar como resolvido',
              onPressed: () async {
                await ref.read(sistemaRepositoryProvider).updateTicket(
                  widget.ticket.id,
                  {
                    'status': 'resolvido',
                    'resolvido_em':
                        DateTime.now().toUtc().toIso8601String(),
                  },
                );
                ref.invalidate(ticketsListProvider);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if ((widget.ticket.descricao ?? '').isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.muted,
              child: Text(widget.ticket.descricao!),
            ),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (mensagens) {
                if (mensagens.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma mensagem ainda.',
                        style: TextStyle(color: AppColors.mutedForeground)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: mensagens.length,
                  itemBuilder: (context, i) {
                    final m = mensagens[i];
                    final doSuporte = m.isSuperadmin;
                    return Align(
                      alignment: doSuporte
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          color: doSuporte
                              ? AppColors.card
                              : AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (m.autorNome != null)
                              Text(m.autorNome!,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mutedForeground)),
                            Text(m.mensagem),
                            if (m.createdAt != null)
                              Text(
                                Formatters.dataHoraBr(
                                    DateTime.tryParse(m.createdAt!)),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.mutedForeground),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mensagem,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          hintText: 'Escreva uma mensagem...', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _enviar,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
