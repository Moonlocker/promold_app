import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/logic/peca_calc.dart';
import '../../core/logic/status_config.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/qr_scanner_view.dart';
import '../../models/leitor.dart';
import '../../models/peca_catalogo.dart';
import '../../providers/obra_providers.dart';
import '../../providers/supabase_providers.dart';
import '../obras/widgets/obra_peca_edit_sheet.dart';

/// Leitor de Consulta: mostra todos os dados de uma peça escaneada.
class LeitorConsultaScreen extends ConsumerStatefulWidget {
  const LeitorConsultaScreen({super.key});

  @override
  ConsumerState<LeitorConsultaScreen> createState() =>
      _LeitorConsultaScreenState();
}

class _LeitorConsultaScreenState extends ConsumerState<LeitorConsultaScreen> {
  bool _manual = false;
  bool _processando = false;
  String? _erro;
  PecaConsulta? _peca;

  final _busca = TextEditingController();
  List<Map<String, dynamic>> _resultados = [];

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _consultar(String codigo) async {
    if (_processando) return;
    setState(() {
      _processando = true;
      _erro = null;
    });
    try {
      final peca = await ref.read(leitorServiceProvider).consultar(codigo);
      if (peca == null) {
        setState(() => _erro = 'Peça não encontrada');
      } else {
        setState(() => _peca = peca);
      }
    } catch (e) {
      setState(() => _erro = 'Erro ao consultar: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _buscarManual(String termo) async {
    if (termo.trim().isEmpty) {
      setState(() => _resultados = []);
      return;
    }
    final res = await ref.read(leitorServiceProvider).buscarPecasManual(termo);
    if (mounted) setState(() => _resultados = res);
  }

  void _reset() {
    setState(() {
      _peca = null;
      _erro = null;
      _busca.clear();
      _resultados = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consultar Peça')),
      body: _peca != null ? _resultado(_peca!) : _entrada(),
    );
  }

  Widget _entrada() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: false, icon: Icon(Icons.qr_code), label: Text('QR Code')),
            ButtonSegment(
                value: true, icon: Icon(Icons.keyboard), label: Text('Manual')),
          ],
          selected: {_manual},
          onSelectionChanged: (s) => setState(() => _manual = s.first),
        ),
        const SizedBox(height: 12),
        if (!_manual)
          Card(
            clipBehavior: Clip.antiAlias,
            child: QrScannerView(
              paused: _processando,
              onDetected: _consultar,
              hint: 'Aponte para o QR Code da peça',
            ),
          ),
        if (_manual) ...[
          TextField(
            controller: _busca,
            textInputAction: TextInputAction.search,
            onChanged: _buscarManual,
            onSubmitted: _consultar,
            decoration: InputDecoration(
              hintText: 'Identificador ou código da peça',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code),
                onPressed: () => _consultar(_busca.text),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._resultados.map(
            (r) => Card(
              child: ListTile(
                title: Text(r['identificador']?.toString() ?? ''),
                subtitle: Text(
                  (r['obra'] is Map ? r['obra']['nome'] : '')?.toString() ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: PecaStatusChipInline(
                    status: r['status']?.toString() ?? 'pendente'),
                onTap: () => _consultar(r['identificador']?.toString() ?? ''),
              ),
            ),
          ),
        ],
        if (_processando)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_erro != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_erro!,
                style: const TextStyle(color: AppColors.destructive)),
          ),
      ],
    );
  }

  Widget _resultado(PecaConsulta peca) {
    final catalogo =
        PecaCatalogo(id: '', nome: peca.catalogoNome, tipoCalculo: peca.tipoCalculo);
    final calc = calcularPorValores(
      catalogo: catalogo,
      largura: peca.largura,
      altura: peca.altura,
      comprimento: peca.comprimento,
      diametro: peca.diametro,
      volumePorMetro: peca.volumeConcretoPorMetro,
      kgAcoPorMetro: peca.kgAcoPorMetro,
      volumeConcreto: peca.volumeConcreto,
    );
    final tipoLabel = switch (peca.tipoCalculo) {
      'cilindrica' => 'Cilíndrica',
      'nao_linear' => 'Não linear',
      _ => 'Linear',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        peca.identificador,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    PecaStatusChipInline(status: peca.status),
                  ],
                ),
                Text(peca.catalogoNome,
                    style: const TextStyle(color: AppColors.mutedForeground)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    if (peca.categoriaNome != null)
                      _chip(peca.categoriaNome!, AppColors.info),
                    _chip(tipoLabel, AppColors.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _secao('Obra', [
          _linha('Obra', peca.obraNome),
          if (peca.posicao != null) _linha('Posição na montagem', peca.posicao!),
        ]),
        const SizedBox(height: 12),
        _secao('Dimensões', [
          if (peca.tipoCalculo == 'cilindrica') ...[
            _linha('Diâmetro (m)', _fmt(peca.diametro, 3)),
            _linha('Comprimento (m)', _fmt(peca.comprimento, 2)),
          ] else if (peca.tipoCalculo == 'nao_linear') ...[
            _linha('Comprimento (m)', _fmt(peca.comprimento, 2)),
            _linha('Vol/metro (m³/m)', _fmt(peca.volumeConcretoPorMetro, 4)),
          ] else ...[
            _linha('Largura (m)', _fmt(peca.largura, 2)),
            _linha('Altura (m)', _fmt(peca.altura, 2)),
            _linha('Comprimento (m)', _fmt(peca.comprimento, 2)),
          ],
          _linha('Volume (m³)', calc.volume.toStringAsFixed(3)),
          _linha('Peso (kg)', calc.peso.toStringAsFixed(0)),
          _linha('Aço (kg)', calc.aco.toStringAsFixed(1)),
          _linha('Taxa aço (kg/m³)', _fmt(peca.kgAcoPorMetro, 1)),
        ]),
        const SizedBox(height: 12),
        _secao('Datas do fluxo', [
          _linha('Armação', Formatters.dataBr(peca.dataArmacao)),
          _linha('Concretagem', Formatters.dataBr(peca.dataConcretagem)),
          _linha('Estoque', Formatters.dataBr(peca.dataEstoque)),
          _linha('Carregamento', Formatters.dataBr(peca.dataCarregamento)),
          _linha('Montagem', Formatters.dataBr(peca.dataMontagem)),
        ]),
        const SizedBox(height: 12),
        _rastreabilidade(peca),
        if (peca.observacoes != null && peca.observacoes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _secao('Observações', [
            Text(peca.observacoes!, style: const TextStyle(fontSize: 13)),
          ]),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Nova consulta'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  context.push(AppRoutes.obraDetalhe(peca.obraId)),
              icon: const Icon(Icons.business_outlined),
              label: const Text('Obra'),
            ),
            if (peca.pdfUrl != null)
              OutlinedButton.icon(
                onPressed: () {
                  final uri = Uri.tryParse(peca.pdfUrl!);
                  if (uri != null) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
            OutlinedButton.icon(
              onPressed: _editar,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _editar() async {
    final peca = _peca!;
    try {
      final todas =
          await ref.read(obrasPecasProvider(peca.obraId).future);
      final alvo = todas.where((p) => p.id == peca.id).toList();
      if (alvo.isEmpty) return;
      if (!mounted) return;
      final ok = await showPecaEditSheet(
        context,
        ref,
        peca: alvo.first,
        todas: todas,
      );
      if (ok == true) _consultar(peca.id);
    } catch (_) {
      // silencioso: peça pode não estar mais acessível
    }
  }

  Widget _rastreabilidade(PecaConsulta peca) {
    final lote = peca.lote;
    if (lote == null) {
      return _secao('Rastreabilidade — Concreto', [
        const Text(
          'Esta peça ainda não está vinculada a um lote de concreto.',
          style: TextStyle(
              fontStyle: FontStyle.italic, color: AppColors.mutedForeground),
        ),
      ]);
    }
    return _secao('Rastreabilidade — Concreto', [
      _linha('Lote', lote.codigo ?? lote.id),
      _linha('fck (MPa)', _fmt(lote.fckMpa, 1)),
      _linha('Concretagem', Formatters.dataBr(lote.dataConcretagem)),
      _linha('Volume (m³)', _fmt(lote.volumeM3, 2)),
      _linha('Fornecedor', lote.fornecedor ?? '—'),
      _linha('Slump', lote.slump ?? '—'),
    ]);
  }

  Widget _chip(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: cor)),
    );
  }

  Widget _secao(String titulo, List<Widget> filhos) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            ...filhos,
          ],
        ),
      ),
    );
  }

  Widget _linha(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.mutedForeground)),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  static String _fmt(num? v, int casas) =>
      v == null ? '—' : v.toStringAsFixed(casas);
}

/// Chip de status inline (evita dependência de cores configuradas na consulta).
class PecaStatusChipInline extends StatelessWidget {
  const PecaStatusChipInline({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
