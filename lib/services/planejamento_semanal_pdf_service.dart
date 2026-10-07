import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils/formatters.dart';
import '../models/planejamento.dart';

/// Geração do PDF do Planejamento Semanal (armação/produção).
class PlanejamentoSemanalPdfService {
  PlanejamentoSemanalPdfService._();

  static Future<void> gerar({
    required String tipo,
    required String periodLabel,
    required PlanejamentoDados dados,
    String? organizacaoNome,
  }) async {
    final doc = pw.Document();
    final tipoLabel = tipo == 'armacao' ? 'Armação' : 'Produção';

    final diasComItens = dados.dias
        .where((d) => (dados.itensPorDia[d.diaStr] ?? const []).isNotEmpty)
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _header(tipoLabel, periodLabel, organizacaoNome),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 8),
          if (diasComItens.isEmpty)
            pw.Text('Nenhum item planejado no período.',
                style: const pw.TextStyle(fontSize: 11))
          else
            ...diasComItens.expand((dia) => [
                  _tituloDia(dia),
                  _tabelaItens(dados.itensPorDia[dia.diaStr] ?? const []),
                  pw.SizedBox(height: 14),
                ]),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static pw.Widget _header(
      String tipoLabel, String periodLabel, String? organizacaoNome) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Planejamento de $tipoLabel',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Período: $periodLabel',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
              pw.Text(organizacaoNome ?? 'ProMold',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _tituloDia(PlanejamentoDia dia) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: const pw.BoxDecoration(color: PdfColors.blue800),
      child: pw.Text(
        '${Formatters.dataBr(dia.dia)} · ${dia.diaNome.toUpperCase()}'
        '   (${dia.concluidos}/${dia.total} concluídas)',
        style: pw.TextStyle(
            fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _tabelaItens(List<PlanejamentoItem> itens) {
    final obras = <String, List<PlanejamentoItem>>{};
    for (final i in itens) {
      obras.putIfAbsent(i.obraNome, () => []).add(i);
    }
    final widgets = <pw.Widget>[];
    obras.forEach((obra, lista) {
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
        child: pw.Text(obra,
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
      ));
      widgets.add(pw.TableHelper.fromTextArray(
        headers: const ['Identificador', 'Peça', 'Status'],
        headerStyle:
            pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.4),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FlexColumnWidth(1.2),
        },
        data: lista
            .map((i) => [i.identificador, i.pecaNome, i.status])
            .toList(),
      ));
    });
    return pw.Column(children: widgets);
  }
}
