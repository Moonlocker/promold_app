/// Fornecedor (tabela `fornecedores`).
class Fornecedor {
  const Fornecedor({
    required this.id,
    required this.razaoSocial,
    this.nomeFantasia,
    this.tipoPessoa = 'pj',
    this.cnpjCpf,
    this.telefone1,
    this.telefone2,
    this.email,
    this.responsavel,
    this.cep,
    this.endereco,
    this.cidade,
    this.estado,
    this.observacoes,
    this.ativo = true,
  });

  final String id;
  final String razaoSocial;
  final String? nomeFantasia;
  final String tipoPessoa;
  final String? cnpjCpf;
  final String? telefone1;
  final String? telefone2;
  final String? email;
  final String? responsavel;
  final String? cep;
  final String? endereco;
  final String? cidade;
  final String? estado;
  final String? observacoes;
  final bool ativo;

  bool get isPessoaFisica => tipoPessoa.toLowerCase() == 'pf';

  factory Fornecedor.fromMap(Map<String, dynamic> map) {
    return Fornecedor(
      id: map['id'] as String,
      razaoSocial: (map['razao_social'] as String?) ?? 'Fornecedor',
      nomeFantasia: map['nome_fantasia'] as String?,
      tipoPessoa: (map['tipo_pessoa'] as String?) ?? 'pj',
      cnpjCpf: map['cnpj_cpf'] as String?,
      telefone1: map['telefone1'] as String?,
      telefone2: map['telefone2'] as String?,
      email: map['email'] as String?,
      responsavel: map['responsavel'] as String?,
      cep: map['cep'] as String?,
      endereco: map['endereco'] as String?,
      cidade: map['cidade'] as String?,
      estado: map['estado'] as String?,
      observacoes: map['observacoes'] as String?,
      ativo: (map['ativo'] as bool?) ?? true,
    );
  }
}
