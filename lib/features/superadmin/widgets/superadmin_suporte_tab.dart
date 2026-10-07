import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/sistema.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/sistema_providers.dart';
import '../../../providers/superadmin_providers.dart';
import '../../../providers/supabase_providers.dart';

const _statusTickets = [
  'aberto',
  'em_andamento',
  'aguardando_cliente',
  'resolvido',
  'fechado',
];
const _prioridades = ['baixa', 'media', 'alta', 'urgente'];

/// SuperAdmin — aba Suporte (todos os tickets da plataforma).
class SuperAdminSuporteTab extends ConsumerStatefulWidget {
  const SuperAdminSuporteTab({super.key});

  @override
  ConsumerState<SuperAdminSuporteTab> createState() =>
      _SuperAdminSuporteTabState();
}

class _SuperAdminSuporteTabState extends ConsumerState<SuperAdminSuporteTab> {
  String _status = 'todos';
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ticketsListProvider);
    final orgs = ref.watch(todasOrganizacoesProvider).value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _novo(orgs),
        icon: const Icon(Icons.add),
        label: const Text('Novo ticket'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (tickets) {
          final t = _busca.toLowerCase();
          final filtrados = tickets.where((tk) {
            if (_status != 'todos' && tk.status != _status) return false;
            if (t.isEmpty) return true;
            return tk.assunto.toLowerCase().contains(t) ||
                (tk.descricao ?? '').toLowerCase().contains(t);
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Buscar ticket...',
                    isDense: true,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  isDense: true,
                  decoration:
                      const InputDecoration(labelText: 'Status', isDense: true),
                  items: [
                    const DropdownMenuItem(
                        value: 'todos', child: Text('Todos')),
                    ..._statusTickets.map((s) => DropdownMenuItem(
                        value: s, child: Text(s.replaceAll('_', ' ')))),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'todos'),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtrados.isEmpty
                    ? const EmptyState(
                        icon: Icons.support_agent_outlined,
                        title: 'Nenhum ticket')
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(ticketsListProvider),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: filtrados.length,
                          itemBuilder: (context, i) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () => _abrir(context, filtrados[i]),
                              title: Text(filtrados[i].assunto,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${filtrados[i].prioridade} · ${filtrados[i].status.replaceAll('_', ' ')}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(
                                filtrados[i].createdAt != null
                                    ? Formatters.dataHoraBr(DateTime.tryParse(
                                        filtrados[i].createdAt!))
                                    : '',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.mutedForeground),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _novo(List<Map<String, dynamic>> orgs) async {
    final assunto = TextEditingController();
    final descricao = TextEditingController();
    String? orgId;
    String prioridade = 'media';
    String categoria = 'duvida';

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
                const Text('Novo ticket',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: orgId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Organização *'),
                  items: orgs
                      .map((o) => DropdownMenuItem(
                            value: o['id'] as String,
                            child: Text(o['nome'] as String? ?? '',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setSheet(() => orgId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: assunto,
                    decoration: const InputDecoration(labelText: 'Assunto *')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: prioridade,
                        decoration:
                            const InputDecoration(labelText: 'Prioridade'),
                        items: _prioridades
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) =>
                            setSheet(() => prioridade = v ?? 'media'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: categoria,
                        decoration:
                            const InputDecoration(labelText: 'Categoria'),
                        items: const [
                          DropdownMenuItem(value: 'duvida', child: Text('Dúvida')),
                          DropdownMenuItem(
                              value: 'problema', child: Text('Problema')),
                          DropdownMenuItem(
                              value: 'sugestao', child: Text('Sugestão')),
                          DropdownMenuItem(
                              value: 'financeiro', child: Text('Financeiro')),
                          DropdownMenuItem(value: 'outro', child: Text('Outro')),
                        ],
                        onChanged: (v) =>
                            setSheet(() => categoria = v ?? 'duvida'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: descricao,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Descrição')),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Criar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) {
      assunto.dispose();
      descricao.dispose();
      return;
    }
    if (assunto.text.trim().isEmpty || orgId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe organização e assunto')),
        );
      }
      assunto.dispose();
      descricao.dispose();
      return;
    }
    final user = ref.read(appUserProvider).value;
    try {
      await ref.read(sistemaRepositoryProvider).createTicket({
        'organizacao_id': orgId,
        'assunto': assunto.text.trim(),
        'descricao':
            descricao.text.trim().isEmpty ? null : descricao.text.trim(),
        'categoria': categoria,
        'prioridade': prioridade,
        'status': 'aberto',
        'criado_por': user?.id,
      });
      ref.invalidate(ticketsListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      assunto.dispose();
      descricao.dispose();
    }
  }

  Future<void> _abrir(
    BuildContext context,
    SupportTicket ticket,
  ) async {
    final resposta = TextEditingController();
    var status = _statusTickets.contains(ticket.status)
        ? ticket.status
        : 'aberto';
    var prioridade =
        _prioridades.contains(ticket.prioridade) ? ticket.prioridade : 'media';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticket.assunto,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                if ((ticket.descricao ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(ticket.descricao!,
                      style: const TextStyle(fontSize: 12.5)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: status,
                        isDense: true,
                        decoration: const InputDecoration(
                            labelText: 'Status', isDense: true),
                        items: _statusTickets
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.replaceAll('_', ' '))))
                            .toList(),
                        onChanged: (v) async {
                          final novo = v ?? status;
                          setSheet(() => status = novo);
                          await ref.read(sistemaRepositoryProvider).updateTicket(
                            ticket.id,
                            {
                              'status': novo,
                              if (novo == 'resolvido')
                                'resolvido_em':
                                    DateTime.now().toIso8601String(),
                            },
                          );
                          ref.invalidate(ticketsListProvider);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: prioridade,
                        isDense: true,
                        decoration: const InputDecoration(
                            labelText: 'Prioridade', isDense: true),
                        items: _prioridades
                            .map((p) => DropdownMenuItem(
                                value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) async {
                          final novo = v ?? prioridade;
                          setSheet(() => prioridade = novo);
                          await ref
                              .read(sistemaRepositoryProvider)
                              .updateTicket(ticket.id, {'prioridade': novo});
                          ref.invalidate(ticketsListProvider);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final msgs =
                          ref.watch(ticketMessagesProvider(ticket.id));
                      return msgs.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Erro: $e'),
                        data: (lista) => lista.isEmpty
                            ? const Center(
                                child: Text('Sem mensagens.',
                                    style: TextStyle(
                                        color: AppColors.mutedForeground)))
                            : ListView(
                                children: lista
                                    .map((m) => _Mensagem(msg: m))
                                    .toList(),
                              ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: resposta,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            hintText: 'Responder como suporte...',
                            isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send, size: 18),
                      onPressed: () async {
                        if (resposta.text.trim().isEmpty) return;
                        final user = ref.read(appUserProvider).value;
                        await ref.read(sistemaRepositoryProvider).sendMessage({
                          'ticket_id': ticket.id,
                          'autor_id': user?.id,
                          'autor_nome': 'Suporte',
                          'is_superadmin': true,
                          'mensagem': resposta.text.trim(),
                        });
                        await ref.read(sistemaRepositoryProvider).updateTicket(
                            ticket.id, {'status': 'aguardando_cliente'});
                        resposta.clear();
                        ref.invalidate(ticketMessagesProvider(ticket.id));
                        ref.invalidate(ticketsListProvider);
                      },
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Excluir ticket'),
                          content: Text('Excluir "${ticket.assunto}"?'),
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
                      if (confirmar != true) return;
                      await ref
                          .read(sistemaRepositoryProvider)
                          .deleteTicket(ticket.id);
                      ref.invalidate(ticketsListProvider);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.destructive),
                    label: const Text('Excluir ticket',
                        style: TextStyle(color: AppColors.destructive)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    resposta.dispose();
  }
}

class _Mensagem extends StatelessWidget {
  const _Mensagem({required this.msg});

  final SupportMessage msg;

  @override
  Widget build(BuildContext context) {
    final superadmin = msg.isSuperadmin;
    return Align(
      alignment:
          superadmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: superadmin
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.muted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.autorNome ?? (superadmin ? 'Suporte' : 'Cliente'),
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(msg.mensagem, style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 2),
            Text(
              msg.createdAt != null
                  ? Formatters.dataHoraBr(DateTime.tryParse(msg.createdAt!))
                  : '',
              style: const TextStyle(
                  fontSize: 10, color: AppColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}
