import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/logic/peca_calc.dart';
import '../core/logic/status_config.dart';
import '../models/obra.dart';
import '../models/obra_peca.dart';

/// Geração do Relatório Geral da obra em PDF.
class ObraRelatorioService {
  ObraRelatorioService._();

  static const _densidade = 2400.0;

  static Future<void> gerar({
    required Obra obra,
    required List<ObraPeca> pecas,
    Map<String, dynamic>? insumosResumo,
  }) async {
    final doc = pw.Document();
    final contagem = <String, int>{};
    var volume = 0.0;
    var aco = 0.0;
    var peso = 0.0;
    for (final p in pecas) {
      final key = normalizarStatus(p.status);
      contagem[key] = (contagem[key] ?? 0) + 1;
      final v = calcularPeca(p).volume;
      volume += v;
      aco += v * (p.kgAcoPorMetro ?? 0).toDouble();
      peso += v * _densidade;
    }
    final progresso = pecas.isEmpty
        ? 0
        : (pecas.fold<double>(
                    0, (a, p) => a + statusWeight(p.status)) /
                pecas.length)
            .round();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _header(obra),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 8),
          pw.Text('Resumo',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _kpiGrid([
            ['Progresso', '$progresso%'],
            ['Total de peças', '${pecas.length}'],
            ['Volume de concreto', '${volume.toStringAsFixed(2)} m³'],
            ['Aço estimado', '${aco.toStringAsFixed(0)} kg'],
            ['Peso estimado', '${peso.toStringAsFixed(0)} kg'],
            [
              'Valor da obra',
              obra.valorObra != null
                  ? 'R\$ ${obra.valorObra!.toStringAsFixed(2)}'
                  : '—'
            ],
          ]),
          pw.SizedBox(height: 16),
          pw.Text('Peças por status',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _tabelaStatus(contagem, pecas.length),
          pw.SizedBox(height: 16),
          pw.Text('Peças',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _tabelaPecas(pecas),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static pw.Widget _header(Obra obra) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Relatório Geral da Obra',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(obra.nome,
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Text(
            '${obra.cliente}'
            '${obra.endereco != null ? ' · ${obra.endereco}' : ''}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Status: ${obra.status}'
            '${obra.dataInicio != null ? ' · Início: ${_fmt(obra.dataInicio!)}' : ''}'
            '${obra.dataPrevisao != null ? ' · Previsão: ${_fmt(obra.dataPrevisao!)}' : ''}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _kpiGrid(List<List<String>> items) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((it) {
        return pw.Container(
          width: 165,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(it[0],
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              pw.Text(it[1],
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _tabelaStatus(Map<String, int> contagem, int total) {
    return pw.TableHelper.fromTextArray(
      headers: ['Status', 'Quantidade', '%'],
      headerStyle:
          pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      data: statusOrdem.map((s) {
        final n = contagem[s] ?? 0;
        final pct = total == 0 ? 0 : (n / total * 100).round();
        return [statusLabel(s), '$n', '$pct%'];
      }).toList(),
    );
  }

  static pw.Widget _tabelaPecas(List<ObraPeca> pecas) {
    final rows = pecas.map((p) {
      final v = calcularPeca(p).volume;
      return [
        p.identificador,
        p.nomePeca,
        _dimensoes(p),
        statusLabel(p.status),
        v.toStringAsFixed(3),
      ];
    }).toList();
    return pw.TableHelper.fromTextArray(
      headers: ['ID', 'Peça', 'Dimensões (m)', 'Status', 'Volume (m³)'],
      headerStyle:
          pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(2.4),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1.4),
        4: const pw.FlexColumnWidth(1.2),
      },
      data: rows,
    );
  }

  static String _dimensoes(ObraPeca p) {
    final partes = [
      p.largura,
      p.altura,
      if (p.comprimento != null) p.comprimento,
    ].where((e) => e != null).map((e) => e.toString()).toList();
    return partes.isEmpty ? '—' : partes.join(' × ');
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
