import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/superadmin_providers.dart';
import '../../../providers/supabase_providers.dart';

/// SuperAdmin — aba Faturamento (faturas SaaS por organização).
class SuperAdminFaturamentoTab extends ConsumerStatefulWidget {
  const SuperAdminFaturamentoTab({super.key});

  @override
  ConsumerState<SuperAdminFaturamentoTab> createState() =>
      _SuperAdminFaturamentoTabState();
}

class _SuperAdminFaturamentoTabState
    extends ConsumerState<SuperAdminFaturamentoTab> {
  int _ano = DateTime.now().year;
  int _mes = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final orgsAsync = ref.watch(todasOrganizacoesProvider);
    final faturasAsync = ref.watch(faturasMesProvider((_ano, _mes)));
    final orgs = orgsAsync.value ?? const [];
    final faturas = faturasAsync.value ?? const [];
    final porOrg = <String, Map<String, dynamic>>{
      for (final f in faturas)
        (f['organizacao_id'] as String? ?? ''): f,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: orgsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (_) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(() => _mudarMes(-1)),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${_mes.toString().padLeft(2, '0')}/$_ano',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(() => _mudarMes(1)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: orgs.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Nenhuma organização')
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(todasOrganizacoesProvider);
                          ref.invalidate(faturasMesProvider((_ano, _mes)));
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: orgs.length,
                          itemBuilder: (context, i) {
                            final o = orgs[i];
                            final orgId = o['id'] as String;
                            final fatura = porOrg[orgId];
                            return _OrgFaturaCard(
                              org: o,
                              fatura: fatura,
                              ano: _ano,
                              mes: _mes,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mudarMes(int delta) {
    var m = _mes + delta;
    var a = _ano;
    if (m < 1) {
      m = 12;
      a -= 1;
    } else if (m > 12) {
      m = 1;
      a += 1;
    }
    setState(() {
      _mes = m;
      _ano = a;
    });
  }
}

class _OrgFaturaCard extends ConsumerWidget {
  const _OrgFaturaCard({
    required this.org,
    required this.fatura,
    required this.ano,
    required this.mes,
  });

  final Map<String, dynamic> org;
  final Map<String, dynamic>? fatura;
  final int ano;
  final int mes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valor = (fatura?['valor_total'] as num?)?.toDouble();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(org['nome'] as String? ?? 'Organização',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          fatura == null
              ? 'Sem fatura neste mês'
              : '${fatura!['status']}'
                  '${valor != null ? ' · ${Formatters.moeda(valor)}' : ''}'
                  '${fatura!['data_vencimento'] != null ? ' · venc. ${Formatters.dataBr(DateTime.tryParse(fatura!['data_vencimento'] as String))}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (v) => _acao(context, ref, v),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: fatura == null ? 'gerar' : 'regerar',
              child: Text(fatura == null ? 'Gerar fatura' : 'Regenerar'),
            ),
            if (fatura != null)
              const PopupMenuItem(value: 'editar', child: Text('Editar')),
            if (fatura != null && fatura!['status'] != 'paga')
              const PopupMenuItem(
                  value: 'paga', child: Text('Marcar como paga')),
            if (fatura != null)
              const PopupMenuItem(
                value: 'excluir',
                child: Text('Excluir',
                    style: TextStyle(color: AppColors.destructive)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _acao(BuildContext context, WidgetRef ref, String acao) async {
    final repo = ref.read(superAdminRepositoryProvider);
    final orgId = org['id'] as String;
    switch (acao) {
      case 'gerar':
      case 'regerar':
        try {
          final calc = await repo.calcularFatura(orgId, ano, mes);
          final venc = DateTime(ano, mes, 10);
          await repo.upsertFatura({
            'organizacao_id': orgId,
            'ano': ano,
            'mes': mes,
            'valor_base': calc['valor_fixo'] ?? calc['valor_base'],
            'valor_faixa': calc['valor_variavel'] ?? calc['valor_faixa'],
            'valor_total': calc['valor_total'] ?? 0,
            'm3_produzidos': calc['m3_produzidos'] ?? 0,
            'status': 'pendente',
            'data_vencimento': Formatters.iso(venc),
          });
          ref.invalidate(faturasMesProvider((ano, mes)));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fatura gerada')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Erro: $e')));
          }
        }
      case 'paga':
        await repo.updateFatura(fatura!['id'] as String, {
          'status': 'paga',
          'data_pagamento': DateTime.now().toIso8601String(),
          'metodo_pagamento': 'manual',
        });
        ref.invalidate(faturasMesProvider((ano, mes)));
      case 'editar':
        await _editar(context, ref);
      case 'excluir':
        await repo.deleteFatura(fatura!['id'] as String);
        ref.invalidate(faturasMesProvider((ano, mes)));
    }
  }

  Future<void> _editar(BuildContext context, WidgetRef ref) async {
    final f = fatura!;
    final valor = TextEditingController(
        text: ((f['valor_total'] as num?)?.toDouble() ?? 0)
            .toStringAsFixed(2));
    final venc = TextEditingController(
        text: (f['data_vencimento'] as String?) ?? '');
    String status = (f['status'] as String?) ?? 'pendente';
    final statusList = ['pendente', 'em_aberto', 'paga', 'vencida', 'cancelada'];

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Editar fatura',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextField(
                  controller: valor,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Valor total (R\$)', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: venc,
                  decoration: const InputDecoration(
                      labelText: 'Vencimento (AAAA-MM-DD)', isDense: true),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: statusList.contains(status) ? status : 'pendente',
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: statusList
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setSheet(() => status = v ?? status),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _enviarNf(context, ref, f['id'] as String),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Anexar Nota Fiscal (PDF)'),
                ),
                if ((f['nota_fiscal_nome'] as String?)?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('NF: ${f['nota_fiscal_nome']}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    await ref
                        .read(superAdminRepositoryProvider)
                        .updateFatura(f['id'] as String, {
                      'valor_total':
                          double.tryParse(valor.text.replaceAll(',', '.')) ?? 0,
                      'data_vencimento':
                          venc.text.trim().isEmpty ? null : venc.text.trim(),
                      'status': status,
                    });
                    ref.invalidate(faturasMesProvider((ano, mes)));
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    valor.dispose();
    venc.dispose();
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Fatura atualizada')));
    }
  }

  Future<void> _enviarNf(
    BuildContext context,
    WidgetRef ref,
    String faturaId,
  ) async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final file = res.firstOrNull;
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      final url = await ref.read(superAdminRepositoryProvider).uploadNotaFiscal(
            faturaId: faturaId,
            bytes: bytes,
            nomeArquivo: file.name,
          );
      await ref.read(superAdminRepositoryProvider).updateFatura(faturaId, {
        'nota_fiscal_url': url,
        'nota_fiscal_nome': file.name,
      });
      ref.invalidate(faturasMesProvider((ano, mes)));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Nota fiscal anexada')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }
}
