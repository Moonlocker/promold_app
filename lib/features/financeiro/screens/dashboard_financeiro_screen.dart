import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/conta_financeira.dart';
import '../../../providers/cadastros_providers.dart';
import '../../../providers/financeiro_providers.dart';

/// Dashboard Financeiro: visão consolidada de receitas e despesas.
class DashboardFinanceiroScreen extends ConsumerStatefulWidget {
  const DashboardFinanceiroScreen({super.key});

  @override
  ConsumerState<DashboardFinanceiroScreen> createState() =>
      _DashboardFinanceiroScreenState();
}

class _DashboardFinanceiroScreenState
    extends ConsumerState<DashboardFinanceiroScreen> {
  late DateTime _inicio;
  late DateTime _fim;
  String _categoria = 'todos';
  String _centro = 'todos';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _inicio = DateTime(now.year, now.month - 5, 1);
    _fim = now;
  }

  @override
  Widget build(BuildContext context) {
    final pagarAsync = ref.watch(contasPagarListProvider);
    final receberAsync = ref.watch(contasReceberListProvider);
    final categorias =
        ref.watch(categoriasFinanceirasListProvider).value ?? const [];
    final centros = ref.watch(centrosCustoListProvider).value ?? const [];

    if (pagarAsync.isLoading || receberAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard Financeiro')),
        body: const LoadingView(),
      );
    }
    if (pagarAsync.hasError || receberAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard Financeiro')),
        body: Center(
          child: Text('Erro: ${pagarAsync.error ?? receberAsync.error}'),
        ),
      );
    }

    final pagar = (pagarAsync.value ?? const <ContaFinanceira>[]).where((c) {
      if (_categoria != 'todos' && c.categoriaId != _categoria) return false;
      if (_centro != 'todos' && c.centroCustoId != _centro) return false;
      return true;
    }).toList();
    final receber = (receberAsync.value ?? const <ContaFinanceira>[]).where((c) {
      if (_categoria != 'todos' && c.categoriaId != _categoria) return false;
      if (_centro != 'todos' && c.centroCustoId != _centro) return false;
      return true;
    }).toList();

    final totalReceitas =
        receber.fold<double>(0, (s, c) => s + c.valor);
    final totalRecebido =
        receber.fold<double>(0, (s, c) => s + c.liquidado);
    final totalDespesas = pagar.fold<double>(0, (s, c) => s + c.valor);
    final totalPago = pagar.fold<double>(0, (s, c) => s + c.liquidado);
    final lucro = totalRecebido - totalPago;
    final saldo = totalReceitas - totalDespesas;
    final aReceber = totalReceitas - totalRecebido;
    final aPagar = totalDespesas - totalPago;

    final despesasCategoria = _porCategoria(pagar, categorias);
    final receitasCategoria = _porCategoria(receber, categorias);
    final mensal = _mensal(pagar, receber);

    final proximos = <ContaFinanceira>[
      ...pagar.where((c) =>
          c.statusEfetivo == 'pendente' || c.statusEfetivo == 'parcial'),
      ...receber.where((c) =>
          c.statusEfetivo == 'pendente' || c.statusEfetivo == 'parcial'),
    ]..sort((a, b) => a.dataVencimento.compareTo(b.dataVencimento));

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Financeiro')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(contasPagarListProvider);
          ref.invalidate(contasReceberListProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'De',
                    value: _inicio,
                    onTap: () => _pick(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateButton(
                    label: 'Até',
                    value: _fim,
                    onTap: () => _pick(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _categoria,
                    isDense: true,
                    isExpanded: true,
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
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _centro,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Centro de custo', isDense: true),
                    items: [
                      const DropdownMenuItem(
                          value: 'todos', child: Text('Todos')),
                      ...centros.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.nome,
                                overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() => _centro = v ?? 'todos'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                _KpiCard(
                  label: 'Total Receitas',
                  valor: totalReceitas,
                  sub: 'Recebido: ${Formatters.moeda(totalRecebido)}',
                  cor: AppColors.success,
                  icon: Icons.arrow_upward,
                ),
                _KpiCard(
                  label: 'Total Despesas',
                  valor: totalDespesas,
                  sub: 'Pago: ${Formatters.moeda(totalPago)}',
                  cor: AppColors.destructive,
                  icon: Icons.arrow_downward,
                ),
                _KpiCard(
                  label: 'Lucro Realizado',
                  valor: lucro,
                  sub: 'Recebido − Pago',
                  cor: lucro >= 0 ? AppColors.primary : AppColors.destructive,
                  icon: Icons.trending_up,
                ),
                _KpiCard(
                  label: 'Saldo Projetado',
                  valor: saldo,
                  sub:
                      'A receber ${Formatters.moeda(aReceber)} | A pagar ${Formatters.moeda(aPagar)}',
                  cor: saldo >= 0 ? AppColors.success : AppColors.destructive,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SecaoCategoria(
              titulo: 'Receitas por categoria',
              cor: AppColors.success,
              dados: receitasCategoria,
              total: totalReceitas,
            ),
            const SizedBox(height: 16),
            _SecaoCategoria(
              titulo: 'Despesas por categoria',
              cor: AppColors.destructive,
              dados: despesasCategoria,
              total: totalDespesas,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Receitas vs Despesas por mês',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    ...mensal.map((m) => _BarraMes(dados: m)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Próximos vencimentos',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (proximos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Nenhum vencimento pendente',
                            style: TextStyle(
                                color: AppColors.mutedForeground)),
                      )
                    else
                      ...proximos.take(10).map((c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (c.isPagar
                                            ? AppColors.destructive
                                            : AppColors.success)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    c.isPagar ? 'Pagar' : 'Receber',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: c.isPagar
                                          ? AppColors.destructive
                                          : AppColors.success,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    c.descricao,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Text(
                                  Formatters.moeda(c.restante),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  Formatters.dataBr(
                                      DateTime.tryParse(c.dataVencimento)),
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.mutedForeground),
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(bool inicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: inicio ? _inicio : _fim,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => inicio ? _inicio = picked : _fim = picked);
    }
  }

  List<({String nome, double valor})> _porCategoria(
    List<ContaFinanceira> contas,
    List<dynamic> categorias,
  ) {
    final map = <String, double>{};
    for (final c in contas) {
      final nome = categorias
              .where((cat) => cat.id == c.categoriaId)
              .map((cat) => cat.nome as String)
              .firstOrNull ??
          'Sem categoria';
      map[nome] = (map[nome] ?? 0) + c.valor;
    }
    final lista = map.entries
        .map((e) => (nome: e.key, valor: e.value))
        .toList();
    lista.sort((a, b) => b.valor.compareTo(a.valor));
    return lista;
  }

  List<({String mes, double entradas, double saidas})> _mensal(
    List<ContaFinanceira> pagar,
    List<ContaFinanceira> receber,
  ) {
    final map = <String, ({double e, double s})>{};
    void add(ContaFinanceira c, bool entrada) {
      if (c.dataVencimento.length < 7) return;
      final key = c.dataVencimento.substring(0, 7);
      final atual = map[key] ?? (e: 0.0, s: 0.0);
      map[key] = entrada
          ? (e: atual.e + c.valor, s: atual.s)
          : (e: atual.e, s: atual.s + c.valor);
    }

    for (final c in receber) {
      add(c, true);
    }
    for (final c in pagar) {
      add(c, false);
    }

    final keys = map.keys.toList()..sort();
    return keys.map((k) {
      final v = map[k]!;
      final partes = k.split('-');
      final mes = '${partes[1]}/${partes[0].substring(2)}';
      return (mes: mes, entradas: v.e, saidas: v.s);
    }).toList();
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.valor,
    required this.cor,
    required this.icon,
    this.sub,
  });

  final String label;
  final double valor;
  final Color cor;
  final IconData icon;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: cor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Formatters.moeda(valor),
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: cor),
              ),
            ),
            if (sub != null)
              Text(
                sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.mutedForeground),
              ),
          ],
        ),
      ),
    );
  }
}

