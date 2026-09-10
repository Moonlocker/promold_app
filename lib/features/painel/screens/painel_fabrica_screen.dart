import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/status_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../models/obra_peca.dart';
import '../../../models/painel_fabrica.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/painel_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../../obras/widgets/obra_peca_edit_sheet.dart';

/// Painel da Fábrica (módulo `painel-fabrica` no webapp).
class PainelFabricaScreen extends ConsumerWidget {
  const PainelFabricaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dadosAsync = ref.watch(painelDadosProvider);
    final tipo = ref.watch(painelTipoProvider);
    final isArmacao = tipo == 'armacao';

    return Scaffold(
      backgroundColor: AppColors.sidebar,
      appBar: AppBar(
        backgroundColor: AppColors.sidebar,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Painel da Fábrica'),
            Text(
              '${Formatters.dataBr(DateTime.now())} · '
              '${Formatters.dataHoraBr(DateTime.now()).split(' ').last}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.sidebarForeground,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _Toggle(
              isArmacao: isArmacao,
              onChange: (v) => ref.read(painelTipoProvider.notifier).set(v),
            ),
          ),
          Expanded(
            child: dadosAsync.when(
              loading: () => const LoadingView(message: 'Carregando painel...'),
              error: (error, _) => ErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(painelDadosProvider),
              ),
              data: (dados) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(painelDadosProvider),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Metricas(dados: dados, isArmacao: isArmacao),
                    const SizedBox(height: 14),
                    _SemanaStrip(dados: dados),
                    const SizedBox(height: 14),
                    _ProducaoDoDia(
                      dados: dados,
                      isArmacao: isArmacao,
                      onPecaTap: (p) => _editarPeca(context, ref, p),
                    ),
                    const SizedBox(height: 14),
                    _StatusObras(dados: dados, isArmacao: isArmacao),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editarPeca(
    BuildContext context,
    WidgetRef ref,
    PainelPeca p,
  ) async {
    if (p.obraPecaId == null) return;
    final repo = ref.read(obrasRepositoryProvider);
    final pecas = await repo.listPecas(p.obraId);
    ObraPeca? alvo;
    for (final item in pecas) {
      if (item.id == p.obraPecaId) {
        alvo = item;
        break;
      }
    }
    if (alvo == null || !context.mounted) return;
    final salvou = await showPecaEditSheet(
      context,
      ref,
      peca: alvo,
      todas: pecas,
    );
    if (salvou == true) {
      ref.invalidate(painelDadosProvider);
      ref.invalidate(todasPecasResumoProvider);
    }
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.isArmacao, required this.onChange});

  final bool isArmacao;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.sidebarAccent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleBtn(
              label: 'Armação',
              icon: Icons.hardware_outlined,
              ativo: isArmacao,
              cor: AppColors.accent,
              onTap: () => onChange('armacao'),
            ),
          ),
          Expanded(
            child: _ToggleBtn(
              label: 'Produção',
              icon: Icons.water_drop_outlined,
              ativo: !isArmacao,
              cor: AppColors.primary,
              onTap: () => onChange('producao'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.label,
    required this.icon,
    required this.ativo,
    required this.cor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool ativo;
  final Color cor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: ativo ? cor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: ativo ? Colors.white : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ativo ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metricas extends StatelessWidget {
  const _Metricas({required this.dados, required this.isArmacao});

  final PainelDados dados;
  final bool isArmacao;

  @override
  Widget build(BuildContext context) {
    final realizado = isArmacao ? 'Armado' : 'Concretado';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Planejado',
                valor: '${dados.planejadoDia}',
                detalhe: Formatters.dataBr(DateTime.now()),
                icon: Icons.flag_outlined,
                cor: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: realizado,
                valor: '${dados.producaoDia}',
                detalhe: '${dados.percentualDia}% da meta',
                icon: Icons.inventory_2_outlined,
                cor: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Pendente',
                valor: '${dados.pendenteDia}',
                detalhe: 'restam',
                icon: Icons.schedule_outlined,
                cor: dados.pendenteDia > 0
                    ? AppColors.warning
                    : AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Semana',
                valor: '${dados.percentualSemana}%',
                detalhe: '${dados.producaoSemana}/${dados.planejadoSemana}',
                icon: Icons.calendar_month_outlined,
                cor: AppColors.info,
                progresso: dados.percentualSemana,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.valor,
    required this.detalhe,
    required this.icon,
    required this.cor,
    this.progresso,
  });

  final String label;
  final String valor;
  final String detalhe;
  final IconData icon;
  final Color cor;
  final int? progresso;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sidebarAccent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: cor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.sidebarForeground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          if (progresso != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (progresso! / 100).clamp(0, 1).toDouble(),
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _corBarra(progresso!),
                ),
              ),
            )
          else
            Text(
              detalhe,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.sidebarForeground,
              ),
            ),
          if (progresso != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                detalhe,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.sidebarForeground,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Color _corBarra(int pct) {
  if (pct >= 100) return AppColors.success;
  if (pct >= 75) return AppColors.info;
  if (pct >= 50) return AppColors.warning;
  return AppColors.destructive;
}

Color _corPercentual(int pct) {
  if (pct >= 100) return AppColors.success;
  if (pct >= 75) return AppColors.info;
  if (pct >= 50) return AppColors.warning;
  if (pct > 0) return AppColors.warning;
  return AppColors.sidebarForeground;
}

class _SemanaStrip extends ConsumerWidget {
  const _SemanaStrip({required this.dados});

  final PainelDados dados;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selecionado = ref.watch(painelDiaProvider);
    final selStr = Formatters.iso(selecionado);

    return Row(
      children: [
        for (final dia in dados.diasSemana)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _DiaChip(
                dia: dia,
                selecionado: dia.diaStr == selStr,
                onTap: () => ref.read(painelDiaProvider.notifier).set(dia.dia),
              ),
            ),
          ),
      ],
    );
  }
}

