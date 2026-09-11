/// Funcionário (tabela `funcionarios`).
class Funcionario {
  const Funcionario({
    required this.id,
    required this.nome,
    this.cargoId,
    this.setorId,
    this.salario,
    this.telefone,
    this.email,
    this.ativo = true,
    this.fotoUrl,
    this.dataAdmissao,
    this.cargoNome,
    this.setorNome,
  });

  final String id;
  final String nome;
  final String? cargoId;
  final String? setorId;
  final num? salario;
  final String? telefone;
  final String? email;
  final bool ativo;
  final String? fotoUrl;
  final String? dataAdmissao;
  final String? cargoNome;
  final String? setorNome;

  String get iniciais {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first.substring(0, 1) + partes.last.substring(0, 1))
        .toUpperCase();
  }

  factory Funcionario.fromMap(Map<String, dynamic> map) {
    String? nomeRel(dynamic rel) {
      if (rel is Map && rel['nome'] is String) return rel['nome'] as String;
      return null;
    }

    return Funcionario(
      id: map['id'] as String,
      nome: (map['nome'] as String?) ?? 'Funcionário',
      cargoId: map['cargo_id'] as String?,
      setorId: map['setor_id'] as String?,
      salario: map['salario'] as num?,
      telefone: map['telefone'] as String?,
      email: map['email'] as String?,
      ativo: (map['ativo'] as bool?) ?? true,
      fotoUrl: map['foto_url'] as String?,
      dataAdmissao: map['data_admissao'] as String?,
      cargoNome: nomeRel(map['cargos']),
      setorNome: nomeRel(map['setores']),
    );
  }
}
