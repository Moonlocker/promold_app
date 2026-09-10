import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/obra_midia.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/supabase_providers.dart';

const _tipos = {
  'referencia': ('Referência', AppColors.primary),
  'progresso': ('Progresso', AppColors.warning),
  'finalizacao': ('Finalização', AppColors.success),
};

/// Aba "Fotos" da obra.
class ObraFotosTab extends ConsumerStatefulWidget {
  const ObraFotosTab({super.key, required this.obraId});

  final String obraId;

  @override
  ConsumerState<ObraFotosTab> createState() => _ObraFotosTabState();
}

class _ObraFotosTabState extends ConsumerState<ObraFotosTab> {
  bool _enviando = false;

  @override
  Widget build(BuildContext context) {
    final fotosAsync = ref.watch(obraFotosProvider(widget.obraId));

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
            : const Icon(Icons.add_a_photo_outlined),
        label: const Text('Adicionar'),
      ),
      body: fotosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (fotos) {
          if (fotos.isEmpty) {
            return const EmptyState(
              icon: Icons.photo_library_outlined,
              title: 'Nenhuma foto cadastrada',
              message: 'Adicione fotos de referência, progresso ou finalização.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(obraFotosProvider(widget.obraId)),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemCount: fotos.length,
              itemBuilder: (_, index) => _FotoCard(
                foto: fotos[index],
                onTap: () => _abrirVisualizador(fotos, index),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _adicionar() async {
    final tipo = await _escolherTipo();
    if (tipo == null) return;

    final picker = ImagePicker();
    final arquivos = await picker.pickMultiImage(imageQuality: 85);
    if (arquivos.isEmpty) return;

    setState(() => _enviando = true);
    final repo = ref.read(obraMidiaRepositoryProvider);
    try {
      for (final x in arquivos) {
        final bytes = await x.readAsBytes();
        if (bytes.lengthInBytes > 10 * 1024 * 1024) continue;
        final ext = x.path.split('.').last.toLowerCase();
        final url = await repo.uploadFoto(
          obraId: widget.obraId,
          bytes: bytes,
          extensao: ext.isEmpty ? 'jpg' : ext,
          contentType: 'image/$ext',
        );
        await repo.addFoto({
          'obra_id': widget.obraId,
          'url': url,
          'tipo': tipo,
        });
      }
      ref.invalidate(obraFotosProvider(widget.obraId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro no upload: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<String?> _escolherTipo() {
    var tipo = 'progresso';
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Nova foto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _tipos.entries
                .map((e) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        tipo == e.key
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: AppColors.primary,
                      ),
                      title: Text(e.value.$1),
                      onTap: () => setDialog(() => tipo = e.key),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, tipo),
              child: const Text('Selecionar fotos'),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirVisualizador(List<ObraFoto> fotos, int index) {
    showDialog<void>(
      context: context,
      builder: (_) => _FotoViewer(
        fotos: fotos,
        index: index,
        onEditar: (foto) => _editar(foto),
        onExcluir: (foto) {
          Navigator.pop(context);
          _excluir(foto);
        },
      ),
    );
  }

  Future<void> _editar(ObraFoto foto) async {
    var tipo = foto.tipo;
    final descricao = TextEditingController(text: foto.descricao ?? '');
    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Editar foto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: _tipos.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value.$1),
                        ))
                    .toList(),
                onChanged: (v) => setDialog(() => tipo = v ?? 'progresso'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descricao,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descrição'),
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
    await ref.read(obraMidiaRepositoryProvider).updateFoto(foto.id, {
      'tipo': tipo,
      'descricao': descricao.text.trim().isEmpty ? null : descricao.text.trim(),
    });
    ref.invalidate(obraFotosProvider(widget.obraId));
  }

  Future<void> _excluir(ObraFoto foto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir foto'),
        content: const Text('Deseja excluir esta foto permanentemente?'),
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
    await repo.removeByUrl('obras-fotos', foto.url);
    await repo.deleteFoto(foto.id);
    ref.invalidate(obraFotosProvider(widget.obraId));
  }
}

class _FotoCard extends StatelessWidget {
  const _FotoCard({required this.foto, required this.onTap});

  final ObraFoto foto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tipo = _tipos[foto.tipo] ?? _tipos['progresso']!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                foto.url,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.muted,
                  child: const Icon(Icons.broken_image_outlined,
                      color: AppColors.mutedForeground),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: tipo.$2.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              tipo.$1,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: tipo.$2,
              ),
            ),
          ),
          if (foto.descricao != null && foto.descricao!.isNotEmpty)
            Text(
              foto.descricao!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5),
            ),
          Text(
            Formatters.dataBr(foto.createdAt),
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _FotoViewer extends StatefulWidget {
  const _FotoViewer({
    required this.fotos,
    required this.index,
    required this.onEditar,
    required this.onExcluir,
  });

  final List<ObraFoto> fotos;
  final int index;
  final ValueChanged<ObraFoto> onEditar;
  final ValueChanged<ObraFoto> onExcluir;

  @override
  State<_FotoViewer> createState() => _FotoViewerState();
}

class _FotoViewerState extends State<_FotoViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.index);
  late int _atual = widget.index;

  @override
  Widget build(BuildContext context) {
    final foto = widget.fotos[_atual];
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.fotos.length,
            onPageChanged: (i) => setState(() => _atual = i),
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(
                child: Image.network(
                  widget.fotos[i].url,
                  errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () => widget.onEditar(foto),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: () => widget.onExcluir(foto),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (foto.descricao != null && foto.descricao!.isNotEmpty)
                  Text(foto.descricao!,
                      style: const TextStyle(color: Colors.white)),
                Text(
                  '${Formatters.dataLonga(foto.createdAt)} · ${_atual + 1} de ${widget.fotos.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