class _DiaChip extends StatelessWidget {
  const _DiaChip({
    required this.dia,
    required this.selecionado,
    required this.onTap,
  });

  final PainelDiaResumo dia;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasData = dia.planejado > 0;
    final Color fundo;
    final Color borda;
    if (selecionado) {
      fundo = AppColors.primary;
      borda = AppColors.primary;
    } else if (dia.isHoje) {
      fundo = AppColors.primary.withValues(alpha: 0.2);
      borda = AppColors.primary.withValues(alpha: 0.5);
    } else if (hasData) {
      fundo = AppColors.sidebarAccent;
      borda = Colors.white12;
    } else {
      fundo = AppColors.sidebarAccent.withValues(alpha: 0.5);
      borda = Colors.transparent;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borda),
        ),
        child: Column(
          children: [
            Text(
              dia.diaNome,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selecionado ? Colors.white : AppColors.sidebarForeground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hasData ? '${dia.percentual}%' : '-',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: selecionado
                    ? Colors.white
                    : _corPercentual(dia.percentual),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProducaoDoDia extends StatelessWidget {
  const _ProducaoDoDia({
    required this.dados,
    required this.isArmacao,
    required this.onPecaTap,
  });

  final PainelDados dados;
  final bool isArmacao;
  final ValueChanged<PainelPeca> onPecaTap;

  @override
  Widget build(BuildContext context) {
    final total = dados.obrasDoDia.fold<int>(0, (a, o) => a + o.total);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sidebarAccent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'PRODUÇÃO DO DIA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '$total peças · ${dados.obrasDoDia.length} obra(s)',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.sidebarForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (dados.obrasDoDia.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nenhuma peça planejada para este dia.',
                  style: TextStyle(color: AppColors.sidebarForeground),
                ),
              ),
            )
          else
            for (final obra in dados.obrasDoDia) ...[
              _ObraDiaCard(
                obra: obra,
                isArmacao: isArmacao,
                onPecaTap: onPecaTap,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ObraDiaCard extends StatelessWidget {
  const _ObraDiaCard({
    required this.obra,
    required this.isArmacao,
    required this.onPecaTap,
  });

  final PainelObraDia obra;
  final bool isArmacao;
  final ValueChanged<PainelPeca> onPecaTap;

  @override
  Widget build(BuildContext context) {
    final cor = obra.obraCor != null ? hexToColor(obra.obraCor) : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: obra.completa
            ? AppColors.success.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: obra.completa
              ? AppColors.success.withValues(alpha: 0.4)
              : Colors.white12,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (cor != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  obra.obraNome.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${obra.produzido}/${obra.total}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: obra.completa
                      ? AppColors.success
                      : AppColors.sidebarForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final tipo in obra.tipos) ...[
            Text(
              '${tipo.pecaNome}:',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.sidebarForeground,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in tipo.pieces)
                  _PecaChip(peca: p, onTap: () => onPecaTap(p)),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _PecaChip extends StatelessWidget {
  const _PecaChip({required this.peca, required this.onTap});

  final PainelPeca peca;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final produzido = peca.produzido;
    return InkWell(
      onTap: peca.obraPecaId != null ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: produzido
              ? AppColors.success.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: produzido
                ? AppColors.success.withValues(alpha: 0.5)
                : Colors.white12,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (produzido) ...[
                  const Icon(Icons.check, size: 10, color: AppColors.success),
                  const SizedBox(width: 3),
                ],
                Text(
                  peca.identificador,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: produzido ? AppColors.success : Colors.white,
                  ),
                ),
              ],
            ),
            Text(
              peca.dimensoes,
              style: TextStyle(
                fontSize: 9,
                fontFamily: 'monospace',
                color: produzido
                    ? AppColors.success.withValues(alpha: 0.8)
                    : AppColors.sidebarForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusObras extends StatelessWidget {
  const _StatusObras({required this.dados, required this.isArmacao});

  final PainelDados dados;
  final bool isArmacao;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sidebarAccent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STATUS DAS OBRAS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (dados.obrasResumo.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Nenhuma obra ativa.',
                  style: TextStyle(color: AppColors.sidebarForeground),
                ),
              ),
            )
          else
            for (final obra in dados.obrasResumo) ...[
              _ObraResumoCard(obra: obra, isArmacao: isArmacao),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _ObraResumoCard extends StatelessWidget {
  const _ObraResumoCard({required this.obra, required this.isArmacao});

  final PainelObraResumo obra;
  final bool isArmacao;

  @override
  Widget build(BuildContext context) {
    final cor = _corPercentual(obra.percentual);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: obra.needsAttention
            ? AppColors.warning.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: obra.needsAttention
              ? AppColors.warning.withValues(alpha: 0.35)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          ProgressRing(
            value: obra.percentual.toDouble(),
            size: 46,
            strokeWidth: 4,
            color: cor,
            trackColor: Colors.white12,
            labelColor: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        obra.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (obra.needsAttention)
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _MiniTag(
                      valor: '${obra.produzido}',
                      label: isArmacao ? 'arm.' : 'prod.',
                      cor: AppColors.success,
                    ),
                    const SizedBox(width: 6),
                    _MiniTag(
                      valor: '${obra.pendente}',
                      label: 'pend.',
                      cor: AppColors.warning,
                    ),
                  ],
                ),
                if (obra.endereco != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 11,
                        color: AppColors.sidebarForeground,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          obra.endereco!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.sidebarForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.valor, required this.label, required this.cor});

  final String valor;
  final String label;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 11, color: cor),
          children: [
            TextSpan(
              text: valor,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: ' $label'),
          ],
        ),
      ),
    );
  }
}
