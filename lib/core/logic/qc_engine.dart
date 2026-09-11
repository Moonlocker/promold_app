/// Engine do módulo Qualidade (porte de `qcCodigoEngine.ts`, `qcTemplates.ts`
/// e `qcEvaluate.ts`).
library;

import '../../models/qc.dart';

enum QcGrupo { inicial, seteDias, vinteOitoDias, livre }

extension QcGrupoX on QcGrupo {
  String get value => switch (this) {
        QcGrupo.inicial => 'inicial',
        QcGrupo.seteDias => '7d',
        QcGrupo.vinteOitoDias => '28d',
        QcGrupo.livre => 'livre',
      };

  static QcGrupo fromValue(String? v) => switch (v) {
        'inicial' => QcGrupo.inicial,
        '7d' => QcGrupo.seteDias,
        '28d' => QcGrupo.vinteOitoDias,
        _ => QcGrupo.livre,
      };
}

class QcTemplateItem {
  const QcTemplateItem({
    required this.grupo,
    required this.label,
    required this.idadeDias,
    required this.qtd,
    this.idadeHoras,
  });

  final QcGrupo grupo;
  final String label;
  final int idadeDias;
  final int qtd;
  final int? idadeHoras;
}

class QcTemplate {
  const QcTemplate({
    required this.slug,
    required this.nome,
    required this.descricao,
    required this.itens,
  });

  final String slug;
  final String nome;
  final String descricao;
  final List<QcTemplateItem> itens;
}

const List<QcTemplate> qcTemplates = [
  QcTemplate(
    slug: 'dupla-inicial',
    nome: 'Apenas 2 CPs (rompimento inicial)',
    descricao: '2 corpos para rompimento inicial (16h / 1 dia) — liberação por FCJ.',
    itens: [
      QcTemplateItem(
          grupo: QcGrupo.inicial,
          label: '16h',
          idadeDias: 1,
          idadeHoras: 16,
          qtd: 2),
    ],
  ),
  QcTemplate(
    slug: 'completo-6',
    nome: 'Conjunto completo (6 CPs)',
    descricao: '2 iniciais (16h) + 2 aos 7 dias + 2 aos 28 dias.',
    itens: [
      QcTemplateItem(
          grupo: QcGrupo.inicial,
          label: '16h',
          idadeDias: 1,
          idadeHoras: 16,
          qtd: 2),
      QcTemplateItem(
          grupo: QcGrupo.seteDias, label: '7d', idadeDias: 7, qtd: 2),
      QcTemplateItem(
          grupo: QcGrupo.vinteOitoDias, label: '28d', idadeDias: 28, qtd: 2),
    ],
  ),
];

QcTemplate? getTemplateBySlug(String slug) {
  for (final t in qcTemplates) {
    if (t.slug == slug) return t;
  }
  return null;
}

/// Renderiza um código a partir de um padrão com tokens.
String renderQcCodigo(String padrao, {String? sigla, required int seq, DateTime? date}) {
  final d = date ?? DateTime.now();
  String pad(int n, int w) => n.toString().padLeft(w, '0');
  final map = <String, String>{
    '{YYYY}': '${d.year}',
    '{YY}': '${d.year}'.substring(2),
    '{MM}': pad(d.month, 2),
    '{DD}': pad(d.day, 2),
    '{HH}': pad(d.hour, 2),
    '{mm}': pad(d.minute, 2),
    '{SIGLA}': sigla ?? '',
    '{SEQ}': '$seq',
    '{SEQ2}': pad(seq, 2),
    '{SEQ3}': pad(seq, 3),
    '{SEQ4}': pad(seq, 4),
  };
  var out = padrao;
  map.forEach((k, v) => out = out.split(k).join(v));
  return out;
}

enum QcResetMode { nunca, diario, mensal, anual }

QcResetMode resetModeFromValue(String? v) => switch (v) {
      'diario' => QcResetMode.diario,
      'mensal' => QcResetMode.mensal,
      'anual' => QcResetMode.anual,
      _ => QcResetMode.nunca,
    };

bool shouldReset(QcResetMode mode, String? last, [DateTime? now]) {
  final n = now ?? DateTime.now();
  if (mode == QcResetMode.nunca) return false;
  if (last == null || last.isEmpty) return true;
  final l = DateTime.tryParse(last);
  if (l == null) return true;
  switch (mode) {
    case QcResetMode.diario:
      return l.year != n.year || l.month != n.month || l.day != n.day;
    case QcResetMode.mensal:
      return l.year != n.year || l.month != n.month;
    case QcResetMode.anual:
      return l.year != n.year;
    case QcResetMode.nunca:
      return false;
  }
}

QcGrupo inferGrupo(int? idadeDias, int? idadeHoras) {
  if (idadeHoras != null && idadeHoras < 24) return QcGrupo.inicial;
  final d = idadeDias ?? 0;
  if (d <= 2) return QcGrupo.inicial;
  if (d <= 14) return QcGrupo.seteDias;
  if (d >= 28) return QcGrupo.vinteOitoDias;
  return QcGrupo.livre;
}

