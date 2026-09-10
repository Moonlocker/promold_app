import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/obra.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../tabs/obra_anexos_tab.dart';
import '../tabs/obra_fotos_tab.dart';
import '../tabs/obra_historico_tab.dart';
import '../tabs/obra_insumos_tab.dart';
import '../tabs/obra_pecas_tab.dart';
import '../tabs/obra_visao_geral_tab.dart';
import '../widgets/obra_form_sheet.dart';

/// Tela de detalhe da obra, com as abas do sistema web.
class ObraDetalheScreen extends ConsumerStatefulWidget {
  const ObraDetalheScreen({super.key, required this.obraId});

  final String obraId;

  @override
  ConsumerState<ObraDetalheScreen> createState() => _ObraDetalheScreenState();
}

class _ObraDetalheScreenState extends ConsumerState<ObraDetalheScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 9, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final obraAsync = ref.watch(obraProvider(widget.obraId));

    return obraAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(obraProvider(widget.obraId)),
        ),
      ),
      data: (obra) {
        if (obra == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Obra')),
            body: const Center(child: Text('Esta obra não existe ou foi removida.')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(obra.nome,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  obra.cliente,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'monitorar') _monitorar(obra);
                  if (v == 'editar') _editar(obra);
                  if (v == 'excluir') _excluir(obra);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'monitorar',
                    child: ListTile(
                      leading: Icon(Icons.notifications_outlined),
                      title: Text('Monitorar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'editar',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar obra'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'excluir',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline,
                          color: AppColors.destructive),
                      title: Text('Excluir',
                          style: TextStyle(color: AppColors.destructive)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Visão Geral'),
                Tab(text: 'Peças'),
                Tab(text: 'Visual'),
                Tab(text: '3D'),
                Tab(text: 'Insumos'),
                Tab(text: 'Planej.'),
                Tab(text: 'Fotos'),
                Tab(text: 'Anexos'),
                Tab(text: 'Histórico'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              ObraVisaoGeralTab(
                obra: obra,
                onVerPecas: () => _tabs.animateTo(1),
              ),
              ObraPecasTab(obraId: obra.id),
              const _EmBreveTab(
                icon: Icons.image_outlined,
                title: 'Painel Visual',
                message:
                    'O editor de mapa de montagem é uma ferramenta de tela grande. '
                    'Será avaliado para uma versão mobile.',
              ),
              const _EmBreveTab(
                icon: Icons.view_in_ar_outlined,
                title: 'Visão 3D',
                message:
                    'A visualização 3D/IFC depende de renderização pesada e será '
                    'tratada em etapa específica.',
              ),
              ObraInsumosTab(obraId: obra.id),
              const _EmBreveTab(
                icon: Icons.calendar_month_outlined,
                title: 'Planejamento',
                message:
                    'O planejamento semanal/montagem será migrado em etapa própria.',
              ),
              ObraFotosTab(obraId: obra.id),
              ObraAnexosTab(obraId: obra.id),
              ObraHistoricoTab(obraId: obra.id, obra: obra),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editar(Obra obra) async {
    final ok = await showObraFormSheet(context, ref, obra: obra);
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obra atualizada!')),
      );
    }
  }

  Future<void> _monitorar(Obra obra) async {
    final atual = await ref.read(obraMonitoramentoProvider(obra.id).future);
    if (!mounted) return;

    var producao = atual?.notifProducao ?? false;
    var carregamento = atual?.notifCarregamento ?? false;
    var aguardando = atual?.notifAguardando ?? false;
    var montagem = atual?.notifMontagem ?? false;
    var manual = atual?.notifManual ?? false;

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Monitorar Obra'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ative notificações para receber alertas.',
                style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nova peça produzida'),
                value: producao,
                onChanged: (v) => setDialog(() => producao = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Carregamento'),
                value: carregamento,
                onChanged: (v) => setDialog(() => carregamento = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aguardando Montagem'),
                value: aguardando,
                onChanged: (v) => setDialog(() => aguardando = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Montagem'),
                value: montagem,
                onChanged: (v) => setDialog(() => montagem = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Registros manuais'),
                value: manual,
                onChanged: (v) => setDialog(() => manual = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (salvar != true) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    try {
      await ref.read(obraHistoricoRepositoryProvider).upsertMonitoramento(
        obra.id,
        user.id,
        {
          'notif_producao': producao,
          'notif_carregamento': carregamento,
          'notif_aguardando': aguardando,
          'notif_montagem': montagem,
          'notif_manual': manual,
        },
      );
      ref.invalidate(obraMonitoramentoProvider(obra.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _excluir(Obra obra) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    final senhaController = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Obra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Ação irreversível. Todos os dados serão removidos: peças, '
                'histórico, fotos e anexos.',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: senhaController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Digite sua senha'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar exclusão'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref.read(authServiceProvider).signIn(
            email: user.email ?? '',
            password: senhaController.text,
          );
    } on AuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha incorreta.')),
        );
      }
      return;
    }

    try {
      final midia = ref.read(obraMidiaRepositoryProvider);
      final fotos = await ref.read(obraFotosProvider(obra.id).future);
      for (final f in fotos) {
        await midia.removeByUrl('obras-fotos', f.url);
      }
      final anexos = await ref.read(obraAnexosProvider(obra.id).future);
      for (final a in anexos) {
        await midia.removeByUrl('obras-anexos', a.url);
      }
      await ref.read(obrasRepositoryProvider).deleteObra(obra.id);
      ref.invalidate(obrasListProvider);
      if (mounted) context.go(AppRoutes.obras);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
      }
    }
  }
}

class _EmBreveTab extends StatelessWidget {
  const _EmBreveTab({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}
