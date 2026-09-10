import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/logic/peca_calc.dart';
import '../../../core/logic/status_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/obra_peca.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Abre a edição de uma peça. Retorna `true` se salvou.
Future<bool?> showPecaEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required ObraPeca peca,
  required List<ObraPeca> todas,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PecaEditSheet(peca: peca, todas: todas),
  );
}

class _PecaEditSheet extends ConsumerStatefulWidget {
  const _PecaEditSheet({required this.peca, required this.todas});

  final ObraPeca peca;
  final List<ObraPeca> todas;

  @override
  ConsumerState<_PecaEditSheet> createState() => _PecaEditSheetState();
}

class _PecaEditSheetState extends ConsumerState<_PecaEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _identificador;
  late final TextEditingController _comprimento;
  late final TextEditingController _largura;
  late final TextEditingController _altura;
  late final TextEditingController _diametro;
  late final TextEditingController _volPorMetro;
  late final TextEditingController _kgAco;
  late final TextEditingController _observacoes;

  late String _status;
  late DateTime? _dataArmacao;
  late DateTime? _dataConcretagem;
  late DateTime? _dataEstoque;
  late DateTime? _dataCarregamento;
  late DateTime? _dataMontagem;

  String? _pdfUrl;
  String? _pdfStoragePath;
  bool _pdfBusy = false;

  final Map<String, TextEditingController> _campos = {};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.peca;
    _identificador = TextEditingController(text: p.identificador);
    _comprimento = TextEditingController(text: _fmt(p.comprimento));
    _largura = TextEditingController(text: _fmt(p.largura));
    _altura = TextEditingController(text: _fmt(p.altura));
    _diametro = TextEditingController(text: _fmt(p.diametro));
    _volPorMetro = TextEditingController(text: _fmt(p.volumeConcretoPorMetro));
    _kgAco = TextEditingController(text: _fmt(p.kgAcoPorMetro));
    _observacoes = TextEditingController(text: p.observacoes ?? '');
    _status = normalizarStatus(p.status);
    _dataArmacao = p.dataArmacao;
    _dataConcretagem = p.dataConcretagem;
    _dataEstoque = p.dataEstoque;
    _dataCarregamento = p.dataCarregamento;
    _dataMontagem = p.dataMontagem;
    _pdfUrl = p.pdfUrl;
    _pdfStoragePath = p.pdfStoragePath;

    for (final campo in p.pecaCatalogo?.camposPersonalizados ?? const []) {
      final id = campo['id']?.toString();
      if (id == null) continue;
      final valor = p.valoresPersonalizados[id]?.toString() ??
          campo['valor_padrao']?.toString() ??
          '';
      _campos[id] = TextEditingController(text: valor);
    }
  }

  static String _fmt(num? v) => v == null ? '' : v.toString();

  @override
  void dispose() {
    _identificador.dispose();
    _comprimento.dispose();
    _largura.dispose();
    _altura.dispose();
    _diametro.dispose();
    _volPorMetro.dispose();
    _kgAco.dispose();
    _observacoes.dispose();
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _pickDate(String field) async {
    final atual = switch (field) {
      'armacao' => _dataArmacao,
      'concretagem' => _dataConcretagem,
      'estoque' => _dataEstoque,
      'carregamento' => _dataCarregamento,
      _ => _dataMontagem,
    };
    final picked = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      switch (field) {
        case 'armacao':
          _dataArmacao = picked;
        case 'concretagem':
          _dataConcretagem = picked;
        case 'estoque':
          _dataEstoque = picked;
        case 'carregamento':
          _dataCarregamento = picked;
        case 'montagem':
          _dataMontagem = picked;
      }
    });
  }

  void _aplicarDatasPadrao() {
    final hoje = DateTime.now();
    void setIfNull(DateTime? Function() get, void Function(DateTime) set) {
      if (get() == null) set(hoje);
    }

    switch (_status) {
      case 'armada':
        setIfNull(() => _dataArmacao, (d) => _dataArmacao = d);
      case 'concretada':
        setIfNull(() => _dataConcretagem, (d) => _dataConcretagem = d);
      case 'em_estoque':
        setIfNull(() => _dataConcretagem, (d) => _dataConcretagem = d);
        setIfNull(() => _dataEstoque, (d) => _dataEstoque = d);
      case 'carregada':
        setIfNull(() => _dataCarregamento, (d) => _dataCarregamento = d);
      case 'montada':
        setIfNull(() => _dataConcretagem, (d) => _dataConcretagem = d);
        setIfNull(() => _dataMontagem, (d) => _dataMontagem = d);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final identificador = _identificador.text.trim();
    final duplicado = widget.todas.any(
      (p) => p.id != widget.peca.id && p.identificador == identificador,
    );
    if (duplicado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Já existe uma peça com esse identificador.')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _aplicarDatasPadrao();
    });

    final comp = _parse(_comprimento);
    final larg = _parse(_largura);
    final alt = _parse(_altura);
    final diam = _parse(_diametro);
    final vpm = _parse(_volPorMetro);
    final kgAco = _parse(_kgAco);

    // Recalcula volume_concreto quando há dimensões informadas (porte de
    // useUpdateObraPeca no webapp).
    final calc = calcularPorValores(
      catalogo: widget.peca.pecaCatalogo,
      largura: larg,
      altura: alt,
      comprimento: comp,
      diametro: diam,
      volumePorMetro: vpm,
      kgAcoPorMetro: kgAco,
      volumeConcreto: widget.peca.volumeConcreto,
    );

    String? iso(DateTime? d) => d?.toIso8601String().split('T').first;

    final update = <String, dynamic>{
      'identificador': identificador,
      'status': _status,
      'comprimento': comp,
      'largura': larg,
      'altura': alt,
      'diametro': diam,
      'volume_concreto_por_metro': vpm,
      'kg_aco_por_metro': kgAco,
      'volume_concreto': calc.volume > 0 ? round3(calc.volume) : null,
      'data_armacao': iso(_dataArmacao),
      'data_concretagem': iso(_dataConcretagem),
      'data_estoque': iso(_dataEstoque),
      'data_carregamento': iso(_dataCarregamento),
      'data_montagem': iso(_dataMontagem),
      'observacoes': _observacoes.text.trim().isEmpty
          ? null
          : _observacoes.text.trim(),
      'valores_personalizados': {
        ...widget.peca.valoresPersonalizados,
        for (final e in _campos.entries) e.key: e.value.text,
      },
    };

    try {
      await ref.read(obrasRepositoryProvider).updatePeca(widget.peca.id, update);
      ref.invalidate(obrasPecasProvider(widget.peca.obraId));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    }
  }

  Future<void> _anexarPdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isEmpty) return;
    setState(() => _pdfBusy = true);
    final repo = ref.read(obraMidiaRepositoryProvider);
    try {
      final bytes = await files.first.readAsBytes();
      if (_pdfStoragePath != null) {
        await repo.removePecaPdf(_pdfStoragePath!);
      }
      final url = await repo.uploadPecaPdf(
        obraId: widget.peca.obraId,
        pecaId: widget.peca.id,
        bytes: bytes,
      );
      const marker = '/storage/v1/object/public/obras-anexos/';
      final idx = url.indexOf(marker);
      final path = idx >= 0 ? url.substring(idx + marker.length) : url;
      await ref.read(obrasRepositoryProvider).updatePeca(widget.peca.id, {
        'pdf_url': url,
        'pdf_storage_path': path,
      });
      setState(() {
        _pdfUrl = url;
        _pdfStoragePath = path;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro no PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _removerPdf() async {
    setState(() => _pdfBusy = true);
    final repo = ref.read(obraMidiaRepositoryProvider);
    try {
      if (_pdfStoragePath != null) {
        await repo.removePecaPdf(_pdfStoragePath!);
      }
      await ref.read(obrasRepositoryProvider).updatePeca(widget.peca.id, {
        'pdf_url': null,
        'pdf_storage_path': null,
      });
      setState(() {
        _pdfUrl = null;
        _pdfStoragePath = null;
      });
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _abrirPdf() async {
    final url = _pdfUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final p = widget.peca;
    final calc = calcularPeca(p);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nomePeca,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${p.tipoConcretoLabel} · ${calc.tipo}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _identificador,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Identificador *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o identificador' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: statusSelecionaveis
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(statusLabel(s)),
                        ))
                    .toList(),
                onChanged:
                    _saving ? null : (v) => setState(() => _status = v ?? 'pendente'),
              ),
              const SizedBox(height: 16),
              const Text('Dimensões',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _num(_largura, 'Largura (m)')),
                  const SizedBox(width: 10),
                  Expanded(child: _num(_altura, 'Altura (m)')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _num(_comprimento, 'Comprimento (m)')),
                  const SizedBox(width: 10),
                  Expanded(child: _num(_diametro, 'Diâmetro (m)')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _num(_volPorMetro, 'Vol/m (m³/m)')),
                  const SizedBox(width: 10),
                  Expanded(child: _num(_kgAco, 'Aço (kg/m³)')),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Volume: ${round3(calc.volume).toStringAsFixed(3)} m³',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      'Aço: ${calc.aco.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Datas',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _dateTile('Armação', _dataArmacao, 'armacao'),
              _dateTile('Concretagem', _dataConcretagem, 'concretagem'),
              _dateTile('Estoque', _dataEstoque, 'estoque'),
              _dateTile('Carregamento', _dataCarregamento, 'carregamento'),
              _dateTile('Montagem', _dataMontagem, 'montagem'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _observacoes,
                enabled: !_saving,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Observações'),
              ),
              if (_campos.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Campos personalizados',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ..._campos.entries.map((e) {
                  final campo = widget.peca.pecaCatalogo!.camposPersonalizados
                      .firstWhere((c) => c['id']?.toString() == e.key);
                  final unidade = campo['unidade']?.toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextFormField(
                      controller: e.value,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: (campo['nome']?.toString() ?? e.key) +
                            (unidade != null ? ' ($unidade)' : ''),
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
              const Text('PDF da peça',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_pdfUrl != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pdfBusy ? null : _abrirPdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Abrir PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _pdfBusy ? null : _removerPdf,
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.destructive),
                    ),
                  ] else
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pdfBusy ? null : _anexarPdf,
                        icon: _pdfBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.attach_file),
                        label: const Text('Anexar PDF'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _salvar,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Salvar peça'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _num(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      enabled: !_saving,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }

  Widget _dateTile(String label, DateTime? value, String field) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value != null ? Formatters.dataBr(value) : 'Não informado'),
      trailing: value != null
          ? IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        switch (field) {
                          case 'armacao':
                            _dataArmacao = null;
                          case 'concretagem':
                            _dataConcretagem = null;
                          case 'estoque':
                            _dataEstoque = null;
                          case 'carregamento':
                            _dataCarregamento = null;
                          case 'montagem':
                            _dataMontagem = null;
                        }
                      }),
            )
          : const Icon(Icons.calendar_today_outlined, size: 18),
      onTap: _saving ? null : () => _pickDate(field),
    );
  }
}