String addDaysIso(String iso, int dias) {
  final d = DateTime.tryParse(iso) ?? DateTime.now();
  final r = DateTime(d.year, d.month, d.day + dias);
  return '${r.year.toString().padLeft(4, '0')}-'
      '${r.month.toString().padLeft(2, '0')}-'
      '${r.day.toString().padLeft(2, '0')}';
}

enum QcStatus { aguardando, aprovado, reprovado }

extension QcStatusX on QcStatus {
  String get value => switch (this) {
        QcStatus.aprovado => 'aprovado',
        QcStatus.reprovado => 'reprovado',
        QcStatus.aguardando => 'aguardando',
      };

  String get label => switch (this) {
        QcStatus.aprovado => 'Aprovado',
        QcStatus.reprovado => 'Reprovado',
        QcStatus.aguardando => 'Aguardando',
      };
}

enum EnsaioSituacao {
  aprovado,
  reprovado,
  aprovadoLiberacao,
  naoLiberado,
  emEvolucao,
  semCriterio,
}

class EnsaioAvaliacao {
  const EnsaioAvaliacao({
    required this.situacao,
    required this.aprovado,
    required this.pctFck,
    required this.label,
    required this.criterioLabel,
  });

  final EnsaioSituacao situacao;
  final bool? aprovado;
  final double pctFck;
  final String label;
  final String criterioLabel;
}

EnsaioAvaliacao evaluateEnsaio({
  required double resistencia,
  int? idadeDias,
  int? idadeHoras,
  QcGrupo? grupo,
  required double fck,
  double? fcj,
}) {
  final g = grupo ?? inferGrupo(idadeDias, idadeHoras);
  final pctFck = fck > 0 ? (resistencia / fck) * 100 : 0.0;

  if (g == QcGrupo.inicial) {
    if (fcj == null || fcj <= 0) {
      return EnsaioAvaliacao(
        situacao: EnsaioSituacao.semCriterio,
        aprovado: null,
        pctFck: pctFck,
        label: 'Sem FCJ',
        criterioLabel: 'FCJ não definido',
      );
    }
    final ok = resistencia >= fcj;
    return EnsaioAvaliacao(
      situacao: ok ? EnsaioSituacao.aprovadoLiberacao : EnsaioSituacao.naoLiberado,
      aprovado: ok,
      pctFck: pctFck,
      label: ok ? 'Aprovado p/ liberação' : 'Não liberado',
      criterioLabel: 'FCJ $fcj MPa',
    );
  }

  if (g == QcGrupo.vinteOitoDias) {
    final ok = resistencia >= fck;
    return EnsaioAvaliacao(
      situacao: ok ? EnsaioSituacao.aprovado : EnsaioSituacao.reprovado,
      aprovado: ok,
      pctFck: pctFck,
      label: ok ? 'Aprovado' : 'Reprovado',
      criterioLabel: 'FCK $fck MPa',
    );
  }

  return EnsaioAvaliacao(
    situacao: EnsaioSituacao.emEvolucao,
    aprovado: null,
    pctFck: pctFck,
    label: 'Em evolução · ${pctFck.toStringAsFixed(0)}%',
    criterioLabel: 'Evolução (FCK $fck MPa)',
  );
}

/// Calcula o status de um lote a partir de CPs e ensaios.
QcStatus computeLoteStatus(
  double fck,
  List<QcEnsaio> ensaios,
  List<QcCorpoProva> cps, {
  double? fcj,
}) {
  final byCp = {for (final c in cps) c.id: c};
  int idade(QcEnsaio e) =>
      e.idadeRealDias ?? byCp[e.corpoProvaId]?.idadeRompimentoDias ?? 0;

  final ensaios28 = ensaios.where((e) {
    final grupo = byCp[e.corpoProvaId]?.grupo;
    if (grupo == '28d') return true;
    if (grupo != null && grupo != 'livre') return false;
    return idade(e) >= 28;
  }).toList();

  if (ensaios28.isNotEmpty) {
    if (ensaios28.every((e) => e.resistenciaMpa >= fck)) return QcStatus.aprovado;
    if (ensaios28.any((e) => e.resistenciaMpa < fck)) return QcStatus.reprovado;
  }

  if (fcj != null && fcj > 0) {
    final iniciais = ensaios.where((e) {
      final cp = byCp[e.corpoProvaId];
      if (cp?.grupo == 'inicial') return true;
      final h = cp?.idadeHoras;
      return (h != null && h < 24) || idade(e) < 3;
    }).toList();
    if (iniciais.isNotEmpty &&
        iniciais.every((e) => e.resistenciaMpa < fcj)) {
      return QcStatus.reprovado;
    }
  }

  return QcStatus.aguardando;
}

String formatIdade(int? idadeDias, int? idadeHoras) {
  if (idadeHoras != null && idadeHoras < 24) return '${idadeHoras}h';
  return '${idadeDias ?? 0}d';
}
