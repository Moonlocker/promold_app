/// Cliente (tabela `clientes`).
class Cliente {
  const Cliente({
    required this.id,
    required this.nome,
    this.tipoPessoa = 'PJ',
    this.cpfCnpj,
    this.inscricaoEstadual,
    this.inscricaoMunicipal,
    this.email,
    this.telefone,
    this.whatsapp,
    this.cep,
    this.logradouro,
    this.numero,
    this.complemento,
    this.bairro,
    this.cidade,
    this.uf,
    this.contatoPrincipal,
    this.observacoes,
    this.ativo = true,
  });

  final String id;
  final String nome;
  final String tipoPessoa;
  final String? cpfCnpj;
  final String? inscricaoEstadual;
  final String? inscricaoMunicipal;
  final String? email;
  final String? telefone;
  final String? whatsapp;
  final String? cep;
  final String? logradouro;
  final String? numero;
  final String? complemento;
  final String? bairro;
  final String? cidade;
  final String? uf;
  final String? contatoPrincipal;
  final String? observacoes;
  final bool ativo;

  bool get isPessoaFisica => tipoPessoa.toUpperCase() == 'PF';

  String get enderecoCompleto {
    final partes = [
      logradouro,
      numero,
      complemento,
      bairro,
      cidade,
      uf,
    ].where((e) => e != null && e.trim().isNotEmpty).toList();
    return partes.join(', ');
  }

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'] as String,
      nome: (map['nome'] as String?) ?? 'Cliente',
      tipoPessoa: (map['tipo_pessoa'] as String?) ?? 'PJ',
      cpfCnpj: map['cpf_cnpj'] as String?,
      inscricaoEstadual: map['inscricao_estadual'] as String?,
      inscricaoMunicipal: map['inscricao_municipal'] as String?,
      email: map['email'] as String?,
      telefone: map['telefone'] as String?,
      whatsapp: map['whatsapp'] as String?,
      cep: map['cep'] as String?,
      logradouro: map['logradouro'] as String?,
      numero: map['numero'] as String?,
      complemento: map['complemento'] as String?,
      bairro: map['bairro'] as String?,
      cidade: map['cidade'] as String?,
      uf: map['uf'] as String?,
      contatoPrincipal: map['contato_principal'] as String?,
      observacoes: map['observacoes'] as String?,
      ativo: (map['ativo'] as bool?) ?? true,
    );
  }
}
