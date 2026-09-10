import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/obra.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/supabase_providers.dart';

const _paletaCores = [
  '#3B82F6', '#EF4444', '#10B981', '#F59E0B', '#8B5CF6', '#EC4899',
  '#06B6D4', '#F97316', '#14B8A6', '#6366F1', '#84CC16', '#D946EF',
];

const _statusOptions = ['planejamento', 'ativa', 'pausada', 'concluida'];
const _statusLabels = {
  'planejamento': 'Planejamento',
  'ativa': 'Ativa',
  'pausada': 'Pausada',
  'concluida': 'Concluída',
};

/// Abre o formulário de obra. Se [obra] for nulo, cria uma nova.
/// Retorna `true` se salvou com sucesso.
Future<bool?> showObraFormSheet(
  BuildContext context,
  WidgetRef ref, {
  Obra? obra,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ObraFormSheet(obra: obra),
  );
}

class _ObraFormSheet extends ConsumerStatefulWidget {
  const _ObraFormSheet({this.obra});

  final Obra? obra;

  @override
  ConsumerState<_ObraFormSheet> createState() => _ObraFormSheetState();
}

class _ObraFormSheetState extends ConsumerState<_ObraFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _cliente;
  late final TextEditingController _endereco;
  late final TextEditingController _contato;
  late final TextEditingController _telefone;
  late final TextEditingController _valor;
  late final TextEditingController _observacoes;

  late DateTime? _dataInicio;
  late DateTime? _dataPrevisao;
  late int _prioridade;
  late String _status;
  late String _cor;

  bool _saving = false;

  bool get _isEdit => widget.obra != null;

  @override
  void initState() {
    super.initState();
    final o = widget.obra;
    _nome = TextEditingController(text: o?.nome ?? '');
    _cliente = TextEditingController(text: o?.cliente ?? '');
    _endereco = TextEditingController(text: o?.endereco ?? '');
    _contato = TextEditingController(text: o?.contatoResponsavel ?? '');
    _telefone = TextEditingController(text: o?.telefoneContato ?? '');
    _valor = TextEditingController(
      text: o?.valorObra != null ? o!.valorObra!.toStringAsFixed(2) : '',
    );
    _observacoes = TextEditingController(text: o?.observacoes ?? '');
    _dataInicio = o?.dataInicio;
    _dataPrevisao = o?.dataPrevisao;
    _prioridade = o?.prioridade ?? 1;
    _status = o?.status ?? 'ativa';
    _cor = o?.cor ??
        _paletaCores[DateTime.now().microsecond % _paletaCores.length];
  }

  @override
  void dispose() {
    _nome.dispose();
    _cliente.dispose();
    _endereco.dispose();
    _contato.dispose();
    _telefone.dispose();
    _valor.dispose();
    _observacoes.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool inicio) async {
    final atual = inicio ? _dataInicio : _dataPrevisao;
    final picked = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (inicio) {
          _dataInicio = picked;
        } else {
          _dataPrevisao = picked;
        }
      });
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    String? nz(TextEditingController c) {
      final v = c.text.trim();
      return v.isEmpty ? null : v;
    }

    final payload = <String, dynamic>{
      'nome': _nome.text.trim(),
      'cliente': _cliente.text.trim(),
      'endereco': nz(_endereco),
      'status': _status,
      'data_inicio': _dataInicio?.toIso8601String().split('T').first,
      'data_previsao': _dataPrevisao?.toIso8601String().split('T').first,
      'prioridade': _prioridade,
      'observacoes': nz(_observacoes),
      'contato_responsavel': nz(_contato),
      'telefone_contato': nz(_telefone),
      'valor_obra': double.tryParse(_valor.text.replaceAll(',', '.')),
      'cor': _cor,
    };

    try {
      final repo = ref.read(obrasRepositoryProvider);
      if (_isEdit) {
        await repo.updateObra(widget.obra!.id, payload);
        ref.invalidate(obraProvider(widget.obra!.id));
      } else {
        await repo.createObra(payload);
      }
      ref.invalidate(obrasListProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    _isEdit ? 'Editar Obra' : 'Nova Obra',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
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
                decoration: const InputDecoration(labelText: 'Nome da obra *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cliente,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Cliente *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o cliente' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _endereco,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Endereço'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _contato,
                      enabled: !_saving,
                      decoration:
                          const InputDecoration(labelText: 'Contato'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _telefone,
                      enabled: !_saving,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Telefone'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Data início',
                      value: _dataInicio,
                      onTap: _saving ? null : () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'Previsão',
                      value: _dataPrevisao,
                      onTap: _saving ? null : () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _prioridade,
                      decoration: const InputDecoration(labelText: 'Prioridade'),
                      items: List.generate(
                        10,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('#${i + 1}'),
                        ),
                      ),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _prioridade = v ?? 1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: _statusOptions
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(_statusLabels[s]!),
                              ))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _status = v ?? 'ativa'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valor,
                enabled: !_saving,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Valor da obra (R\$)'),
              ),
              const SizedBox(height: 16),
              const Text('Cor da obra',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _paletaCores.map((hex) {
                  final color = hexToColorSafe(hex);
                  final selected = _cor == hex;
                  return GestureDetector(
                    onTap: _saving ? null : () => setState(() => _cor = hex),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? AppColors.foreground : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _observacoes,
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Observações'),
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
                    : Text(_isEdit ? 'Salvar alterações' : 'Cadastrar obra'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color hexToColorSafe(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(0xFF000000 | int.parse(h, radix: 16));
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, this.onTap});

  final String label;
  final DateTime? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(value != null ? Formatters.dataBr(value) : 'Selecionar'),
      ),
    );
  }
}
