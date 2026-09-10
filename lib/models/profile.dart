/// Perfil do usuário (tabela `profiles`).
class Profile {
  const Profile({
    required this.id,
    required this.userId,
    this.nome,
    this.email,
    this.telefone,
    this.fotoUrl,
    this.ativo = true,
    this.organizacaoId,
  });

  final String id;
  final String userId;
  final String? nome;
  final String? email;
  final String? telefone;
  final String? fotoUrl;
  final bool ativo;
  final String? organizacaoId;

  String get displayName =>
      (nome != null && nome!.trim().isNotEmpty) ? nome! : (email ?? 'Usuário');

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      nome: map['nome'] as String?,
      email: map['email'] as String?,
      telefone: map['telefone'] as String?,
      fotoUrl: map['foto_url'] as String?,
      ativo: (map['ativo'] as bool?) ?? true,
      organizacaoId: map['organizacao_id'] as String?,
    );
  }
}
