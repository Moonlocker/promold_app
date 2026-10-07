import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/mapa_montagem.dart';

/// Exportação do Mapa de Montagem (vistas) em PDF.
class MapaMontagemPdfService {
  MapaMontagemPdfService._();

  static Future<void> gerar({
    required String obraNome,
    required List<MapaMontagemVista> vistas,
    required Map<String, List<MapaMontagemCelula>> celulasPorVista,
    String? organizacaoNome,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Mapa de Montagem',
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(obraNome,
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(organizacaoNome ?? 'ProMold',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 10),
          if (vistas.isEmpty)
            pw.Text('Nenhuma vista cadastrada.',
                style: const pw.TextStyle(fontSize: 12))
          else
            for (final v in vistas) ...[
              pw.Text(v.nome,
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              if ((v.descricao ?? '').isNotEmpty)
                pw.Text(v.descricao!,
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700)),
              pw.SizedBox(height: 6),
              _grade(v, celulasPorVista[v.id] ?? const []),
              pw.SizedBox(height: 8),
              _legenda(),
              pw.SizedBox(height: 20),
            ],
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static pw.Widget _grade(
    MapaMontagemVista vista,
    List<MapaMontagemCelula> celulas,
  ) {
    final porPos = <String, MapaMontagemCelula>{
      for (final c in celulas) '${c.linha}:${c.coluna}': c,
    };
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        for (var l = 0; l < vista.linhas; l++)
          pw.TableRow(
            children: [
              for (var c = 0; c < vista.colunas; c++)
                _celula(porPos['$l:$c']),
            ],
          ),
      ],
    );
  }

  static pw.Widget _celula(MapaMontagemCelula? celula) {
    final ocupada = celula != null && !celula.vazia;
    return pw.Container(
      height: 26,
      alignment: pw.Alignment.center,
      color: ocupada ? _corStatus(celula.status) : PdfColors.white,
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(1),
        child: pw.Text(
          ocupada ? (celula.identificador ?? '•') : '',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 6),
        ),
      ),
    );
  }

  static pw.Widget _legenda() {
    final itens = <List<Object>>[
      ['pendente', _corStatus('pendente')],
      ['armada', _corStatus('armada')],
      ['concretada', _corStatus('concretada')],
      ['em estoque', _corStatus('em_estoque')],
      ['montada', _corStatus('montada')],
    ];
    return pw.Wrap(
      spacing: 10,
      runSpacing: 4,
      children: itens.map((it) {
        return pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(
              width: 10,
              height: 10,
              decoration: pw.BoxDecoration(
                color: it[1] as PdfColor,
                border: pw.Border.all(color: PdfColors.grey400, width: 0.4),
              ),
            ),
            pw.SizedBox(width: 4),
            pw.Text(it[0] as String, style: const pw.TextStyle(fontSize: 8)),
          ],
        );
      }).toList(),
    );
  }

  static PdfColor _corStatus(String? s) {
    switch (s) {
      case 'montada':
      case 'montado':
        return PdfColor.fromInt(0xFFDCFCE7);
      case 'em_estoque':
      case 'estoque':
        return PdfColor.fromInt(0xFFDBEAFE);
      case 'concretada':
      case 'concretado':
        return PdfColor.fromInt(0xFFFFEDD5);
      case 'armada':
      case 'armado':
        return PdfColor.fromInt(0xFFFEF9C3);
      default:
        return PdfColors.grey200;
    }
  }
}
