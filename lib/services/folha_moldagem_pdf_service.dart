import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils/formatters.dart';
import '../models/qc.dart';

/// Geração da "Folha de Moldagem e Controle de Resistência de Corpos-de-Prova"
/// em PDF (formato paisagem), preenchida com os dados do lote e dos CPs e com
/// campos em branco para preenchimento/assinatura em campo.
class FolhaMoldagemPdfService {
  FolhaMoldagemPdfService._();

  static Future<void> gerar({
    required QcLote lote,
    required List<QcCorpoProva> cps,
    String? organizacaoNome,
    String? obraNome,
  }) async {
    final doc = pw.Document();
    final dataConcretagem =
        Formatters.dataBr(DateTime.tryParse(lote.dataConcretagem));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        header: (context) => _header(lote, organizacaoNome),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 6),
          _resumo(lote, obraNome, dataConcretagem),
          pw.SizedBox(height: 12),
          pw.Text('Corpos de prova',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          _tabelaCps(cps),
          pw.SizedBox(height: 14),
          _assinaturas(),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static pw.Widget _header(QcLote lote, String? organizacaoNome) {
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
          pw.Center(
            child: pw.Text(
              'CONTROLE DE MOLDAGEM E RESISTÊNCIA DE CORPOS-DE-PROVA',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(organizacaoNome ?? 'ProMold',
                  style: const pw.TextStyle(
                      fontSize: 8.5, color: PdfColors.grey700)),
              pw.Text('Lote: ${lote.codigo}',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text('Folha: ____ / ____',
                  style: const pw.TextStyle(
                      fontSize: 8.5, color: PdfColors.grey700)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _resumo(
      QcLote lote, String? obraNome, String dataConcretagem) {
    final itens = <List<String>>[
      ['Data de concretagem', dataConcretagem],
      ['Hora de moldagem', _txt(lote.horaMoldagem)],
      ['FCK (MPa)', lote.fckMpa.toStringAsFixed(1)],
      ['FCJ (MPa)', lote.fcjMpa != null ? lote.fcjMpa!.toStringAsFixed(1) : '—'],
      ['Traço', _txt(lote.traco)],
      ['Slump', _txt(lote.slump)],
      ['Fornecedor', _txt(lote.fornecedor)],
      ['Volume (m³)', lote.volumeM3 != null ? '${lote.volumeM3}' : '—'],
      ['Fôrma de produção', _txt(lote.formaProducao)],
      ['Laboratorista', _txt(lote.laboratorista)],
      ['Responsável', _txt(lote.responsavel)],
      ['Obra', _txt(obraNome)],
    ];
    return pw.Wrap(
      spacing: 8,
      runSpacing: 6,
      children: itens.map((it) {
        return pw.Container(
          width: 158,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(it[0],
                  style: const pw.TextStyle(
                      fontSize: 7, color: PdfColors.grey700)),
              pw.SizedBox(height: 1),
              pw.Text(it[1],
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _tabelaCps(List<QcCorpoProva> cps) {
    final headers = [
      'Identificador',
      'Idade',
      'Data de moldagem',
      'Data prevista de ruptura',
      'Grupo',
      'Horário de ruptura',
      'Carga (kN)',
      'Tensão (MPa)',
      'Resultado (MPa)',
      'Observações',
    ];
    final data = <List<String>>[];
    if (cps.isEmpty) {
      for (var i = 0; i < 6; i++) {
        data.add(List<String>.filled(headers.length, ''));
      }
    } else {
      for (final cp in cps) {
        data.add([
          cp.identificador,
          _idade(cp),
          Formatters.dataBr(DateTime.tryParse(cp.dataMoldagem)),
          cp.dataPrevistaRompimento != null
              ? Formatters.dataBr(
                  DateTime.tryParse(cp.dataPrevistaRompimento!))
              : '',
          cp.grupo ?? '',
          '',
          '',
          '',
          '',
          cp.observacoes ?? '',
        ]);
      }
    }
    return pw.TableHelper.fromTextArray(
      headers: headers,
      headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 7),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      headerAlignment: pw.Alignment.center,
      cellAlignment: pw.Alignment.centerLeft,
      cellHeight: 20,
      data: data,
    );
  }

  static pw.Widget _assinaturas() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _linhaAssinatura('Laboratorista'),
        _linhaAssinatura('Responsável técnico'),
        _linhaAssinatura('Fiscalização'),
      ],
    );
  }

  static pw.Widget _linhaAssinatura(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(height: 24),
        pw.Container(width: 180, height: 0.8, color: PdfColors.grey500),
        pw.SizedBox(height: 2),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  static String _idade(QcCorpoProva cp) {
    if (cp.idadeHoras != null && cp.idadeHoras! > 0) {
      return '${cp.idadeHoras}h';
    }
    return '${cp.idadeRompimentoDias}d';
  }

  static String _txt(String? v) =>
      (v == null || v.trim().isEmpty) ? '—' : v;
}
