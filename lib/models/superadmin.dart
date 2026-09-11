/// Modelos do painel SuperAdmin (plataforma).
library;

class SaudeOrg {
  const SaudeOrg({
    required this.organizacaoId,
    required this.nome,
    this.ativo = true,
    this.m3Ultimos30 = 0,
    this.obrasAtivas = 0,
    this.totalUsuarios = 0,
    this.usuariosAtivos30 = 0,
    this.faturasAtrasadas = 0,
    this.diasSemProducao = 0,
    this.healthScore = 0,
    this.trialFim,
  });

  final String organizacaoId;
  final String nome;
  final bool ativo;
  final double m3Ultimos30;
  final int obrasAtivas;
  final int totalUsuarios;
  final int usuariosAtivos30;
  final int faturasAtrasadas;
  final int diasSemProducao;
  final int healthScore;
  final String? trialFim;

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory SaudeOrg.fromMap(Map<String, dynamic> m) => SaudeOrg(
        organizacaoId: (m['organizacao_id'] as String?) ?? '',
        nome: (m['nome'] as String?) ?? 'Organização',
        ativo: (m['ativo'] as bool?) ?? true,
        m3Ultimos30: _d(m['m3_30d']),
        obrasAtivas: _i(m['obras_ativas']),
        totalUsuarios: _i(m['total_usuarios']),
        usuariosAtivos30: _i(m['usuarios_ativos_30d']),
        faturasAtrasadas: _i(m['faturas_atrasadas']),
        diasSemProducao: _i(m['dias_sem_producao']),
        healthScore: _i(m['health_score']),
        trialFim: m['trial_fim'] as String?,
      );
}

class AuditLogSuper {
  const AuditLogSuper({
    required this.id,
    required this.acao,
    this.alvoTipo,
    this.alvoDescricao,
    this.atorEmail,
    this.createdAt,
  });

  final String id;
  final String acao;
  final String? alvoTipo;
  final String? alvoDescricao;
  final String? atorEmail;
  final String? createdAt;

  factory AuditLogSuper.fromMap(Map<String, dynamic> m) => AuditLogSuper(
        id: m['id'] as String,
        acao: (m['acao'] as String?) ?? '',
        alvoTipo: m['alvo_tipo'] as String?,
        alvoDescricao: m['alvo_descricao'] as String?,
        atorEmail: m['ator_email'] as String?,
        createdAt: m['created_at'] as String?,
      );
}
