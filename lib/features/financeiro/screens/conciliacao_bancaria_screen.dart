import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/conta_financeira.dart';
import '../../../providers/financeiro_providers.dart';
import '../../../providers/supabase_providers.dart';

class _ExtratoItem {
  _ExtratoItem({
    required this.data,
    required this.descricao,
    required this.valor,
    required this.credito,
  });

  final String data;
  final String descricao;
  final double valor;
  final bool credito;
  ContaFinanceira? match;
  bool confirmado = false;
}

/// Conciliação bancária: importa extrato (CSV/OFX) e sugere correspondências.
class ConciliacaoBancariaScreen extends ConsumerStatefulWidget {
  const ConciliacaoBancariaScreen({super.key});

  @override
  ConsumerState<ConciliacaoBancariaScreen> createState() =>
      _ConciliacaoBancariaScreenState();
}

class _ConciliacaoBancariaScreenState
    extends ConsumerState<ConciliacaoBancariaScreen> {
  final List<_ExtratoItem> _extrato = [];
  String _busca = '';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final filtrados = _extrato
        .where((e) =>
            e.descricao.toLowerCase().contains(_busca.toLowerCase()))
        .toList();
    final total = _extrato.length;
    final comMatch = _extrato.where((e) => e.match != null).length;
    final confirmados = _extrato.where((e) => e.confirmado).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Conciliação Bancária')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Importar extrato bancário',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                    'Formatos suportados: CSV (data;descrição;valor) ou OFX.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _importar,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Selecionar arquivo'),
                  ),
                ],
              ),
            ),
          ),
          if (_extrato.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _Stat(label: 'Importados', valor: '$total')),
                const SizedBox(width: 8),
                Expanded(
                    child: _Stat(
                        label: 'Sugeridos',
                        valor: '$comMatch',
                        cor: AppColors.primary)),
                const SizedBox(width: 8),
                Expanded(
                    child: _Stat(
                        label: 'Conciliados',
                        valor: '$confirmados',
                        cor: AppColors.success)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _busca = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Buscar lançamento...',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(filtrados.length, (i) {
              final item = filtrados[i];
              return _ExtratoCard(
                item: item,
                onConfirmar: () => _confirmar(item),
                onRejeitar: () => setState(() => item.match = null),
              );
            }),
          ] else if (!_loading)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: EmptyState(
                icon: Icons.account_balance_outlined,
                title: 'Nenhum extrato importado',
                message:
                    'Importe um arquivo CSV ou OFX para conciliar automaticamente.',
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _importar() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'ofx', 'txt'],
    );
    if (files.isEmpty) return;
    setState(() => _loading = true);
    try {
      final bytes = await files.first.readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true);
      final itens = _parseExtrato(text);
      if (itens.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Não foi possível extrair dados. Use CSV (data;descrição;valor) ou OFX.'),
            ),
          );
        }
        return;
      }
      final repo = ref.read(financeiroRepositoryProvider);
      final pagar = await repo.listContasAbertas('pagar');
      final receber = await repo.listContasAbertas('receber');
      for (final item in itens) {
        final base = item.credito ? receber : pagar;
        final match = base.where((c) =>
            (c.restante - item.valor).abs() < 0.02 &&
            c.dataVencimento == item.data);
        if (match.isNotEmpty) item.match = match.first;
      }
      setState(() {
        _extrato
          ..clear()
          ..addAll(itens);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${itens.length} lançamentos importados · ${itens.where((e) => e.match != null).length} correspondências.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_ExtratoItem> _parseExtrato(String text) {
    final itens = <_ExtratoItem>[];
    if (text.contains('<OFX') || text.contains('<STMTTRN>')) {
      final regex = RegExp(r'<STMTTRN>([\s\S]*?)</STMTTRN>', caseSensitive: false);
      for (final m in regex.allMatches(text)) {
        final block = m.group(1) ?? '';
        final dt = RegExp(r'<DTPOSTED>(\d{8})').firstMatch(block)?.group(1);
        final amt =
            RegExp(r'<TRNAMT>([-\d.,]+)').firstMatch(block)?.group(1);
        final memo = RegExp(r'<MEMO>(.*?)(?:\n|<)').firstMatch(block)?.group(1);
        final name = RegExp(r'<NAME>(.*?)(?:\n|<)').firstMatch(block)?.group(1);
        if (dt != null && amt != null) {
          final valor = double.tryParse(amt.replaceAll(',', '.')) ?? 0;
          itens.add(_ExtratoItem(
            data: '${dt.substring(0, 4)}-${dt.substring(4, 6)}-${dt.substring(6, 8)}',
            descricao: (memo ?? name ?? 'Sem descrição').trim(),
            valor: valor.abs(),
            credito: valor >= 0,
          ));
        }
      }
      return itens;
    }

    final linhas = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (linhas.isEmpty) return itens;
    final sep = linhas.first.contains(';') ? ';' : ',';
    var inicio = RegExp(r'data|date', caseSensitive: false).hasMatch(linhas.first)
        ? 1
        : 0;
    for (var i = inicio; i < linhas.length; i++) {
      final cols = linhas[i]
          .split(sep)
          .map((c) => c.replaceAll('"', '').trim())
          .toList();
      if (cols.length < 3) continue;
      final valor = double.tryParse(cols[2].replaceAll(',', '.'));
      if (valor == null) continue;
      var data = cols[0];
      if (data.contains('/')) {
        final p = data.split('/');
        if (p.length == 3) {
          data = '${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}';
        }
      }
      itens.add(_ExtratoItem(
        data: data,
        descricao: cols[1],
        valor: valor.abs(),
        credito: valor >= 0,
      ));
    }
    return itens;
  }

  Future<void> _confirmar(_ExtratoItem item) async {
    final match = item.match;
    if (match == null) return;
    try {
      await ref.read(financeiroRepositoryProvider).conciliar(
            tipo: match.tipo,
            conta: match,
            valor: item.valor,
            data: item.data,
          );
      ref.invalidate(contasPagarListProvider);
      ref.invalidate(contasReceberListProvider);
      setState(() => item.confirmado = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conciliação confirmada!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }
}

class _ExtratoCard extends StatelessWidget {
  const _ExtratoCard({
    required this.item,
    required this.onConfirmar,
    required this.onRejeitar,
  });

  final _ExtratoItem item;
  final VoidCallback onConfirmar;
  final VoidCallback onRejeitar;

  @override
  Widget build(BuildContext context) {
    final match = item.match;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: item.confirmado ? 0.5 : 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.descricao,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.dataBr(DateTime.tryParse(item.data))} · ${item.credito ? 'Crédito' : 'Débito'}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.mutedForeground),
                    ),
                    if (match != null && !item.confirmado)
                      Text(
                        'Sugerido: ${match.descricao}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.primary),
                      ),
                  ],
                ),
              ),
              Text(
                Formatters.moeda(item.valor),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (item.confirmado)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.check_circle,
                      color: AppColors.success, size: 20),
                )
              else if (match != null)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check,
                          color: AppColors.success, size: 20),
                      onPressed: onConfirmar,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.destructive, size: 20),
                      onPressed: onRejeitar,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.valor, this.cor});

  final String label;
  final String valor;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10.5, color: AppColors.mutedForeground)),
            Text(valor,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cor)),
          ],
        ),
      ),
    );
  }
}
