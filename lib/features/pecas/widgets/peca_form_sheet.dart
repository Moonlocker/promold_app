import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/peca_catalogo.dart';
import '../../../providers/pecas_catalogo_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Abre o formulário de peça do catálogo. Retorna `true` se salvou.
Future<bool?> showPecaFormSheet(BuildContext context, {PecaCatalogo? peca}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PecaFormSheet(peca: peca),
  );
}

class _PecaFormSheet extends ConsumerStatefulWidget {
  const _PecaFormSheet({this.peca});

  final PecaCatalogo? peca;

  @override
  ConsumerState<_PecaFormSheet> createState() => _PecaFormSheetState();
}

class _CampoCustom {
  _CampoCustom({required this.id, this.nome = '', this.tipo = 'texto', this.unidade = '', this.valorPadrao = ''});

  final String id;
  String nome;
  String tipo;
  String unidade;
  String valorPadrao;
}

class _PecaFormSheetState extends ConsumerState<_PecaFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _identificador;
  late final TextEditingController _largura;
  late final TextEditingController _altura;
  late final TextEditingController _comprimento;
  late final TextEditingController _diametro;
  late final TextEditingController _volumePorMetro;
  late final TextEditingController _kgAco;
  late final TextEditingController _descricao;

  String? _categoriaId;
  String _tipoCalculo = 'linear';
  String _tipoConcreto = 'armado';
  late List<_CampoCustom> _campos;
  bool _saving = false;

  bool get _isEdit => widget.peca != null;

  @override
  void initState() {
    super.initState();
    final p = widget.peca;
    _nome = TextEditingController(text: p?.nome ?? '');
    _identificador = TextEditingController(text: p?.identificadorPadrao ?? '');
    _largura = TextEditingController(text: p?.larguraPadrao?.toString() ?? '');
    _altura = TextEditingController(text: p?.alturaPadrao?.toString() ?? '');
    _comprimento =
        TextEditingController(text: p?.comprimentoPadrao?.toString() ?? '');
    _diametro = TextEditingController(text: p?.diametroPadrao?.toString() ?? '');
    _volumePorMetro = TextEditingController(
        text: p?.volumeConcretoPorMetro?.toString() ?? '');
    _kgAco =
        TextEditingController(text: p?.kgAcoPorMetro?.toString() ?? '');
    _descricao = TextEditingController(text: p?.descricao ?? '');
    _categoriaId = p?.categoriaId;
    _tipoCalculo = p?.tipoCalculo ?? 'linear';
    _tipoConcreto = p?.tipoConcreto ?? 'armado';
    _campos = (p?.camposPersonalizados ?? [])
        .map((c) => _CampoCustom(
              id: (c['id'] as String?) ?? const Uuid().v4(),
              nome: (c['nome'] as String?) ?? '',
              tipo: (c['tipo'] as String?) ?? 'texto',
              unidade: (c['unidade'] as String?) ?? '',
              valorPadrao: (c['valor_padrao'] as String?) ?? '',
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final c in [
      _nome,
      _identificador,
      _largura,
      _altura,
      _comprimento,
      _diametro,
      _volumePorMetro,
      _kgAco,
      _descricao,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.'));

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoriaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma categoria')),
      );
      return;
    }
    if (_identificador.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o identificador padrão')),
      );
      return;
    }

    final pecas = ref.read(pecasCatalogoListProvider).value ?? const [];
    final dup = pecas.where((p) =>
        p.id != widget.peca?.id &&
        p.identificadorPadrao == _identificador.text.trim());
    if (dup.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Identificador já usado por "${dup.first.nome}"')),
      );
      return;
    }

    if (_tipoCalculo == 'linear') {
      if ((_num(_largura) ?? 0) <= 0 || (_num(_altura) ?? 0) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe largura e altura')),
        );
        return;
      }
    } else if (_tipoCalculo == 'nao_linear') {
      if ((_num(_volumePorMetro) ?? 0) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe o volume por metro')),
        );
        return;
      }
    } else if (_tipoCalculo == 'cilindrica') {
      if ((_num(_diametro) ?? 0) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe o diâmetro')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'nome': _nome.text.trim(),
      'categoria_id': _categoriaId,
      'descricao': _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
      'identificador_padrao': _identificador.text.trim().toUpperCase(),
      'largura_padrao': _tipoCalculo == 'linear' ? _num(_largura) : null,
      'altura_padrao': _tipoCalculo == 'linear' ? _num(_altura) : null,
      'comprimento_padrao': _num(_comprimento),
      'diametro_padrao': _tipoCalculo == 'cilindrica' ? _num(_diametro) : null,
      'volume_concreto_por_metro':
          _tipoCalculo == 'nao_linear' ? _num(_volumePorMetro) : null,
      'kg_aco_por_metro': _num(_kgAco),
      'custo_unitario': null,
      'tipo_calculo': _tipoCalculo,
      'tipo_concreto': _tipoConcreto,
      'campos_personalizados': _campos
          .where((c) => c.nome.trim().isNotEmpty)
          .map((c) => {
                'id': c.id,
                'nome': c.nome.trim(),
                'tipo': c.tipo,
                'unidade': c.unidade,
                'valor_padrao': c.valorPadrao,
              })
          .toList(),
    };

    try {
      final repo = ref.read(pecasCatalogoRepositoryProvider);
      if (_isEdit) {
        final antigo = widget.peca!.identificadorPadrao ?? '';
        final novo = _identificador.text.trim().toUpperCase();
        await repo.update(widget.peca!.id, payload);
        if (antigo.isNotEmpty && novo.isNotEmpty && antigo != novo) {
          final n = await repo.propagarIdentificador(
            pecaCatalogoId: widget.peca!.id,
            identificadorAntigo: antigo,
            identificadorNovo: novo,
          );
          if (n > 0 && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$n peça(s) atualizada(s)')),
            );
          }
        }
      } else {
        await repo.create({...payload, 'ativa': true});
      }
      ref.invalidate(pecasCatalogoListProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = ref.watch(categoriasPecaListProvider).value ?? const [];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    _isEdit ? 'Editar Peça' : 'Nova Peça',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nome,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Nome da peça *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoriaId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Categoria *'),
                      items: categorias
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.nome,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _categoriaId = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _identificador,
                      enabled: !_saving,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                          labelText: 'ID padrão *', hintText: 'TES, PIL...'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _tipoConcreto,
                      decoration:
                          const InputDecoration(labelText: 'Concreto'),
                      items: const [
                        DropdownMenuItem(
                            value: 'armado', child: Text('Armado')),
                        DropdownMenuItem(
                            value: 'protendido', child: Text('Protendido')),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _tipoConcreto = v ?? 'armado'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _tipoCalculo,
                      decoration:
                          const InputDecoration(labelText: 'Cálculo'),
                      items: const [
                        DropdownMenuItem(
                            value: 'linear', child: Text('Linear')),
                        DropdownMenuItem(
                            value: 'nao_linear', child: Text('Não linear')),
                        DropdownMenuItem(
                            value: 'cilindrica', child: Text('Cilíndrica')),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) =>
                              setState(() => _tipoCalculo = v ?? 'linear'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_tipoCalculo == 'linear')
                Row(
                  children: [
                    Expanded(child: _numField(_largura, 'Largura (m) *')),
                    const SizedBox(width: 10),
                    Expanded(child: _numField(_altura, 'Altura (m) *')),
                    const SizedBox(width: 10),
                    Expanded(child: _numField(_comprimento, 'Comp. (m)')),
                  ],
                )
              else if (_tipoCalculo == 'nao_linear')
                Row(
                  children: [
                    Expanded(
                        child: _numField(_volumePorMetro, 'Vol/m (m³/m) *')),
                    const SizedBox(width: 10),
                    Expanded(child: _numField(_comprimento, 'Comp. (m)')),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: _numField(_diametro, 'Diâmetro (m) *')),
                    const SizedBox(width: 10),
                    Expanded(child: _numField(_comprimento, 'Comp. (m)')),
                  ],
                ),
              const SizedBox(height: 12),
              _numField(_kgAco, 'Taxa aço/m³ (kg)'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descricao,
                enabled: !_saving,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Campos personalizados',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _campos.add(
                            _CampoCustom(id: const Uuid().v4()))),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar'),
                  ),
                ],
              ),
              ..._campos.map((campo) => _campoEditor(campo)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _salvar,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(_isEdit ? 'Salvar' : 'Cadastrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _campoEditor(_CampoCustom campo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.muted.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: campo.nome,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                      labelText: 'Nome', isDense: true),
                  onChanged: (v) => campo.nome = v,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  initialValue: campo.tipo,
                  isDense: true,
                  decoration:
                      const InputDecoration(labelText: 'Tipo', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'texto', child: Text('Texto')),
                    DropdownMenuItem(value: 'numero', child: Text('Número')),
                    DropdownMenuItem(value: 'data', child: Text('Data')),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => campo.tipo = v ?? 'texto'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.destructive),
                onPressed: _saving
                    ? null
                    : () => setState(() => _campos.remove(campo)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: campo.unidade,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                      labelText: 'Unidade', isDense: true),
                  onChanged: (v) => campo.unidade = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: campo.valorPadrao,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                      labelText: 'Valor padrão', isDense: true),
                  onChanged: (v) => campo.valorPadrao = v,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
