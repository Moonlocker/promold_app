import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/sistema_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Anexos do orçamento (tabela `orcamentos_anexos`, bucket `orcamentos_anexos`).
class OrcamentoAnexosCard extends ConsumerStatefulWidget {
  const OrcamentoAnexosCard({super.key, required this.orcamentoId});

  final String orcamentoId;

  @override
  ConsumerState<OrcamentoAnexosCard> createState() =>
      _OrcamentoAnexosCardState();
}

class _OrcamentoAnexosCardState extends ConsumerState<OrcamentoAnexosCard> {
  bool _enviando = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orcamentoAnexosProvider(widget.orcamentoId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Anexos',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: _enviando ? null : _enviar,
                  icon: _enviando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file, size: 18),
                  label: const Text('Anexar'),
                ),
              ],
            ),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Erro: $e',
                  style: const TextStyle(color: AppColors.mutedForeground)),
              data: (anexos) {
                if (anexos.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Nenhum anexo.',
                        style: TextStyle(color: AppColors.mutedForeground)),
                  );
                }
                return Column(
                  children: [
                    for (final a in anexos) _AnexoRow(
                      anexo: a,
                      onChanged: () => ref.invalidate(
                          orcamentoAnexosProvider(widget.orcamentoId)),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enviar() async {
    final res = await FilePicker.pickFiles();
    final file = res.firstOrNull;
    if (file == null) return;
    setState(() => _enviando = true);
    final repo = ref.read(sistemaRepositoryProvider);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 50 * 1024 * 1024) {
        throw Exception('Arquivo acima de 50MB');
      }
      final url = await repo.uploadOrcamentoAnexo(
        orcamentoId: widget.orcamentoId,
        bytes: bytes,
        nomeArquivo: file.name,
      );
      await repo.addOrcamentoAnexo({
        'orcamento_id': widget.orcamentoId,
        'nome': file.name,
        'url': url,
        'tipo': file.extension,
        'tamanho': bytes.lengthInBytes,
      });
      ref.invalidate(orcamentoAnexosProvider(widget.orcamentoId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro no upload: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}

class _AnexoRow extends ConsumerWidget {
  const _AnexoRow({required this.anexo, required this.onChanged});

  final Map<String, dynamic> anexo;
  final VoidCallback onChanged;

  String get _id => anexo['id'] as String;
  String get _nome => (anexo['nome'] as String?) ?? 'Anexo';
  String get _url => (anexo['url'] as String?) ?? '';
  bool get _visivel => (anexo['visivel_publico'] as bool?) ?? false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tamanho = (anexo['tamanho'] as num?)?.toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () async {
                final uri = Uri.tryParse(_url);
                if (uri != null) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                  if (tamanho != null)
                    Text(Formatters.arquivoTamanho(tamanho),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedForeground)),
                ],
              ),
            ),
          ),
          Tooltip(
            message: 'Visível no link público',
            child: Switch(
              value: _visivel,
              onChanged: (v) async {
                await ref
                    .read(sistemaRepositoryProvider)
                    .updateOrcamentoAnexo(_id, {'visivel_publico': v});
                onChanged();
              },
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (v) {
              if (v == 'renomear') _renomear(context, ref);
              if (v == 'excluir') _excluir(context, ref);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'renomear', child: Text('Renomear')),
              PopupMenuItem(
                value: 'excluir',
                child: Text('Excluir',
                    style: TextStyle(color: AppColors.destructive)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _renomear(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: _nome);
    final novo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear anexo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (novo == null || novo.isEmpty) return;
    await ref
        .read(sistemaRepositoryProvider)
        .updateOrcamentoAnexo(_id, {'nome': novo});
    onChanged();
  }

  Future<void> _excluir(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir anexo'),
        content: Text('Excluir "$_nome"?'),
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
    if (confirmar != true) return;
    final repo = ref.read(sistemaRepositoryProvider);
    if (_url.isNotEmpty) {
      await repo.removeStorageByUrl('orcamentos_anexos', _url);
    }
    await repo.deleteOrcamentoAnexo(_id);
    onChanged();
  }
}

/// Histórico de acessos ao link público (tabela `orcamento_acesso_log`).
class OrcamentoAcessoLogCard extends ConsumerWidget {
  const OrcamentoAcessoLogCard({super.key, required this.orcamentoId});

  final String orcamentoId;

  static const _acoes = {
    'acesso_pagina': 'Acessou a página',
    'senha_inserida': 'Inseriu a senha',
    'visualizou_anexo': 'Visualizou anexo',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orcamentoAcessoLogProvider(orcamentoId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Histórico de acessos',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Erro: $e',
                  style: const TextStyle(color: AppColors.mutedForeground)),
              data: (logs) {
                if (logs.isEmpty) {
                  return const Text('Nenhum acesso registrado.',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.mutedForeground));
                }
                return Column(
                  children: logs.map((l) {
                    final acao = _acoes[(l['acao'] as String?) ?? ''] ??
                        (l['acao'] as String? ?? 'Ação');
                    final ua = (l['user_agent'] as String?) ?? '';
                    final detalhes = (l['detalhes'] as String?) ?? '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.visibility_outlined, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(acao,
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600)),
                                if (detalhes.isNotEmpty)
                                  Text(detalhes,
                                      style: const TextStyle(fontSize: 11.5)),
                                if (ua.isNotEmpty)
                                  Text(
                                    ua.length > 80
                                        ? '${ua.substring(0, 80)}…'
                                        : ua,
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.mutedForeground),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            Formatters.dataHoraBr(DateTime.tryParse(
                                (l['created_at'] as String?) ?? '')),
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.mutedForeground),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
