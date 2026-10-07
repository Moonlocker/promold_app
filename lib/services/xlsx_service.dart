import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

/// Utilitário de leitura e escrita de planilhas XLSX (pacote `excel`).
class XlsxService {
  XlsxService._();

  static const _mimeXlsx =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Salva uma planilha XLSX com [headers] e [rows]. Retorna `true` se salvo.
  static Future<bool> exportar({
    required String nomeArquivo,
    required List<String> headers,
    required List<List<Object?>> rows,
    String aba = 'Planilha',
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != aba) {
      excel.delete(defaultSheet);
    }
    final sheet = excel[aba];
    sheet.appendRow(headers.map<CellValue>(TextCellValue.new).toList());
    for (final row in rows) {
      sheet.appendRow(row.map<CellValue>(_toCell).toList());
    }
    final bytes = excel.encode();
    if (bytes == null) return false;
    final uri = await FilePicker.saveFile(
      fileName: nomeArquivo,
      bytes: Uint8List.fromList(bytes),
      mimeType: _mimeXlsx,
    );
    return uri != null;
  }

  /// Lê a primeira aba de um arquivo XLSX/XLS e devolve linhas de texto.
  static List<List<String>> lerBytes(Uint8List bytes, {String? extensao}) {
    final ext = (extensao ?? '').toLowerCase();
    if (ext == 'csv') return _lerCsv(bytes);
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return const [];
    final sheet = excel.tables.values.first;
    final linhas = <List<String>>[];
    for (final row in sheet.rows) {
      linhas.add(row.map((c) => _texto(c?.value)).toList());
    }
    return linhas;
  }

  static CellValue _toCell(Object? v) {
    if (v == null) return TextCellValue('');
    if (v is int) return IntCellValue(v);
    if (v is double) return DoubleCellValue(v);
    if (v is bool) return BoolCellValue(v);
    return TextCellValue(v.toString());
  }

  static String _texto(CellValue? v) {
    if (v == null) return '';
    if (v is TextCellValue) return v.value.text ?? '';
    return v.toString();
  }

  static List<List<String>> _lerCsv(Uint8List bytes) {
    var texto = String.fromCharCodes(bytes);
    if (texto.startsWith('\uFEFF')) texto = texto.substring(1);
    final sep = texto.contains(';') ? ';' : ',';
    final linhas = <List<String>>[];
    for (final linha in texto.split(RegExp(r'\r?\n'))) {
      if (linha.trim().isEmpty) continue;
      linhas.add(_splitCsv(linha, sep));
    }
    return linhas;
  }

  static List<String> _splitCsv(String linha, String sep) {
    final out = <String>[];
    final sb = StringBuffer();
    var aspas = false;
    for (var i = 0; i < linha.length; i++) {
      final ch = linha[i];
      if (ch == '"') {
        if (aspas && i + 1 < linha.length && linha[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          aspas = !aspas;
        }
      } else if (ch == sep && !aspas) {
        out.add(sb.toString());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    out.add(sb.toString());
    return out;
  }
}
