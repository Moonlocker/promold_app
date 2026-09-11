import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/conta_financeira.dart';
import '../../../providers/cadastros_providers.dart';
import '../../../providers/financeiro_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../widgets/cobranca_sheet.dart';
import '../widgets/conta_form_sheet.dart';
import '../widgets/liquidacao_sheet.dart';

/// Lista de contas a pagar ou a receber (tela parametrizada por [tipo]).
class ContasScreen extends ConsumerStatefulWidget {
  const ContasScreen({super.key, required this.tipo});

  final String tipo; // 'pagar' | 'receber'

  @override
  ConsumerState<ContasScreen> createState() => _ContasScreenState();
}

class _ContasScreenState extends ConsumerState<ContasScreen> {
  String _busca = '';
  String _status = 'todos';
  String _categoria = 'todos';

  bool get _isPagar => widget.tipo == 'pagar';

  @override
  Widget build(BuildContext context) {
    final async = _isPagar
        ? ref.watch(contasPagarListProvider)
        : ref.watch(contasReceberListProvider);
    final categorias =
        ref.watch(categoriasFinanceirasListProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isPagar ? 'Contas a Pagar' : 'Contas a Receber'),
      ),
      floatingActionButton: ref.podeCriar(
              _isPagar ? 'financeiro-contas-pagar' : 'financeiro-contas-receber')
          ? FloatingActionButton.extended(
              onPressed: () async {
                final ok = await showContaFormSheet(context, tipo: widget.tipo);
                if (ok == true) _invalidar();
              },
              icon: const Icon(Icons.add),
              label: const Text('Nova'),
            )
          : null,
      body: async.when(
        loading: () => const LoadingView(message: 'Carregando...'),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (contas) {
          final totais = _calcularTotais(contas);
          final filtradas = contas.where((c) {
            if (_status != 'todos' && c.statusEfetivo != _status) return false;
            if (_categoria != 'todos' && c.categoriaId != _categoria) {
              return false;
            }
            final s = _busca.toLowerCase();
            return c.descricao.toLowerCase().contains(s) ||
                (c.cliente ?? '').toLowerCase().contains(s);
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => _invalidar(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TotalBox(
                        label: 'Total',
                        valor: totais.total,
                        cor: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TotalBox(
                        label: _isPagar ? 'Pago' : 'Recebido',
                        valor: totais.liquidado,
                        cor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TotalBox(
                        label: 'Pendente',
                        valor: totais.pendente,
                        cor: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TotalBox(
                        label: 'Vencido',
                        valor: totais.vencido,
                        cor: AppColors.destructive,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Buscar conta...',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        isDense: true,
                        decoration: const InputDecoration(
                            labelText: 'Status', isDense: true),
                        items: [
                          const DropdownMenuItem(
                              value: 'todos', child: Text('Todos')),
                          const DropdownMenuItem(
                              value: 'pendente', child: Text('Pendente')),
                          const DropdownMenuItem(
                              value: 'parcial', child: Text('Parcial')),
                          DropdownMenuItem(
                              value: _isPagar ? 'pago' : 'recebido',
                              child: Text(_isPagar ? 'Pago' : 'Recebido')),
                          const DropdownMenuItem(
                              value: 'vencido', child: Text('Vencido')),
                        ],
                        onChanged: (v) =>
                            setState(() => _status = v ?? 'todos'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _categoria,
                        isDense: true,
                        decoration: const InputDecoration(
                            labelText: 'Categoria', isDense: true),
                        items: [
                          const DropdownMenuItem(
                              value: 'todos', child: Text('Todas')),
                          ...categorias.map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.nome,
                                    overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => _categoria = v ?? 'todos'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (filtradas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Nenhuma conta encontrada',
                    ),
                  )
                else
                  ...filtradas.map((c) => _ContaCard(
                        conta: c,
                        onChanged: _invalidar,
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  void _invalidar() {
    if (_isPagar) {
      ref.invalidate(contasPagarListProvider);
    } else {
      ref.invalidate(contasReceberListProvider);
    }
  }

  ({double total, double liquidado, double pendente, double vencido})
      _calcularTotais(List<ContaFinanceira> contas) {
    var total = 0.0, liquidado = 0.0, pendente = 0.0, vencido = 0.0;
    for (final c in contas) {
      total += c.valor;
      final efetivo = c.statusEfetivo;
      if (efetivo == 'pago' || efetivo == 'recebido') {
        liquidado += c.valor;
      } else if (efetivo == 'vencido') {
        vencido += c.restante;
      } else {
        pendente += c.restante;
      }
    }
    return (
      total: total,
      liquidado: liquidado,
      pendente: pendente,
      vencido: vencido,
    );
  }
}

class _ContaCard extends ConsumerWidget {
  const _ContaCard({required this.conta, required this.onChanged});

  final ContaFinanceira conta;
  final VoidCallback onChanged;

  Color get _statusCor {
    switch (conta.statusEfetivo) {
      case 'pago':
      case 'recebido':
        return AppColors.success;
      case 'parcial':
        return AppColors.info;
      case 'vencido':
        return AppColors.destructive;
      case 'cancelado':
        return AppColors.mutedForeground;
      default:
        return AppColors.warning;
    }
  }

  String get _statusLabel {
    switch (conta.statusEfetivo) {
      case 'pago':
        return 'Pago';
      case 'recebido':
        return 'Recebido';
      case 'parcial':
        return 'Parcial';
      case 'vencido':
        return 'Vencido';
      case 'cancelado':
        return 'Cancelado';
      default:
        return 'Pendente';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venc = DateTime.tryParse(conta.dataVencimento);
    final categoria =
        ref.watch(categoriasFinanceirasListProvider).value ?? const [];
    final catNome =
        categoria.where((c) => c.id == conta.categoriaId).firstOrNull?.nome;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conta.descricao,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (conta.totalParcelas != null)
                    Text(
                      'Parcela ${conta.numParcela}/${conta.totalParcelas}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.mutedForeground),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (conta.isReceber && (conta.cliente ?? '').isNotEmpty)
                        conta.cliente!,
                      ?catNome,
                      'Venc. ${Formatters.dataBr(venc)}',
                    ].join(' Â· '),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        Formatters.moeda(conta.valor),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      if (conta.liquidado > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${conta.isPagar ? 'Pago' : 'Receb.'} ${Formatters.moeda(conta.liquidado)}',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.success),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusCor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusCor,
                    ),
                  ),
                ),
                if (ref.podeEditar(conta.isPagar
                            ? 'financeiro-contas-pagar'
                            : 'financeiro-contas-receber') ||
                        ref.podeExcluir(conta.isPagar
                            ? 'financeiro-contas-pagar'
                            : 'financeiro-contas-receber'))
                    PopupMenuButton<String>(
                        onSelected: (v) => _acao(context, ref, v),
                        itemBuilder: (_) => [
                          if (ref.podeEditar(conta.isPagar
                              ? 'financeiro-contas-pagar'
                              : 'financeiro-contas-receber'))
                            const PopupMenuItem(
                                value: 'editar', child: Text('Editar conta')),
                          if (ref.podeEditar(conta.isPagar
                                  ? 'financeiro-contas-pagar'
                                  : 'financeiro-contas-receber') &&
                              conta.statusEfetivo != 'pago' &&
                              conta.statusEfetivo != 'recebido' &&
                              conta.statusEfetivo != 'cancelado')
                            PopupMenuItem(
                              value: 'liquidar',
                              child: Text(conta.isPagar
                                  ? 'Registrar pagamento'
                                  : 'Registrar recebimento'),
                            ),
                          if (ref.podeEditar(conta.isPagar
                                  ? 'financeiro-contas-pagar'
                                  : 'financeiro-contas-receber') &&
                              conta.liquidado > 0)
                            const PopupMenuItem(
                                value: 'editar_liquidacao',
                                child: Text('Editar liquidaÃ§Ã£o')),
                          if (ref.podeEditar(conta.isPagar
                                  ? 'financeiro-contas-pagar'
                                  : 'financeiro-contas-receber') &&
                              conta.liquidado > 0)
                            const PopupMenuItem(
                                value: 'reverter',
                                child: Text('Desmarcar liquidaÃ§Ã£o')),
                          if (ref.podeCriar(conta.isPagar
                                  ? 'financeiro-contas-pagar'
                                  : 'financeiro-contas-receber') &&
                              conta.isReceber &&
                              conta.statusEfetivo != 'recebido' &&
                              conta.statusEfetivo != 'cancelado')
                            const PopupMenuItem(
                                value: 'cobranca', child: Text('Gerar cobranÃ§a')),
                          if (ref.podeExcluir(conta.isPagar
                              ? 'financeiro-contas-pagar'
                              : 'financeiro-contas-receber'))
                            const PopupMenuItem(
                              value: 'excluir',
                              child: Text('Excluir',
                                  style:
                                      TextStyle(color: AppColors.destructive)),
                            ),
                        ],
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acao(BuildContext context, WidgetRef ref, String acao) async {
    final repo = ref.read(financeiroRepositoryProvider);
    switch (acao) {
      case 'editar':
        final ok = await showContaFormSheet(context,
            tipo: conta.tipo, conta: conta);
        if (ok == true) onChanged();
      case 'liquidar':
        final ok = await showLiquidacaoSheet(context, conta: conta);
        if (ok == true) onChanged();
      case 'editar_liquidacao':
        final ok = await showLiquidacaoSheet(context, conta: conta, editar: true);
        if (ok == true) onChanged();
      case 'reverter':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Desmarcar liquidaÃ§Ã£o'),
            content: const Text(
                'Reverter esta conta para Pendente? Os valores liquidados serÃ£o zerados.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reverter'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await repo.reverter(conta);
          onChanged();
        }
      case 'cobranca':
        await showCobrancaSheet(context, conta: conta);
        onChanged();
      case 'excluir':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir conta'),
            content: Text('Excluir "${conta.descricao}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.destructive),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await repo.deleteConta(conta.tipo, conta.id);
          onChanged();
        }
    }
  }
}

class _TotalBox extends StatelessWidget {
  const _TotalBox({
    required this.label,
    required this.valor,
    required this.cor,
  });

  final String label;
  final double valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10.5, color: AppColors.mutedForeground)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Formatters.moeda(valor),
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: cor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
