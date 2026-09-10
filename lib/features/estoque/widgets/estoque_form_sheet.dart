import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/estoque.dart';
import '../../../providers/estoque_providers.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Formulário de criação/edição de estoque. Retorna `true` se salvou.
Future<bool?> showEstoqueFormSheet(
  BuildContext context,
  WidgetRef ref, {
  Estoque? estoque,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EstoqueFormSheet(estoque: estoque),
  );
}

class _EstoqueFormSheet extends ConsumerStatefulWidget {
  const _EstoqueFormSheet({this.estoque});

  final Estoque? estoque;

  @override
  ConsumerState<_EstoqueFormSheet> createState() => _EstoqueFormSheetState();
}

class _EstoqueFormSheetState extends ConsumerState<_EstoqueFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _descricao;
  late final TextEditingController _capacidade;
  late bool _permitirTodas;
  late Set<String> _categorias;
  late Set<String> _pecas;
  bool _saving = false;

  bool get _isEdit => widget.estoque != null;

  @override
  void initState() {
    super.initState();
    final e = widget.estoque;
    _nome = TextEditingController(text: e?.nome ?? '');
    _descricao = TextEditingController(text: e?.descricaoLimpa ?? '');
    _capacidade = TextEditingController(text: e?.capacidade?.toString() ?? '');
    _permitirTodas = e?.permiteTodas ?? true;
    _categorias = {...?e?.categoriasPermitidas};
    _pecas = {...?e?.pecasPermitidas};
  }

  @override
  void dispose() {
    _nome.dispose();
    _descricao.dispose();
    _capacidade.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final payload = {
      'nome': _nome.text.trim(),
      'descricao': _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
      'capacidade': int.tryParse(_capacidade.text.trim()),
      'categorias_permitidas':
          _permitirTodas || _categorias.isEmpty ? null : _categorias.toList(),
      'pecas_permitidas':
          _permitirTodas || _pecas.isEmpty ? null : _pecas.toList(),
    };
    try {
      final repo = ref.read(estoqueRepositoryProvider);
      if (_isEdit) {
        await repo.updateEstoque(widget.estoque!.id, payload);
      } else {
        await repo.createEstoque(payload);
      }
      ref.invalidate(estoquesProvider);
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
    final categorias = ref.watch(categoriasPecaProvider).value ?? const [];
    final pecas = ref.watch(pecasCatalogoProvider).value ?? const [];
    final bottom = MediaQuery.of(context).viewInsets.bottom;

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
                  Text(
                    _isEdit ? 'Editar Estoque' : 'Novo Estoque',
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
                decoration: const InputDecoration(labelText: 'Nome *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descricao,
                enabled: !_saving,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacidade,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Capacidade (peças)'),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Permitir todas as categorias e peças'),
                value: _permitirTodas,
                onChanged:
                    _saving ? null : (v) => setState(() => _permitirTodas = v),
              ),
              if (!_permitirTodas) ...[
                const Text('Categorias permitidas',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: categorias.map((c) {
                    final sel = _categorias.contains(c.id);
                    return FilterChip(
                      label: Text(c.nome),
                      selected: sel,
                      onSelected: _saving
                          ? null
                          : (v) => setState(() {
                                if (v) {
                                  _categorias.add(c.id);
                                } else {
                                  _categorias.remove(c.id);
                                }
                              }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Peças específicas',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: pecas.map((p) {
                    final sel = _pecas.contains(p.id);
                    return FilterChip(
                      label: Text(p.nome),
                      selected: sel,
                      onSelected: _saving
                          ? null
                          : (v) => setState(() {
                                if (v) {
                                  _pecas.add(p.id);
                                } else {
                                  _pecas.remove(p.id);
                                }
                              }),
                    );
                  }).toList(),
                ),
              ],
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
}
