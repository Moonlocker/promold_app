import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/sistema.dart';

/// Geração do PDF do orçamento (sintético e detalhado).
class OrcamentoPdfService {
  OrcamentoPdfService._();

  static Future<void> gerar({
    required Orcamento orcamento,
    required List<Map<String, dynamic>> itens,
    String? organizacaoNome,
    double composicoesTotal = 0,
  }) async {
    final doc = pw.Document();

    final subtotalItens = itens.fold<double>(0, (a, it) {
      final qtd = (it['quantidade'] as num?)?.toDouble() ?? 0;
      final unit = (it['custo_unitario'] as num?)?.toDouble() ?? 0;
      final total = (it['custo_total'] as num?)?.toDouble() ?? (qtd * unit);
      return a + total;
    });
    final subtotal = subtotalItens + composicoesTotal;
    final bdi = orcamento.bdiAtivo
        ? subtotal * ((orcamento.percentualAjuste ?? 0) / 100)
        : 0.0;
    final total = subtotal + bdi;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _header(orcamento, organizacaoNome),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 8),
          pw.Text('Dados do orçamento',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [],
            data: [
              ['Cliente', orcamento.cliente],
              ['Endereço', orcamento.endereco ?? '—'],
              ['Contato', orcamento.contatoResponsavel ?? '—'],
              ['Telefone', orcamento.telefoneContato ?? '—'],
              ['Prazo', orcamento.prazoEstimado ?? '—'],
              ['Validade', orcamento.dataValidade ?? '—'],
              ['Status', orcamento.status],
            ],
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(90),
              1: const pw.FlexColumnWidth(3),
            },
            border: null,
          ),
          pw.SizedBox(height: 14),
          pw.Text('Itens',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Peça', 'Qtd', 'Custo unit.', 'Total'],
            headerStyle:
                pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey200),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.4),
              3: const pw.FlexColumnWidth(1.4),
            },
            data: itens.map((it) {
              final peca = it['pecas_catalogo'];
              final nome = peca is Map
                  ? (peca['nome'] as String? ?? 'Peça')
                  : 'Peça';
              final qtd = (it['quantidade'] as num?)?.toDouble() ?? 0;
              final unit = (it['custo_unitario'] as num?)?.toDouble() ?? 0;
              final tot =
                  (it['custo_total'] as num?)?.toDouble() ?? (qtd * unit);
              return [
                nome,
                _num(qtd),
                _moeda(unit),
                _moeda(tot),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 220,
              child: pw.Column(
                children: [
                  _linha('Subtotal', _moeda(subtotal)),
                  if (composicoesTotal > 0)
                    _linha('Composições (etapas)', _moeda(composicoesTotal)),
                  if (orcamento.bdiAtivo)
                    _linha('BDI (${orcamento.percentualAjuste ?? 0}%)',
                        _moeda(bdi)),
                  pw.Divider(),
                  _linha('Total', _moeda(total), destaque: true),
                ],
              ),
            ),
          ),
          if ((orcamento.observacoes ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('Observações',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text(orcamento.observacoes!,
                style: const pw.TextStyle(fontSize: 9)),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static pw.Widget _header(Orcamento orcamento, String? organizacaoNome) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(organizacaoNome ?? 'ProMold',
              style: pw.TextStyle(
                  fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('Orçamento #${orcamento.numeroOrcamento}',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text(orcamento.cliente,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  static pw.Widget _linha(String label, String valor, {bool destaque = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: destaque ? 11 : 9,
                  fontWeight:
                      destaque ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(valor,
              style: pw.TextStyle(
                  fontSize: destaque ? 12 : 9,
                  fontWeight:
                      destaque ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static String _moeda(double v) => 'R\$ ${v.toStringAsFixed(2)}';

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
