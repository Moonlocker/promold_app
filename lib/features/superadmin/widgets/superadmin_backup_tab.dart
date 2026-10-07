import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/superadmin_providers.dart';
import '../../../providers/supabase_providers.dart';

/// SuperAdmin — aba Backup (edge function `org-backup`).
class SuperAdminBackupTab extends ConsumerStatefulWidget {
  const SuperAdminBackupTab({super.key});

  @override
  ConsumerState<SuperAdminBackupTab> createState() =>
      _SuperAdminBackupTabState();
}

class _SuperAdminBackupTabState extends ConsumerState<SuperAdminBackupTab> {
  String? _orgId;
  bool _incluirStorage = true;
  bool _processando = false;
  Map<String, dynamic>? _manifest;
  String? _resultado;

  @override
  Widget build(BuildContext context) {
    final orgs = ref.watch(todasOrganizacoesProvider).value ?? const [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Exportar backup',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _orgId,
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
                  onChanged: (v) => setState(() {
                    _orgId = v;
                    _manifest = null;
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Incluir arquivos (Storage)'),
                  value: _incluirStorage,
                  onChanged: (v) => setState(() => _incluirStorage = v),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _processando || _orgId == null
                            ? null
                            : _verManifesto,
                        icon: const Icon(Icons.list_alt, size: 18),
                        label: const Text('Ver manifesto'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _processando || _orgId == null
                            ? null
                            : _exportar,
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Exportar'),
                      ),
                    ),
                  ],
                ),
                if (_manifest != null) ...[
                  const SizedBox(height: 12),
                  _manifesto(_manifest!),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Importar backup',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                  'Selecione um arquivo .json exportado anteriormente.',
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _processando ? null : _importar,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Selecionar arquivo .json'),
                ),
              ],
            ),
          ),
        ),
        if (_processando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_resultado != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resultado',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(_resultado!,
                      style: const TextStyle(
                          fontSize: 12.5, fontFamily: 'monospace')),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _manifesto(Map<String, dynamic> m) {
    final tables = (m['tables'] as List?) ?? const [];
    final buckets = (m['buckets'] as List?) ?? const [];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tabelas (${tables.length})',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            tables
                .map((t) => '${t['table']}: ${t['count']}')
                .join(', '),
            style: const TextStyle(fontSize: 11.5),
          ),
          if (buckets.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Buckets (${buckets.length})',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              buckets
                  .map((b) => '${b['bucket']}: ${b['files']} arq.')
                  .join(', '),
              style: const TextStyle(fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _verManifesto() async {
    setState(() => _processando = true);
    try {
      final m = await ref.read(superAdminRepositoryProvider).backupManifest(_orgId!);
      setState(() => _manifest = m);
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _exportar() async {
    setState(() => _processando = true);
    try {
      final res = await ref
          .read(superAdminRepositoryProvider)
          .backupExport(_orgId!, includeStorage: _incluirStorage);
      final backup = res['backup'];
      if (backup == null) {
        _snack('Nenhum dado retornado');
        return;
      }
      final bytes = Uint8List.fromList(
          utf8.encode(jsonEncode(backup)));
      final uri = await FilePicker.saveFile(
        fileName:
            'backup-${_orgId!.substring(0, 8)}-${DateTime.now().millisecondsSinceEpoch}.json',
        bytes: bytes,
        mimeType: 'application/json',
      );
      if (uri != null) _snack('Backup exportado');
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _importar() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final file = res.firstOrNull;
    if (file == null) return;
    setState(() {
      _processando = true;
      _resultado = null;
    });
    try {
      final bytes = await file.readAsBytes();
      final backup = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final resultado = await ref
          .read(superAdminRepositoryProvider)
          .backupImport(backup);
      final results = (resultado['results'] as List?) ?? const [];
      final storage = (resultado['storage'] as List?) ?? const [];
      setState(() {
        _resultado = 'Tabelas: ${results.length} processada(s)\n'
            'Storage: ${storage.length} bucket(s)\n'
            '${results.map((r) => '${r['table']}: ${r['inserted']} inseridos').join('\n')}';
      });
    } catch (e) {
      _snack('Erro ao importar: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
