import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/xlsx_service.dart';
import '../theme/app_colors.dart';

/// Definição de coluna para importação XLSX.
class XlsxImportColumn {
  const XlsxImportColumn({
    required this.key,
    required this.label,
    this.required = false,
    this.isNumber = false,
    this.example = '',
  });

  final String key;
  final String label;
  final bool required;
  final bool isNumber;
  final String example;
}

/// Abre o assistente de importação XLSX. Retorna `true` se importou registros.
///
/// Fluxo: baixar modelo → enviar planilha preenchida → pré-visualizar →
/// confirmar. O [onImport] recebe as linhas já mapeadas para os [key]s das
/// colunas e deve retornar a quantidade importada.
Future<bool?> showXlsxImportSheet(
  BuildContext context, {
  required String title,
  required String templateName,
  required List<XlsxImportColumn> columns,
  required Future<int> Function(List<Map<String, dynamic>> rows) onImport,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _XlsxImportSheet(
      title: title,
      templateName: templateName,
      columns: columns,
      onImport: onImport,
    ),
  );
}

class _XlsxImportSheet extends StatefulWidget {
  const _XlsxImportSheet({
    required this.title,
    required this.templateName,
    required this.columns,
    required this.onImport,
  });

  final String title;
  final String templateName;
  final List<XlsxImportColumn> columns;
  final Future<int> Function(List<Map<String, dynamic>> rows) onImport;

  @override
  State<_XlsxImportSheet> createState() => _XlsxImportSheetState();
}

class _XlsxImportSheetState extends State<_XlsxImportSheet> {
  final List<Map<String, dynamic>> _preview = [];
  final List<String> _erros = [];
  bool _lendo = false;
  bool _importando = false;

  Future<void> _baixarModelo() async {
    try {
      await XlsxService.exportar(
        nomeArquivo: 'modelo-${widget.templateName}.xlsx',
        headers: widget.columns
            .map((c) => '${c.label}${c.required ? ' *' : ''}')
            .toList(),
        rows: [
          widget.columns.map((c) => c.example).toList(),
        ],
      );
    } catch (e) {
      _snack('Erro ao gerar modelo: $e');
    }
  }

  Future<void> _escolherArquivo() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls', 'csv'],
    );
    final file = res.firstOrNull;
    if (file == null) return;
    setState(() => _lendo = true);
    try {
      final bytes = await file.readAsBytes();
      final linhas = XlsxService.lerBytes(
        bytes,
        extensao: file.extension ?? file.name.split('.').last,
      );
      _processar(linhas);
    } catch (e) {
      _snack('Erro ao ler arquivo: $e');
    } finally {
      if (mounted) setState(() => _lendo = false);
    }
  }

  void _processar(List<List<String>> linhas) {
    _preview.clear();
    _erros.clear();
    if (linhas.isEmpty) {
      setState(() {});
      _snack('Planilha vazia');
      return;
    }
    // Cabeçalho = primeira linha; mapeia rótulo -> índice.
    final header = linhas.first
        .map((h) => h.replaceAll('*', '').trim().toLowerCase())
        .toList();
    final idxPorKey = <String, int>{};
    for (final col in widget.columns) {
      final i = header.indexOf(col.label.trim().toLowerCase());
      if (i >= 0) idxPorKey[col.key] = i;
    }

    // Se nenhuma coluna foi reconhecida, assume a ordem declarada.
    final porOrdem = idxPorKey.isEmpty;

    for (var r = 1; r < linhas.length; r++) {
      final linha = linhas[r];
      if (linha.every((v) => v.trim().isEmpty)) continue;
      final obj = <String, dynamic>{};
      var faltou = false;
      for (var c = 0; c < widget.columns.length; c++) {
        final col = widget.columns[c];
        final idx = porOrdem ? c : idxPorKey[col.key];
        final raw = (idx != null && idx < linha.length) ? linha[idx].trim() : '';
        if (col.required && raw.isEmpty) {
          _erros.add('Linha ${r + 1}: "${col.label}" é obrigatório');
          faltou = true;
        }
        if (raw.isEmpty) {
          obj[col.key] = null;
        } else if (col.isNumber) {
          obj[col.key] = _parseNumero(raw);
        } else {
          obj[col.key] = raw;
        }
      }
      if (!faltou) _preview.add(obj);
    }
    setState(() {});
    _snack('${_preview.length} linha(s) prontas para importar');
  }

  Future<void> _confirmar() async {
    if (_preview.isEmpty) return;
    setState(() => _importando = true);
    try {
      final n = await widget.onImport(_preview);
      if (mounted) Navigator.pop(context, true);
      _snack('$n registro(s) importado(s)');
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static num? _parseNumero(String raw) {
    var s = raw.replaceAll(RegExp(r'[^\d,.\-]'), '');
    if (s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }
    final n = double.tryParse(s);
    if (n == null) return null;
    return n == n.roundToDouble() ? n.toInt() : n;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Colunas: ${widget.columns.map((c) => '${c.label}${c.required ? ' *' : ''}').join(', ')}',
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importando ? null : _baixarModelo,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Baixar modelo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_importando || _lendo) ? null : _escolherArquivo,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Enviar planilha'),
                ),
              ),
            ],
          ),
          if (_lendo)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_erros.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_erros.length} aviso(s)',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.destructive)),
                  const SizedBox(height: 4),
                  ..._erros.take(6).map((e) => Text(e,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.destructive))),
                ],
              ),
            ),
          ],
          if (_preview.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('${_preview.length} linha(s) válida(s)',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success)),
            const SizedBox(height: 6),
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowHeight: 36,
                      dataRowMinHeight: 34,
                      dataRowMaxHeight: 44,
                      columns: widget.columns
                          .map((c) => DataColumn(
                                label: Text(c.label,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ))
                          .toList(),
                      rows: _preview
                          .map((r) => DataRow(
                                cells: widget.columns
                                    .map((c) => DataCell(Text(
                                          r[c.key]?.toString() ?? '',
                                          style:
                                              const TextStyle(fontSize: 11),
                                        )))
                                    .toList(),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed:
                (_importando || _preview.isEmpty) ? null : _confirmar,
            child: _importando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : Text('Importar ${_preview.length}'),
          ),
        ],
      ),
    );
  }
}
