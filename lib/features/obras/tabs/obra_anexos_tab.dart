import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/obra_midia.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/supabase_providers.dart';

const _tipos = {
  'projeto': ('Projeto', AppColors.primary, Icons.description_outlined),
  'contrato': ('Contrato', AppColors.success, Icons.assignment_outlined),
  'documento': ('Documento', AppColors.warning, Icons.insert_drive_file_outlined),
  'outro': ('Outro', AppColors.mutedForeground, Icons.folder_outlined),
};

/// Aba "Anexos" da obra.
class ObraAnexosTab extends ConsumerStatefulWidget {
  const ObraAnexosTab({super.key, required this.obraId});

  final String obraId;

  @override
  ConsumerState<ObraAnexosTab> createState() => _ObraAnexosTabState();
}

class _ObraAnexosTabState extends ConsumerState<ObraAnexosTab> {
  bool _enviando = false;

  @override
  Widget build(BuildContext context) {
    final anexosAsync = ref.watch(obraAnexosProvider(widget.obraId));

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _enviando ? null : _adicionar,
        icon: _enviando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.attach_file),
        label: const Text('Adicionar'),
      ),
      body: anexosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (anexos) {
          if (anexos.isEmpty) {
            return const EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'Nenhum anexo',
              message: 'Anexe projetos, contratos e documentos (máx. 50MB).',
            );
          }
          final grupos = <String, List<ObraAnexo>>{};
          for (final a in anexos) {
            grupos.putIfAbsent(a.tipo, () => []).add(a);
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(obraAnexosProvider(widget.obraId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: _tipos.keys
                  .where((t) => grupos.containsKey(t))
                  .map((t) {
                final lista = grupos[t]!;
                final cfg = _tipos[t]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 6),
                      child: Row(
                        children: [
                          Icon(cfg.$3, size: 16, color: cfg.$2),
                          const SizedBox(width: 6),
                          Text(
                            '${cfg.$1}s (${lista.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Card(
                      child: Column(
                        children: lista
                            .map((a) => _AnexoTile(
                                  anexo: a,
                                  color: cfg.$2,
                                  icon: cfg.$3,
                                  onAbrir: () => _abrir(a),
                                  onEditar: () => _editar(a),
                                  onExcluir: () => _excluir(a),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Future<void> _adicionar() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;

    setState(() => _enviando = true);
    final repo = ref.read(obraMidiaRepositoryProvider);
    try {
      for (final file in files) {
        final bytes = await file.readAsBytes();
        if (bytes.lengthInBytes > 50 * 1024 * 1024) continue;
        final url = await repo.uploadAnexo(
          obraId: widget.obraId,
          bytes: bytes,
          nomeArquivo: file.name,
        );
        await repo.addAnexo({
          'obra_id': widget.obraId,
          'nome': file.name,
          'url': url,
          'tipo': 'documento',
          'tamanho': bytes.lengthInBytes,
        });
      }
      ref.invalidate(obraAnexosProvider(widget.obraId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro no upload: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _abrir(ObraAnexo anexo) async {
    final uri = Uri.tryParse(anexo.url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _editar(ObraAnexo anexo) async {
    final nome = TextEditingController(text: anexo.nome);
    var tipo = anexo.tipo;
    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Editar anexo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nome,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: _tipos.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value.$1),
                        ))
                    .toList(),
                onChanged: (v) => setDialog(() => tipo = v ?? 'documento'),
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
    if (nome.text.trim().isEmpty) return;
    await ref.read(obraMidiaRepositoryProvider).updateAnexo(anexo.id, {
      'nome': nome.text.trim(),
      'tipo': tipo,
    });
    ref.invalidate(obraAnexosProvider(widget.obraId));
  }

  Future<void> _excluir(ObraAnexo anexo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir anexo'),
        content: Text('Deseja excluir "${anexo.nome}" permanentemente?'),
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
    final repo = ref.read(obraMidiaRepositoryProvider);
    await repo.removeByUrl('obras-anexos', anexo.url);
    await repo.deleteAnexo(anexo.id);
    ref.invalidate(obraAnexosProvider(widget.obraId));
  }
}

class _AnexoTile extends StatelessWidget {
  const _AnexoTile({
    required this.anexo,
    required this.color,
    required this.icon,
    required this.onAbrir,
    required this.onEditar,
    required this.onExcluir,
  });

  final ObraAnexo anexo;
  final Color color;
  final IconData icon;
  final VoidCallback onAbrir;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(anexo.nome, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${Formatters.arquivoTamanho(anexo.tamanho)} · ${Formatters.dataBr(anexo.createdAt)}',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: onAbrir,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (v) {
          if (v == 'abrir') onAbrir();
          if (v == 'editar') onEditar();
          if (v == 'excluir') onExcluir();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'abrir', child: Text('Abrir / baixar')),
          PopupMenuItem(value: 'editar', child: Text('Editar')),
          PopupMenuItem(
            value: 'excluir',
            child:
                Text('Excluir', style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
  }
}
