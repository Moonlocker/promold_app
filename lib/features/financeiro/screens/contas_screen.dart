import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/auth_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_input.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/xlsx_import_sheet.dart';
import '../../../models/conta_financeira.dart';
import '../../../providers/cadastros_providers.dart';
import '../../../providers/financeiro_providers.dart';
import '../../../providers/fiscal_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../../../services/xlsx_service.dart';
import '../../fornecedores/widgets/fornecedor_form_sheet.dart';
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
  DateTime? _de;
  DateTime? _ate;

  bool get _isPagar => widget.tipo == 'pagar';

  List<ContaFinanceira> _filtrar(List<ContaFinanceira> contas) {
    final s = _busca.toLowerCase();
    return contas.where((c) {
      if (_status != 'todos' && c.statusEfetivo != _status) return false;
      if (_categoria != 'todos' && c.categoriaId != _categoria) return false;
      if (_de != null || _ate != null) {
        final v = DateTime.tryParse(c.dataVencimento);
        if (v == null) return false;
        if (_de != null &&
            v.isBefore(DateTime(_de!.year, _de!.month, _de!.day))) {
          return false;
        }
        if (_ate != null &&
            v.isAfter(
                DateTime(_ate!.year, _ate!.month, _ate!.day, 23, 59, 59))) {
          return false;
        }
      }
      return c.descricao.toLowerCase().contains(s) ||
          (c.cliente ?? '').toLowerCase().contains(s);
    }).toList();
  }

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
        actions: [
          IconButton(
            tooltip: 'Importar XLSX',
            onPressed: _importarXlsx,
            icon: const Icon(Icons.upload_file_outlined),
          ),
          IconButton(
            tooltip: 'Exportar XLSX',
            onPressed: _exportarXlsx,
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
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
          final filtradas = _filtrar(contas);

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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(true),
                        icon: const Icon(Icons.calendar_today, size: 15),
                        label: Text(
                          _de == null ? 'De' : Formatters.dataBr(_de),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(false),
                        icon: const Icon(Icons.event, size: 15),
                        label: Text(
                          _ate == null ? 'Até' : Formatters.dataBr(_ate),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_de != null || _ate != null)
                      IconButton(
                        tooltip: 'Limpar período',
                        onPressed: () => setState(() {
                          _de = null;
                          _ate = null;
                        }),
                        icon: const Icon(Icons.close, size: 18),
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

  Future<void> _pickDate(bool inicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (inicio ? _de : _ate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (inicio) {
        _de = picked;
      } else {
        _ate = picked;
      }
    });
  }

  Future<void> _exportarXlsx() async {
    final contas = (_isPagar
                ? ref.read(contasPagarListProvider)
                : ref.read(contasReceberListProvider))
            .value ??
        const <ContaFinanceira>[];
    final filtradas = _filtrar(contas);
    if (filtradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nada para exportar')),
      );
      return;
    }
    final cats =
        ref.read(categoriasFinanceirasListProvider).value ?? const [];
    final fornecedores = ref.read(fornecedoresListProvider).value ?? const [];
    String? catNome(String? id) =>
        cats.where((x) => x.id == id).firstOrNull?.nome;
    String? fornNome(String? id) {
      final f = fornecedores.where((x) => x.id == id).firstOrNull;
      if (f == null) return null;
      return f.nomeFantasia ?? f.razaoSocial;
    }

    try {
      final ok = await XlsxService.exportar(
        nomeArquivo:
            'contas-${_isPagar ? 'pagar' : 'receber'}-${Formatters.hojeBr()}.xlsx',
        headers: [
          'Descrição',
          'Valor',
          _isPagar ? 'Pago' : 'Recebido',
          'Vencimento',
          'Status',
          _isPagar ? 'Fornecedor' : 'Cliente',
          'Categoria',
        ],
        rows: filtradas
            .map((c) => [
                  c.descricao,
                  c.valor,
                  c.liquidado,
                  c.dataVencimento,
                  c.statusEfetivo,
                  _isPagar ? (fornNome(c.fornecedorId) ?? '') : (c.cliente ?? ''),
                  catNome(c.categoriaId) ?? '',
                ])
            .toList(),
      );
      if (mounted && ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${filtradas.length} linha(s) exportada(s)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
      }
    }
  }

  Future<void> _importarXlsx() async {
    final ok = await showXlsxImportSheet(
      context,
      title: _isPagar ? 'Importar Contas a Pagar' : 'Importar Contas a Receber',
      templateName: _isPagar ? 'contas-pagar' : 'contas-receber',
      columns: [
        const XlsxImportColumn(
            key: 'descricao',
            label: 'Descrição',
            required: true,
            example: 'Aluguel galpão'),
        const XlsxImportColumn(
            key: 'valor',
            label: 'Valor',
            required: true,
            isNumber: true,
            example: '1500.00'),
        const XlsxImportColumn(
            key: 'data_vencimento',
            label: 'Vencimento (AAAA-MM-DD)',
            required: true,
            example: '2026-06-10'),
        if (!_isPagar)
          const XlsxImportColumn(
              key: 'cliente', label: 'Cliente', example: 'Construtora ABC'),
        const XlsxImportColumn(key: 'observacoes', label: 'Observações'),
      ],
      onImport: (rows) async {
        final normalizadas = rows.map((r) {
          final map = Map<String, dynamic>.from(r);
          map['data_vencimento'] =
              normalizarDataBr(map['data_vencimento'] as String?);
          return map;
        }).toList();
        await ref
            .read(financeiroRepositoryProvider)
            .createParcelas(widget.tipo, normalizadas);
        return normalizadas.length;
      },
    );
    if (ok == true) _invalidar();
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
                    ].join(' · '),
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
                      if (conta.isPagar && conta.notaFiscalId != null) ...[
                        const SizedBox(width: 4),
                        _NotaFiscalButton(notaFiscalId: conta.notaFiscalId!),
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
                          if (conta.isPagar &&
                              conta.fornecedorId != null &&
                              ref.podeEditar('financeiro-contas-pagar'))
                            const PopupMenuItem(
                                value: 'editar_fornecedor',
                                child: Text('Editar dados do fornecedor')),
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
                                child: Text('Editar liquidação')),
                          if (ref.podeEditar(conta.isPagar
                                  ? 'financeiro-contas-pagar'
                                  : 'financeiro-contas-receber') &&
                              conta.liquidado > 0)
                            const PopupMenuItem(
                                value: 'reverter',
                                child: Text('Desmarcar liquidação')),
                          if (ref.podeCriar(conta.isPagar
                                  ? 'financeiro-contas-pagar'
                                  : 'financeiro-contas-receber') &&
                              conta.isReceber &&
                              conta.statusEfetivo != 'recebido' &&
                              conta.statusEfetivo != 'cancelado')
                            const PopupMenuItem(
                                value: 'cobranca', child: Text('Gerar cobrança')),
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
      case 'editar_fornecedor':
        final fornecedores =
            ref.read(fornecedoresListProvider).value ?? const [];
        final f =
            fornecedores.where((x) => x.id == conta.fornecedorId).firstOrNull;
        if (f != null) {
          final ok = await showFornecedorFormSheet(context, fornecedor: f);
          if (ok == true) onChanged();
        }
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
            title: const Text('Desmarcar liquidação'),
            content: const Text(
                'Reverter esta conta para Pendente? Os valores liquidados serão zerados.'),
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

class _NotaFiscalButton extends ConsumerWidget {
  const _NotaFiscalButton({required this.notaFiscalId});

  final String notaFiscalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notas = ref.watch(notasRecebidasProvider).value ?? const [];
    final nota = notas.where((n) => n.id == notaFiscalId).firstOrNull;
    if (nota == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'NF ${nota.numero ?? ''}/${nota.serie ?? ''}',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.receipt_long, size: 18, color: AppColors.primary),
      onSelected: (v) async {
        final url = v == 'danfe' ? nota.danfeUrl : nota.xmlUrl;
        if (url != null && url.isNotEmpty) {
          await launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'danfe',
          enabled: (nota.danfeUrl ?? '').isNotEmpty,
          child: const Text('Baixar DANFE'),
        ),
        PopupMenuItem(
          value: 'xml',
          enabled: (nota.xmlUrl ?? '').isNotEmpty,
          child: const Text('Baixar XML'),
        ),
      ],
    );
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
