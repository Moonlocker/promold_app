import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/qc.dart';
import '../../../providers/qualidade_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Bottom sheet para gerenciar anexos (laudos/fotos) de um CP ou ensaio.
Future<void> showQcAnexosSheet(
  BuildContext context, {
  required String ownerType,
  required String ownerId,
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _QcAnexosSheet(
      ownerType: ownerType,
      ownerId: ownerId,
      title: title,
    ),
  );
}

class _QcAnexosSheet extends ConsumerStatefulWidget {
  const _QcAnexosSheet({
    required this.ownerType,
    required this.ownerId,
    required this.title,
  });

  final String ownerType;
  final String ownerId;
  final String title;

  @override
  ConsumerState<_QcAnexosSheet> createState() => _QcAnexosSheetState();
}

class _QcAnexosSheetState extends ConsumerState<_QcAnexosSheet> {
  bool _enviando = false;

  (String, String) get _key => (widget.ownerType, widget.ownerId);

  Future<void> _enviarArquivo() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
    );
    if (files.isEmpty) return;
    await _enviar(() async {
      final file = files.first;
      final bytes = await file.readAsBytes();
      await ref.read(qualidadeRepositoryProvider).uploadAnexo(
            ownerType: widget.ownerType,
            ownerId: widget.ownerId,
            bytes: bytes,
            nome: file.name,
            contentType: _contentType(file.name),
          );
    });
  }

  Future<void> _enviarImagem(ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 2200,
    );
    if (img == null) return;
    await _enviar(() async {
      final bytes = await img.readAsBytes();
      await ref.read(qualidadeRepositoryProvider).uploadAnexo(
            ownerType: widget.ownerType,
            ownerId: widget.ownerId,
            bytes: bytes,
            nome: img.name,
            contentType: 'image/${img.name.split('.').last.toLowerCase()}',
          );
    });
  }

  Future<void> _enviar(Future<void> Function() acao) async {
    setState(() => _enviando = true);
    try {
      await acao();
      ref.invalidate(qcAnexosProvider(_key));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anexo enviado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro no upload: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _abrir(QcAnexo a) async {
    final uri = Uri.tryParse(a.url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _excluir(QcAnexo a) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir anexo'),
        content: Text('Deseja excluir "${a.nome}" permanentemente?'),
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
    try {
      await ref.read(qualidadeRepositoryProvider).deleteAnexo(a);
      ref.invalidate(qcAnexosProvider(_key));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(qcAnexosProvider(_key));
    final anexos = async.value ?? const <QcAnexo>[];
    final bottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Anexos · ${widget.title}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (_enviando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _enviando ? null : () => _enviarImagem(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Câmera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _enviando ? null : () => _enviarImagem(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Galeria'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _enviando ? null : _enviarArquivo,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Arquivo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (async.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (anexos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Nenhum anexo',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedForeground)),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: anexos.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final a = anexos[i];
                  final isImg = (a.tipo ?? '').startsWith('image');
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isImg ? Icons.image_outlined : Icons.picture_as_pdf,
                      color: AppColors.primary,
                    ),
                    title: Text(a.nome, overflow: TextOverflow.ellipsis),
                    subtitle: a.tamanho != null
                        ? Text(_tamanho(a.tamanho!),
                            style: const TextStyle(fontSize: 11.5))
                        : null,
                    onTap: () => _abrir(a),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.destructive, size: 20),
                      onPressed: () => _excluir(a),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  static String _contentType(String nome) {
    final ext = nome.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  static String _tamanho(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
