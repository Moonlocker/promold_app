import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/conta_financeira.dart';
import '../../../providers/financeiro_providers.dart';
import '../../../providers/supabase_providers.dart';

const _metodos = [
  ('pix', 'PIX'),
  ('boleto', 'Boleto'),
  ('dinheiro', 'Dinheiro'),
  ('transferencia', 'Transferência'),
  ('cartao', 'Cartão'),
  ('cheque', 'Cheque'),
  ('outro', 'Outro'),
];

/// Abre a folha de registro/edição de liquidação. Retorna `true` se salvou.
Future<bool?> showLiquidacaoSheet(
  BuildContext context, {
  required ContaFinanceira conta,
  bool editar = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _LiquidacaoSheet(conta: conta, editar: editar),
  );
}

class _LiquidacaoSheet extends ConsumerStatefulWidget {
  const _LiquidacaoSheet({required this.conta, required this.editar});

  final ContaFinanceira conta;
  final bool editar;

  @override
  ConsumerState<_LiquidacaoSheet> createState() => _LiquidacaoSheetState();
}

class _LiquidacaoSheetState extends ConsumerState<_LiquidacaoSheet> {
  late final TextEditingController _valor;
  DateTime? _data;
  String _metodo = 'pix';
  bool _saving = false;

  bool get _isPagar => widget.conta.isPagar;

  @override
  void initState() {
    super.initState();
    final c = widget.conta;
    final valorInicial = widget.editar ? c.liquidado : c.restante;
    _valor = TextEditingController(text: valorInicial.toStringAsFixed(2));
    final dataStr = _isPagar ? c.dataPagamento : c.dataRecebimento;
    _data = dataStr != null ? DateTime.tryParse(dataStr) : DateTime.now();
    _metodo = (_isPagar ? c.metodoPagamento : c.metodoRecebimento) ?? 'pix';
  }

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final valor = double.tryParse(_valor.text.replaceAll(',', '.'));
    if (valor == null || valor < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor inválido')),
      );
      return;
    }
    if (!widget.editar && valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor maior que zero')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(financeiroRepositoryProvider);
      final data = Formatters.iso(_data ?? DateTime.now());
      if (widget.editar) {
        await repo.editarLiquidacao(widget.conta,
            valor: valor, data: data, metodo: _metodo);
      } else {
        await repo.registrarLiquidacao(widget.conta,
            valor: valor, data: data, metodo: _metodo);
      }
      if (_isPagar) {
        ref.invalidate(contasPagarListProvider);
      } else {
        ref.invalidate(contasReceberListProvider);
      }
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
    final c = widget.conta;
    final titulo = widget.editar
        ? (_isPagar ? 'Editar pagamento' : 'Editar recebimento')
        : (_isPagar ? 'Registrar pagamento' : 'Registrar recebimento');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.descricao,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Total: ${Formatters.moeda(c.valor)}',
                      style: const TextStyle(fontSize: 12.5)),
                  Text('Liquidado: ${Formatters.moeda(c.liquidado)}',
                      style: const TextStyle(fontSize: 12.5)),
                  Text('Restante: ${Formatters.moeda(c.restante)}',
                      style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _valor,
              enabled: !_saving,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: _isPagar ? 'Valor do pagamento' : 'Valor do recebimento'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _saving
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _data ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _data = picked);
                    },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data',
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(Formatters.dataBr(_data)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _metodo,
              decoration: const InputDecoration(labelText: 'Forma'),
              items: _metodos
                  .map((m) => DropdownMenuItem(
                        value: m.$1,
                        child: Text(m.$2),
                      ))
                  .toList(),
              onChanged:
                  _saving ? null : (v) => setState(() => _metodo = v ?? 'pix'),
            ),
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
                  : const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }
}
