import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Módulo Suporte: tickets e vídeos tutoriais.
class SuporteScreen extends ConsumerStatefulWidget {
  const SuporteScreen({super.key});

  @override
  ConsumerState<SuporteScreen> createState() => _SuporteScreenState();
}

class _SuporteScreenState extends ConsumerState<SuporteScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final naTickets = _tabs.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suporte'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Meus tickets'),
            Tab(text: 'Vídeos tutoriais'),
          ],
        ),
      ),
      floatingActionButton: naTickets
          ? FloatingActionButton.extended(
              onPressed: () => _novoTicket(),
              icon: const Icon(Icons.add),
              label: const Text('Abrir Ticket'),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: const [
          _TicketsTab(),
          _TutoriaisTab(),
        ],
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

class _TicketsTab extends ConsumerWidget {
  const _TicketsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ticketsListProvider);
    return async.when(
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
    );
  }
}

class _TutoriaisTab extends ConsumerStatefulWidget {
  const _TutoriaisTab();

  @override
  ConsumerState<_TutoriaisTab> createState() => _TutoriaisTabState();
}

class _TutoriaisTabState extends ConsumerState<_TutoriaisTab> {
  String _busca = '';
  String _modulo = 'todos';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tutoriaisVideosProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (videos) {
        final modulos = videos
            .map((v) => v.modulo)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
        final t = _busca.toLowerCase();
        final filtrados = videos.where((v) {
          if (_modulo != 'todos' && v.modulo != _modulo) return false;
          if (t.isEmpty) return true;
          return [v.titulo, v.descricao, v.modulo, v.pagina]
              .whereType<String>()
              .any((x) => x.toLowerCase().contains(t));
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                onChanged: (v) => setState(() => _busca = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'Buscar vídeo, módulo ou página...',
                  isDense: true,
                ),
              ),
            ),
            if (modulos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<String>(
                  initialValue: _modulo,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Módulo', isDense: true),
                  items: [
                    const DropdownMenuItem(
                        value: 'todos', child: Text('Todos os módulos')),
                    ...modulos.map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setState(() => _modulo = v ?? 'todos'),
                ),
              ),
            Expanded(
              child: filtrados.isEmpty
                  ? const EmptyState(
                      icon: Icons.play_circle_outline,
                      title: 'Nenhum vídeo tutorial',
                      message: 'Ainda não há tutoriais disponíveis.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(tutoriaisVideosProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: filtrados.length,
                        itemBuilder: (context, i) =>
                            _VideoCard(video: filtrados[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video});

  final TutorialVideo video;

  @override
  Widget build(BuildContext context) {
    final id = video.videoId;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrir(id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: id == null
                  ? Container(
                      color: AppColors.muted,
                      child: const Center(
                        child: Text('URL inválida',
                            style: TextStyle(color: AppColors.mutedForeground)),
                      ),
                    )
                  : Image.network(
                      'https://i.ytimg.com/vi/$id/hqdefault.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.muted,
                        child: const Icon(Icons.play_circle_outline,
                            size: 48, color: AppColors.mutedForeground),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video.titulo,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  if ((video.descricao ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(video.descricao!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.mutedForeground)),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      if ((video.modulo ?? '').isNotEmpty)
                        _Tag(label: video.modulo!, cor: AppColors.primary),
                      if ((video.pagina ?? '').isNotEmpty)
                        _Tag(
                            label: video.pagina!,
                            cor: AppColors.mutedForeground),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrir(String? id) async {
    final url = id != null
        ? 'https://www.youtube.com/watch?v=$id'
        : video.youtubeUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.cor});

  final String label;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w600, color: cor)),
    );
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
