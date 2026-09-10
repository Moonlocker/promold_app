/// Organização (empresa) do usuário (tabela `organizacoes`).
///
/// Cada organização é isolada por RLS no Supabase, exatamente como no webapp.
class Organizacao {
  const Organizacao({
    required this.id,
    required this.nome,
    this.slug,
    this.cnpj,
    this.email,
    this.telefone,
    this.logoUrl,
    this.plano,
    this.ativo = true,
    this.dataExpiracao,
    this.maxUsuarios,
    this.bloqueioMotivo,
    this.bloqueioTipo,
  });

  final String id;
  final String nome;
  final String? slug;
  final String? cnpj;
  final String? email;
  final String? telefone;
  final String? logoUrl;
  final String? plano;
  final bool ativo;
  final DateTime? dataExpiracao;
  final int? maxUsuarios;
  final String? bloqueioMotivo;
  final String? bloqueioTipo;

  factory Organizacao.fromMap(Map<String, dynamic> map) {
    return Organizacao(
      id: map['id'] as String,
      nome: (map['nome'] as String?) ?? 'Organização',
      slug: map['slug'] as String?,
      cnpj: map['cnpj'] as String?,
      email: map['email'] as String?,
      telefone: map['telefone'] as String?,
      logoUrl: map['logo_url'] as String?,
      plano: map['plano'] as String?,
      ativo: (map['ativo'] as bool?) ?? true,
      dataExpiracao: map['data_expiracao'] != null
          ? DateTime.tryParse(map['data_expiracao'] as String)
          : null,
      maxUsuarios: map['max_usuarios'] as int?,
      bloqueioMotivo: map['bloqueio_motivo'] as String?,
      bloqueioTipo: map['bloqueio_tipo'] as String?,
    );
  }
}
