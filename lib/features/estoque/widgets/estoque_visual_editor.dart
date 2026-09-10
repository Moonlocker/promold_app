import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/estoque.dart';
import '../../../providers/estoque_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Editor visual do mapa de estoque.
///
/// Versão mobile/funcional do `EstoqueVisualEditor`: carrega e salva a
/// configuração do canvas e os elementos, permite adicionar/mover/redimensionar
/// compartimentos e labels, vincular um elemento a um estoque e ver as peças.
/// Recursos de desktop (marquee, paintbrush, undo/redo, alinhamento) foram
/// simplificados.
class EstoqueVisualEditor extends ConsumerStatefulWidget {
  const EstoqueVisualEditor({
    super.key,
    required this.estoqueId,
    required this.estoques,
    required this.pecasByEstoque,
  });

  final String estoqueId;
  final List<Estoque> estoques;
  final Map<String, List<PecaEmEstoque>> pecasByEstoque;

  @override
  ConsumerState<EstoqueVisualEditor> createState() =>
      _EstoqueVisualEditorState();
}

class _EstoqueVisualEditorState extends ConsumerState<EstoqueVisualEditor> {
  final _uuid = const Uuid();

  List<EstoqueVisualElemento> _elementos = [];
  double _canvasW = 1200;
  double _canvasH = 800;
  String? _bgUrl;
  double _bgOpacity = 0.3;

