import 'dart:io';
import 'dart:typed_data';

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
    List<Map<String, dynamic>> headerBlocks = const [],
    List<Map<String, dynamic>> footerBlocks = const [],
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

    final vars = <String, String>{
      'cliente': orcamento.cliente,
      'endereco': orcamento.endereco ?? '',
      'numero_orcamento': '${orcamento.numeroOrcamento}',
      'data_emissao': orcamento.dataCriacao ?? '',
      'data_validade': orcamento.dataValidade ?? '',
      'prazo_estimado': orcamento.prazoEstimado ?? '',
      'contato_responsavel': orcamento.contatoResponsavel ?? '',
      'telefone_contato': orcamento.telefoneContato ?? '',
      'metros_quadrados': '',
      'valor_total': _moeda(total),
      'empresa_nome': organizacaoNome ?? 'ProMold',
      'observacoes': orcamento.observacoes ?? '',
    };

    // Pré-carrega imagens usadas nos blocos.
    final imagens = <String, Uint8List>{};
    for (final b in [...headerBlocks, ...footerBlocks]) {
      if (b['type'] == 'image') {
        final url = (b['imageUrl'] as String?) ?? '';
        if (url.isNotEmpty && !imagens.containsKey(url)) {
          final bytes = await _baixarImagem(url);
          if (bytes != null) imagens[url] = bytes;
        }
      }
    }

    final usaHeaderCustom = headerBlocks.isNotEmpty;
    final usaFooterCustom = footerBlocks.isNotEmpty;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => usaHeaderCustom
            ? _blocos(headerBlocks, vars, imagens)
            : _header(orcamento, organizacaoNome),
        footer: (context) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (usaFooterCustom)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: _blocos(footerBlocks, vars, imagens),
              ),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ),
          ],
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

  static pw.Widget _blocos(
    List<Map<String, dynamic>> blocks,
    Map<String, String> vars,
    Map<String, Uint8List> imagens,
  ) {
    final widgets = <pw.Widget>[];
    for (final b in blocks) {
      final type = b['type'] as String? ?? 'text';
      final align = _align(b['align'] as String?);
      final size = (b['fontSize'] as num?)?.toDouble() ?? 10;
      final bold = (b['bold'] as bool?) ?? false;
      final italic = (b['italic'] as bool?) ?? false;
      switch (type) {
        case 'line':
          widgets.add(pw.Divider(color: PdfColors.grey400));
          break;
        case 'spacer':
          widgets.add(
              pw.SizedBox(height: (b['height'] as num?)?.toDouble() ?? 12));
          break;
        case 'image':
          final url = (b['imageUrl'] as String?) ?? '';
          final bytes = imagens[url];
          if (bytes != null) {
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Image(pw.MemoryImage(bytes),
                    height: 40, fit: pw.BoxFit.contain),
              ),
            );
          }
          break;
        case 'title':
        case 'text':
        default:
          widgets.add(
            pw.Text(
              resolveTexto((b['content'] as String?) ?? '', vars),
              textAlign: align,
              style: pw.TextStyle(
                fontSize: size,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontStyle:
                    italic ? pw.FontStyle.italic : pw.FontStyle.normal,
              ),
            ),
          );
      }
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  /// Substitui as variáveis `{{chave}}` pelos valores informados.
  static String resolveTexto(String text, Map<String, String> vars) {
    var out = text;
    vars.forEach((k, v) {
      out = out.replaceAll('{{$k}}', v);
    });
    return out;
  }

  static pw.TextAlign _align(String? a) {
    switch (a) {
      case 'center':
        return pw.TextAlign.center;
      case 'right':
        return pw.TextAlign.right;
      default:
        return pw.TextAlign.left;
    }
  }

  static Future<Uint8List?> _baixarImagem(String url) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return null;
      }
      final bytes = await response.fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );
      client.close();
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
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
