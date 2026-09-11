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
import '../../../services/obra_relatorio_service.dart';
import '../tabs/obra_anexos_tab.dart';
import '../tabs/obra_3d_tab.dart';
import '../tabs/obra_fotos_tab.dart';
import '../tabs/obra_historico_tab.dart';
import '../tabs/obra_insumos_tab.dart';
import '../tabs/obra_painel_tab.dart';
import '../tabs/obra_pecas_tab.dart';
import '../tabs/obra_planejamento_tab.dart';
import '../tabs/obra_visao_geral_tab.dart';
import '../tabs/obra_visual_tab.dart';
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
  late final TabController _tabs = TabController(length: 10, vsync: this);

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
            body: const Center(child: Text('Esta obra nÃ£o existe ou foi removida.')),
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
                  if (v == 'relatorio') _relatorio(obra);
                  if (v == 'editar') _editar(obra);
                  if (v == 'excluir') _excluir(obra);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'monitorar',
                    child: ListTile(
                      leading: Icon(Icons.notifications_outlined),
                      title: Text('Monitorar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'relatorio',
                    child: ListTile(
                      leading: Icon(Icons.picture_as_pdf_outlined),
                      title: Text('Relatório PDF'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (ref.podeEditar('obras'))
                    const PopupMenuItem(
                      value: 'editar',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar obra'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (ref.podeExcluir('obras'))
                    const PopupMenuItem(
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
                Tab(text: 'VisÃ£o Geral'),
                Tab(text: 'Painel'),
                Tab(text: 'PeÃ§as'),
                Tab(text: 'Visual'),
                Tab(text: '3D'),
                Tab(text: 'Insumos'),
                Tab(text: 'Planej.'),
                Tab(text: 'Fotos'),
                Tab(text: 'Anexos'),
                Tab(text: 'HistÃ³rico'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              ObraVisaoGeralTab(
                obra: obra,
                onVerPecas: () => _tabs.animateTo(2),
              ),
              ObraPainelTab(obraId: obra.id),
              ObraPecasTab(obraId: obra.id),
              ObraVisualTab(obraId: obra.id),
              Obra3DTab(obraId: obra.id),
              ObraInsumosTab(obraId: obra.id),
              ObraPlanejamentoTab(obraId: obra.id),
              ObraFotosTab(obraId: obra.id),
              ObraAnexosTab(obraId: obra.id),
              ObraHistoricoTab(obraId: obra.id, obra: obra),
            ],
          ),
        );
      },
    );
  }

  Future<void> _relatorio(Obra obra) async {
    try {
      final pecas = await ref.read(obrasPecasProvider(obra.id).future);
      await ObraRelatorioService.gerar(obra: obra, pecas: pecas);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
      }
    }
  }

  Future<void> _editar(Obra obra) async {    final ok = await showObraFormSheet(context, ref, obra: obra);
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
                'Ative notificaÃ§Ãµes para receber alertas.',
                style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nova peÃ§a produzida'),
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
          const SnackBar(content: Text('ConfiguraÃ§Ãµes salvas!')),
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
                'AÃ§Ã£o irreversÃ­vel. Todos os dados serÃ£o removidos: peÃ§as, '
                'histÃ³rico, fotos e anexos.',
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
            child: const Text('Confirmar exclusÃ£o'),
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
