import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/logic/peca_calc.dart';
import '../models/obra_peca.dart';

/// Configuração de quais campos aparecem na etiqueta (porte de `EtiquetaConfig`).
class EtiquetaConfig {
  EtiquetaConfig({
    this.obra = true,
    this.categoria = true,
    this.identificador = true,
    this.dimensoes = true,
    this.volume = true,
    this.aco = true,
    this.peso = true,
    this.posicao = true,
    this.qrcode = true,
    this.personalizados = true,
  });

  bool obra;
  bool categoria;
  bool identificador;
  bool dimensoes;
  bool volume;
  bool aco;
  bool peso;
  bool posicao;
  bool qrcode;
  bool personalizados;
}

/// Geração de etiquetas (100×150mm) com QR Code, porte de `etiquetasPecas.ts`.
///
/// O QR contém apenas o UUID da peça.
class EtiquetasService {
  EtiquetasService._();

  static const _densidadeEtiqueta = 2400; // kg/m³ (igual ao webapp)

  static Future<void> imprimir({
    required String obraNome,
    required List<ObraPeca> pecas,
    Map<String, String> posicoes = const {},
    EtiquetaConfig? config,
  }) async {
    final cfg = config ?? EtiquetaConfig();
    final doc = pw.Document();

    for (final peca in pecas) {
      final calc = calcularPeca(peca);
      final volume = calc.volume;
      final aco = volume * (peca.kgAcoPorMetro ?? 0).toDouble();
      final peso = volume * _densidadeEtiqueta;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(100 * PdfPageFormat.mm, 150 * PdfPageFormat.mm,
              marginAll: 4 * PdfPageFormat.mm),
          build: (context) {
            final rows = <pw.Widget>[];

            if (cfg.obra) {
              rows.add(_cell('OBRA', obraNome));
            }
            if (cfg.posicao) {
              rows.add(_cell('POSIÇÃO NA MONTAGEM',
                  posicoes[peca.id] ?? '—'));
            }
            if (cfg.dimensoes) {
              rows.add(_dimensoes(peca));
            }

            final totais = <pw.Widget>[
              if (cfg.volume)
                _miniCell('VOLUME (m³)', volume.toStringAsFixed(3)),
              if (cfg.aco) _miniCell('AÇO (kg)', aco.toStringAsFixed(1)),
              if (cfg.peso) _miniCell('PESO (kg)', peso.toStringAsFixed(0)),
            ];
            if (totais.isNotEmpty) {
              rows.add(pw.Row(
                children: totais
                    .map((w) => pw.Expanded(child: w))
                    .toList(),
              ));
            }

            final campos = peca.pecaCatalogo?.camposPersonalizados ?? const [];
            if (cfg.personalizados && campos.isNotEmpty) {
              rows.add(_personalizados(peca, campos));
            }

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            peca.nomePeca.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (cfg.categoria &&
                              peca.pecaCatalogo?.categoria != null)
                            pw.Text(
                              peca.pecaCatalogo!.categoria!.nome.toUpperCase(),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                        ],
                      ),
                    ),
                    if (cfg.identificador && peca.identificador.isNotEmpty)
                      pw.Text(
                        peca.identificador,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                pw.SizedBox(height: 6),
                ...rows,
                pw.Spacer(),
                if (cfg.qrcode)
                  pw.Center(
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: peca.id,
                      width: 34 * PdfPageFormat.mm,
                      height: 34 * PdfPageFormat.mm,
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    final bytes = await doc.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  /// QR de identificação do local de estoque (50×80mm), payload = id do estoque.
  static Future<void> imprimirQrEstoque({
    required String nome,
    required String estoqueId,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(50 * PdfPageFormat.mm, 80 * PdfPageFormat.mm,
            marginAll: 4 * PdfPageFormat.mm),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              nome,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: estoqueId,
              width: 34 * PdfPageFormat.mm,
              height: 34 * PdfPageFormat.mm,
            ),
          ],
        ),
      ),
    );
    final bytes = await doc.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static pw.Widget _cell(String titulo, String valor) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(titulo,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          pw.Text(valor,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _miniCell(String titulo, String valor) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(right: 4, bottom: 4),
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(titulo,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          pw.Text(valor,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _dimensoes(ObraPeca peca) {
    final tipo = tipoCalculoDaPeca(peca);
    final cells = <pw.Widget>[];
    if (tipo == 'cilindrica') {
      cells.add(_miniCell('DIÂMETRO (m)', _n(peca.diametro)));
      cells.add(_miniCell('COMP (m)', _n(peca.comprimento)));
    } else if (tipo == 'nao_linear') {
      cells.add(_miniCell('COMP (m)', _n(peca.comprimento)));
      cells.add(_miniCell('VOL/m (m³/m)', _n(peca.volumeConcretoPorMetro)));
    } else {
      cells.add(_miniCell('LARG (m)', _n(peca.largura)));
      cells.add(_miniCell('ALT (m)', _n(peca.altura)));
      cells.add(_miniCell('COMP (m)', _n(peca.comprimento)));
    }
    return pw.Row(
      children: cells.map((w) => pw.Expanded(child: w)).toList(),
    );
  }

  static pw.Widget _personalizados(
    ObraPeca peca,
    List<Map<String, dynamic>> campos,
  ) {
    final widgets = <pw.Widget>[];
    for (final campo in campos) {
      final id = campo['id']?.toString();
      if (id == null) continue;
      final nome = campo['nome']?.toString() ?? id;
      final valor = peca.valoresPersonalizados[id]?.toString() ?? '—';
      widgets.add(_miniCell(nome.toUpperCase(), valor));
    }
    return pw.Wrap(spacing: 4, children: widgets);
  }

  static String _n(num? v) => v == null ? '—' : v.toString();
}