class _SecaoCategoria extends StatelessWidget {
  const _SecaoCategoria({
    required this.titulo,
    required this.cor,
    required this.dados,
    required this.total,
  });

  final String titulo;
  final Color cor;
  final List<({String nome, double valor})> dados;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: TextStyle(fontWeight: FontWeight.w700, color: cor)),
            const SizedBox(height: 12),
            if (dados.isEmpty)
              const Text('Sem dados',
                  style: TextStyle(color: AppColors.mutedForeground))
            else
              ...dados.take(8).map((d) {
                final pct = total > 0 ? d.valor / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(d.nome,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5)),
                          ),
                          Text(Formatters.moeda(d.valor),
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: AppColors.muted,
                          color: cor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _BarraMes extends StatelessWidget {
  const _BarraMes({required this.dados});

  final ({String mes, double entradas, double saidas}) dados;

  @override
  Widget build(BuildContext context) {
    final maxV = [
      dados.entradas,
      dados.saidas,
    ].fold<double>(0, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dados.mes,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          _barra(AppColors.success, dados.entradas, maxV),
          const SizedBox(height: 3),
          _barra(AppColors.destructive, dados.saidas, maxV),
        ],
      ),
    );
  }

  Widget _barra(Color cor, double valor, double maxV) {
    final frac = maxV > 0 ? valor / maxV : 0.0;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 10,
              backgroundColor: AppColors.muted,
              color: cor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 96,
          child: Text(
            Formatters.moeda(valor),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

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
        child: Text(Formatters.dataBr(value)),
      ),
    );
  }
}