  bool _editMode = false;
  bool _carregado = false;
  String? _selectedId;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final repo = ref.read(estoqueRepositoryProvider);
    final config = await repo.getConfig(widget.estoqueId);
    final elementos = await repo.listElementos(widget.estoqueId);
    if (!mounted) return;
    setState(() {
      _canvasW = config?.canvasWidth ?? 1200;
      _canvasH = config?.canvasHeight ?? 800;
      _bgUrl = config?.backgroundUrl;
      _bgOpacity = config?.backgroundOpacity ?? 0.3;
      _elementos = elementos;
      _carregado = true;
    });
  }

  int _countEstoque(String? estoqueId) {
    if (estoqueId == null) return 0;
    return widget.pecasByEstoque[estoqueId]?.length ?? 0;
  }

  Estoque? _estoquePorId(String? id) {
    if (id == null) return null;
    for (final e in widget.estoques) {
      if (e.id == id) return e;
    }
    return null;
  }

  Color _fillFor(EstoqueVisualElemento el) {
    if (el.isLabel) return Colors.transparent;
    if (el.linkedEstoqueId == null) return AppColors.muted;
    final estoque = _estoquePorId(el.linkedEstoqueId);
    final cap = estoque?.capacidade;
    final count = _countEstoque(el.linkedEstoqueId);
    final ratio = (cap != null && cap > 0) ? count / cap : 0;
    if (ratio > 0.9) return const Color(0xFFFEF2F2);
    if (ratio > 0.7) return const Color(0xFFFFFBEB);
    return const Color(0xFFF0FDF4);
  }

  Color _strokeFor(EstoqueVisualElemento el) {
    if (el.isLabel) return Colors.transparent;
    if (el.linkedEstoqueId == null) return AppColors.border;
    final estoque = _estoquePorId(el.linkedEstoqueId);
    final cap = estoque?.capacidade;
    final count = _countEstoque(el.linkedEstoqueId);
    final ratio = (cap != null && cap > 0) ? count / cap : 0;
    if (ratio > 0.9) return const Color(0xFFF87171);
    if (ratio > 0.7) return const Color(0xFFF59E0B);
    return const Color(0xFF4ADE80);
  }

  void _addElemento({required bool label}) {
    setState(() {
      _elementos = [
        ..._elementos,
        EstoqueVisualElemento(
          id: _uuid.v4(),
          estoqueId: widget.estoqueId,
          tipo: label ? 'label' : 'compartimento',
          label: label ? 'Título' : null,
          x: 10,
          y: 10,
          largura: label ? 120 : 140,
          altura: label ? 30 : 100,
        ),
      ];
    });
  }

  void _removerSelecionado() {
    if (_selectedId == null) return;
    setState(() {
      _elementos =
          _elementos.where((e) => e.id != _selectedId).toList();
      _selectedId = null;
    });
  }

  void _atualizar(String id, EstoqueVisualElemento Function(EstoqueVisualElemento) fn) {
    setState(() {
      _elementos = _elementos.map((e) => e.id == id ? fn(e) : e).toList();
    });
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    final repo = ref.read(estoqueRepositoryProvider);
    try {
      await repo.saveConfig(widget.estoqueId, {
        'canvas_width': _canvasW,
        'canvas_height': _canvasH,
        'background_url': _bgUrl,
        'background_opacity': _bgOpacity,
      });
      await repo.saveElementos(widget.estoqueId, _elementos);
      ref.invalidate(estoqueConfigProvider(widget.estoqueId));
      ref.invalidate(estoqueElementosProvider(widget.estoqueId));
      if (mounted) {
        setState(() {
          _editMode = false;
          _selectedId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mapa salvo!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _escolherFundo() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    try {
      final bytes = await files.first.readAsBytes();
      final url = await ref
          .read(estoqueRepositoryProvider)
          .uploadBackground(
            estoqueId: widget.estoqueId,
            bytes: bytes,
            nomeArquivo: files.first.name,
          );
      setState(() => _bgUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro no upload: $e')));
      }
    }
  }

  Future<void> _onTapElemento(EstoqueVisualElemento el) async {
    if (_editMode) {
      setState(() => _selectedId = el.id);
      return;
    }
    if (el.isLabel) return;
    if (el.linkedEstoqueId == null) {
      await _vincularElemento(el);
    } else {
      _verPecas(el);
    }
  }

  Future<void> _vincularElemento(EstoqueVisualElemento el) async {
    final escolhido = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Vincular a qual estoque?',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ...widget.estoques.map(
              (e) => ListTile(
                title: Text(e.nome),
                onTap: () => Navigator.pop(context, e.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (escolhido != null) {
      _atualizar(el.id, (e) => e.copyWith(linkedEstoqueId: escolhido));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Vínculo alterado. Toque em Salvar para gravar.')),
        );
      }
    }
  }

  void _verPecas(EstoqueVisualElemento el) {
    final pecas = widget.pecasByEstoque[el.linkedEstoqueId] ?? const [];
    final estoque = _estoquePorId(el.linkedEstoqueId);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${estoque?.nome ?? 'Estoque'} · ${pecas.length} peça(s)',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (pecas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Nenhuma peça neste local.',
                      style: TextStyle(color: AppColors.mutedForeground)),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: pecas
                        .map((p) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  '${p.identificador} · ${p.pecaNome}'),
                              subtitle: Text(p.obraNome,
                                  style: const TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_carregado) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _toolbar(),
        if (_editMode && _selectedId != null) _painelPropriedades(),
        Expanded(
          child: Container(
            color: const Color(0xFFF3F4F6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: SizedBox(
                  width: _canvasW,
                  height: _canvasH,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _GridPainter()),
                      ),
                      if (_bgUrl != null)
                        Positioned.fill(
                          child: Opacity(
                            opacity: _bgOpacity,
                            child: Image.network(_bgUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink()),
                          ),
                        ),
                      ..._elementos.map(_buildElemento),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolbar() {
    return Material(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() {
                _editMode = !_editMode;
                _selectedId = null;
              }),
              icon: Icon(_editMode ? Icons.visibility : Icons.edit),
              label: Text(_editMode ? 'Visualizar' : 'Editar'),
            ),
            const Spacer(),
            if (_editMode) ...[
              IconButton(
                tooltip: 'Adicionar compartimento',
                icon: const Icon(Icons.add_box_outlined),
                onPressed: () => _addElemento(label: false),
              ),
              IconButton(
                tooltip: 'Adicionar label',
                icon: const Icon(Icons.text_fields),
                onPressed: () => _addElemento(label: true),
              ),
              IconButton(
                tooltip: 'Imagem de fundo',
                icon: const Icon(Icons.image_outlined),
                onPressed: _escolherFundo,
              ),
              IconButton(
                tooltip: 'Excluir selecionado',
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.destructive),
                onPressed: _selectedId == null ? null : _removerSelecionado,
              ),
              FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: const Text('Salvar'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _painelPropriedades() {
    final el = _elementos.firstWhere((e) => e.id == _selectedId);
    return Material(
      color: AppColors.muted,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(el.isLabel ? 'Label' : 'Compartimento',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (!el.isLabel)
                  TextButton(
                    onPressed: () => _vincularElemento(el),
                    child: Text(el.linkedEstoqueId == null
                        ? 'Vincular estoque'
                        : (_estoquePorId(el.linkedEstoqueId)?.nome ??
                            'Alterar vínculo')),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: el.label ?? '',
              decoration: const InputDecoration(
                  labelText: 'Texto do label', isDense: true),
              onFieldSubmitted: (v) =>
                  _atualizar(el.id, (e) => e.copyWith(label: v)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _numField('Largura', el.largura, (v) =>
                      _atualizar(el.id, (e) => e.copyWith(largura: v))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _numField('Altura', el.altura, (v) =>
                      _atualizar(el.id, (e) => e.copyWith(altura: v))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _numField('Rotação', el.rotacao, (v) =>
                      _atualizar(el.id, (e) => e.copyWith(rotacao: v))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(String label, double value, ValueChanged<double> onChanged) {
    return TextFormField(
      initialValue: value.toStringAsFixed(0),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true),
      onFieldSubmitted: (v) {
        final d = double.tryParse(v.replaceAll(',', '.'));
        if (d != null) onChanged(d);
      },
    );
  }

  Widget _buildElemento(EstoqueVisualElemento el) {
    final selecionado = el.id == _selectedId;
    final linked = _estoquePorId(el.linkedEstoqueId);
    final count = _countEstoque(el.linkedEstoqueId);

    return Positioned(
      left: el.x,
      top: el.y,
      child: Transform.rotate(
        angle: el.rotacao * 3.1415926535 / 180,
        child: GestureDetector(
          onTap: () => _onTapElemento(el),
          onPanUpdate: _editMode
              ? (d) => _atualizar(
                    el.id,
                    (e) => e.copyWith(
                      x: (e.x + d.delta.dx).clamp(0, _canvasW - e.largura),
                      y: (e.y + d.delta.dy).clamp(0, _canvasH - e.altura),
                    ),
                  )
              : null,
          child: Container(
            width: el.largura,
            height: el.altura,
            decoration: BoxDecoration(
              color: _fillFor(el),
              border: Border.all(
                color: selecionado ? AppColors.primary : _strokeFor(el),
                width: selecionado ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: el.isLabel
                ? Center(
                    child: Text(
                      el.label ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          linked?.nome ?? 'Sem estoque',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 11),
                        ),
                        Text(
                          linked == null
                              ? 'toque para vincular'
                              : '$count${linked.capacidade != null ? '/${linked.capacidade}' : ''} peça(s)',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
