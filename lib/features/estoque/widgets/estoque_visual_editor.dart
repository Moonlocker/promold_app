import 'dart:math' as math;

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
/// Inclui seleção múltipla (marquee), desfazer/refazer, pincel (copiar tamanho),
/// alinhar/distribuir e copiar/colar.
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
  bool _salvando = false;

  final Set<String> _selectedIds = {};
  final List<List<EstoqueVisualElemento>> _undoStack = [];
  final List<List<EstoqueVisualElemento>> _redoStack = [];
  List<EstoqueVisualElemento> _clipboard = [];
  double? _brushLargura;
  double? _brushAltura;
  double? _brushRotacao;

  bool _marqueeMode = false;
  Offset? _marqueeStart;
  Rect? _marqueeRect;

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

  // ------------------------------------------------------- Undo / Redo
  void _pushUndo() {
    _undoStack.add(List.of(_elementos));
    if (_undoStack.length > 100) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(List.of(_elementos));
      _elementos = _undoStack.removeLast();
      _selectedIds.clear();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(List.of(_elementos));
      _elementos = _redoStack.removeLast();
      _selectedIds.clear();
    });
  }

  // ------------------------------------------------------- Seleção
  String? get _selectedId =>
      _selectedIds.length == 1 ? _selectedIds.first : null;

  List<EstoqueVisualElemento> get _selecionados =>
      _elementos.where((e) => _selectedIds.contains(e.id)).toList();

  void _selecionarTudo() => setState(() {
        _selectedIds
          ..clear()
          ..addAll(_elementos.map((e) => e.id));
      });

  void _limparSelecao() => setState(_selectedIds.clear);

  void _aplicarMarquee() {
    final r = _marqueeRect;
    setState(() {
      if (r != null && r.width.abs() > 5 && r.height.abs() > 5) {
        final norm = Rect.fromLTRB(
          math.min(r.left, r.right),
          math.min(r.top, r.bottom),
          math.max(r.left, r.right),
          math.max(r.top, r.bottom),
        );
        _selectedIds
          ..clear()
          ..addAll(_elementos.where((e) {
            final er = Rect.fromLTWH(e.x, e.y, e.largura, e.altura);
            return er.overlaps(norm);
          }).map((e) => e.id));
      }
      _marqueeRect = null;
      _marqueeStart = null;
    });
  }

  // ------------------------------------------------------- Edição
  void _addElemento({required bool label}) {
    final el = EstoqueVisualElemento(
      id: _uuid.v4(),
      estoqueId: widget.estoqueId,
      tipo: label ? 'label' : 'compartimento',
      label: label ? 'Título' : null,
      x: 10,
      y: 10,
      largura: label ? 120 : 140,
      altura: label ? 30 : 100,
    );
    _pushUndo();
    setState(() {
      _elementos = [..._elementos, el];
      _selectedIds
        ..clear()
        ..add(el.id);
    });
  }

  void _removerSelecionado() {
    if (_selectedIds.isEmpty) return;
    _pushUndo();
    setState(() {
      _elementos =
          _elementos.where((e) => !_selectedIds.contains(e.id)).toList();
      _selectedIds.clear();
    });
  }

  void _atualizar(
    String id,
    EstoqueVisualElemento Function(EstoqueVisualElemento) fn, {
    bool undo = false,
  }) {
    if (undo) _pushUndo();
    setState(() {
      _elementos = _elementos.map((e) => e.id == id ? fn(e) : e).toList();
    });
  }

  void _moverSelecionados(Offset delta) {
    final mover = _selectedIds.isEmpty ? <String>{} : _selectedIds;
    setState(() {
      _elementos = _elementos.map((e) {
        if (!mover.contains(e.id)) return e;
        return e.copyWith(
          x: (e.x + delta.dx).clamp(0, _canvasW - e.largura),
          y: (e.y + delta.dy).clamp(0, _canvasH - e.altura),
        );
      }).toList();
    });
  }

  void _align(String tipo) {
    final sel = _selecionados;
    if (sel.length < 2) return;
    final minX = sel.map((e) => e.x).reduce(math.min);
    final maxX = sel.map((e) => e.x + e.largura).reduce(math.max);
    final minY = sel.map((e) => e.y).reduce(math.min);
    final maxY = sel.map((e) => e.y + e.altura).reduce(math.max);
    _pushUndo();
    setState(() {
      _elementos = _elementos.map((e) {
        if (!_selectedIds.contains(e.id)) return e;
        switch (tipo) {
          case 'left':
            return e.copyWith(x: minX);
          case 'right':
            return e.copyWith(x: maxX - e.largura);
          case 'top':
            return e.copyWith(y: minY);
          case 'bottom':
            return e.copyWith(y: maxY - e.altura);
          case 'hcenter':
            return e.copyWith(x: (minX + maxX) / 2 - e.largura / 2);
          case 'vcenter':
            return e.copyWith(y: (minY + maxY) / 2 - e.altura / 2);
        }
        return e;
      }).toList();
    });
  }

  void _distribuir(bool horizontal) {
    final sel = _selecionados;
    if (sel.length < 3) return;
    final ordered = [...sel]
      ..sort((a, b) => horizontal ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
    final start =
        horizontal ? ordered.first.x : ordered.first.y;
    final end = horizontal ? ordered.last.x : ordered.last.y;
    final step = (end - start) / (ordered.length - 1);
    final posicoes = <String, double>{
      for (var i = 0; i < ordered.length; i++)
        ordered[i].id: start + step * i,
    };
    _pushUndo();
    setState(() {
      _elementos = _elementos.map((e) {
        final p = posicoes[e.id];
        if (p == null) return e;
        return horizontal ? e.copyWith(x: p) : e.copyWith(y: p);
      }).toList();
    });
  }

  void _copiar() {
    if (_selectedIds.isEmpty) return;
    _clipboard = _selecionados;
    _snack('${_clipboard.length} elemento(s) copiado(s)');
  }

  void _colar() {
    if (_clipboard.isEmpty) return;
    _pushUndo();
    final novos = _clipboard
        .map((e) => e.copyWith(id: _uuid.v4(), x: e.x + 20, y: e.y + 20))
        .toList();
    setState(() {
      _elementos = [..._elementos, ...novos];
      _selectedIds
        ..clear()
        ..addAll(novos.map((e) => e.id));
    });
  }

  void _copiarTamanho() {
    if (_selectedIds.isEmpty) return;
    final e = _selecionados.first;
    _brushLargura = e.largura;
    _brushAltura = e.altura;
    _brushRotacao = e.rotacao;
    _snack('Pincel: ${e.largura.toInt()}×${e.altura.toInt()}');
  }

  void _aplicarPincel() {
    if (_brushLargura == null || _selectedIds.isEmpty) return;
    _pushUndo();
    setState(() {
      _elementos = _elementos.map((e) {
        if (!_selectedIds.contains(e.id)) return e;
        return e.copyWith(
          largura: _brushLargura,
          altura: _brushAltura,
          rotacao: _brushRotacao,
        );
      }).toList();
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
          _selectedIds.clear();
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
      setState(() {
        if (_selectedIds.contains(el.id)) {
          _selectedIds.remove(el.id);
        } else {
          _selectedIds.add(el.id);
        }
      });
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
                              title:
                                  Text('${p.identificador} · ${p.pecaNome}'),
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
        if (_editMode && _selectedIds.isNotEmpty) _painelPropriedades(),
        Expanded(
          child: Container(
            color: const Color(0xFFF3F4F6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: _marqueeMode
                  ? const NeverScrollableScrollPhysics()
                  : null,
              child: SingleChildScrollView(
                physics: _marqueeMode
                    ? const NeverScrollableScrollPhysics()
                    : null,
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
                      if (_editMode)
                        Positioned.fill(
                          child: IgnorePointer(
                            ignoring: !_marqueeMode,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (d) => setState(() {
                                _marqueeStart = d.localPosition;
                                _marqueeRect = Rect.fromPoints(
                                    d.localPosition, d.localPosition);
                              }),
                              onPanUpdate: (d) => setState(() {
                                _marqueeRect = Rect.fromPoints(
                                    _marqueeStart ?? d.localPosition,
                                    d.localPosition);
                              }),
                              onPanEnd: (_) => _aplicarMarquee(),
                            ),
                          ),
                        ),
                      ..._elementos.map(_buildElemento),
                      if (_marqueeRect != null)
                        Positioned(
                          left: math.min(
                              _marqueeRect!.left, _marqueeRect!.right),
                          top: math.min(_marqueeRect!.top, _marqueeRect!.bottom),
                          width: (_marqueeRect!.right - _marqueeRect!.left)
                              .abs(),
                          height: (_marqueeRect!.bottom - _marqueeRect!.top)
                              .abs(),
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.12),
                                border: Border.all(color: AppColors.primary),
                              ),
                            ),
                          ),
                        ),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _editMode = !_editMode;
                  _selectedIds.clear();
                  _marqueeMode = false;
                });
              },
              icon: Icon(_editMode ? Icons.visibility : Icons.edit),
              label: Text(_editMode ? 'Visualizar' : 'Editar'),
            ),
            if (_editMode) ...[
              IconButton(
                tooltip: 'Desfazer',
                icon: const Icon(Icons.undo),
                onPressed: _undoStack.isEmpty ? null : _undo,
              ),
              IconButton(
                tooltip: 'Refazer',
                icon: const Icon(Icons.redo),
                onPressed: _redoStack.isEmpty ? null : _redo,
              ),
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
                tooltip: _marqueeMode
                    ? 'Seleção retangular ativada'
                    : 'Seleção retangular',
                icon: Icon(Icons.select_all,
                    color: _marqueeMode ? AppColors.primary : null),
                onPressed: () => setState(() {
                  _marqueeMode = !_marqueeMode;
                }),
              ),
              IconButton(
                tooltip: 'Selecionar tudo',
                icon: const Icon(Icons.done_all),
                onPressed: _selecionarTudo,
              ),
              IconButton(
                tooltip: 'Copiar',
                icon: const Icon(Icons.copy_all_outlined),
                onPressed: _selectedIds.isEmpty ? null : _copiar,
              ),
              IconButton(
                tooltip: 'Colar',
                icon: const Icon(Icons.content_paste),
                onPressed: _clipboard.isEmpty ? null : _colar,
              ),
              IconButton(
                tooltip: 'Copiar tamanho (pincel)',
                icon: const Icon(Icons.brush_outlined),
                onPressed: _selectedIds.isEmpty ? null : _copiarTamanho,
              ),
              IconButton(
                tooltip: 'Aplicar tamanho do pincel',
                icon: const Icon(Icons.format_paint),
                onPressed: (_brushLargura == null || _selectedIds.isEmpty)
                    ? null
                    : _aplicarPincel,
              ),
              PopupMenuButton<String>(
                tooltip: 'Alinhar',
                icon: const Icon(Icons.align_horizontal_left),
                enabled: _selectedIds.length >= 2,
                onSelected: _align,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'left', child: Text('Alinhar à esquerda')),
                  PopupMenuItem(value: 'hcenter', child: Text('Centralizar H')),
                  PopupMenuItem(value: 'right', child: Text('Alinhar à direita')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'top', child: Text('Alinhar ao topo')),
                  PopupMenuItem(value: 'vcenter', child: Text('Centralizar V')),
                  PopupMenuItem(value: 'bottom', child: Text('Alinhar base')),
                ],
              ),
              PopupMenuButton<bool>(
                tooltip: 'Distribuir',
                icon: const Icon(Icons.horizontal_distribute),
                enabled: _selectedIds.length >= 3,
                onSelected: _distribuir,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: true, child: Text('Distribuir H')),
                  PopupMenuItem(value: false, child: Text('Distribuir V')),
                ],
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
                onPressed:
                    _selectedIds.isEmpty ? null : _removerSelecionado,
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
    if (_selectedIds.length > 1) {
      return Material(
        color: AppColors.muted,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text('${_selectedIds.length} elementos selecionados',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: _limparSelecao,
                child: const Text('Limpar seleção'),
              ),
            ],
          ),
        ),
      );
    }
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
                TextButton(
                  onPressed: _limparSelecao,
                  child: const Text('Limpar seleção'),
                ),
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
              key: ValueKey('label-${el.id}'),
              initialValue: el.label ?? '',
              decoration: const InputDecoration(
                  labelText: 'Texto do label', isDense: true),
              onFieldSubmitted: (v) => _atualizar(
                  el.id,
                  (e) => e.copyWith(label: v),
                  undo: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _numField('Largura', el.largura, (v) => _atualizar(
                      el.id, (e) => e.copyWith(largura: v),
                      undo: true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _numField('Altura', el.altura, (v) => _atualizar(
                      el.id, (e) => e.copyWith(altura: v),
                      undo: true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _numField('Rotação', el.rotacao, (v) => _atualizar(
                      el.id, (e) => e.copyWith(rotacao: v),
                      undo: true)),
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
    final selecionado = _selectedIds.contains(el.id);
    final linked = _estoquePorId(el.linkedEstoqueId);
    final count = _countEstoque(el.linkedEstoqueId);
    final arrastandoSelecao =
        _selectedIds.contains(el.id) && _selectedIds.length > 1;

    return Positioned(
      left: el.x,
      top: el.y,
      child: Transform.rotate(
        angle: el.rotacao * 3.1415926535 / 180,
        child: GestureDetector(
          onTap: () => _onTapElemento(el),
          onPanStart: _editMode ? (_) => _pushUndo() : null,
          onPanUpdate: !_editMode
              ? null
              : (d) {
                  if (arrastandoSelecao) {
                    _moverSelecionados(d.delta);
                  } else {
                    _atualizar(
                      el.id,
                      (e) => e.copyWith(
                        x: (e.x + d.delta.dx).clamp(0, _canvasW - e.largura),
                        y: (e.y + d.delta.dy).clamp(0, _canvasH - e.altura),
                      ),
                    );
                  }
                },
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
