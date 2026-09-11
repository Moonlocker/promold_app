/// Modelos de permissões e perfis de acesso (Configurações → Permissões).
library;

/// Direitos granulares de uma página para o usuário atual.
class PermissaoPagina {
  const PermissaoPagina({
    this.podeVisualizar = true,
    this.podeCriar = true,
    this.podeEditar = true,
    this.podeExcluir = true,
  });

  final bool podeVisualizar;
  final bool podeCriar;
  final bool podeEditar;
  final bool podeExcluir;

  factory PermissaoPagina.fromMap(Map<String, dynamic> m) => PermissaoPagina(
        podeVisualizar: (m['pode_visualizar'] as bool?) ?? true,
        podeCriar: (m['pode_criar'] as bool?) ?? true,
        podeEditar: (m['pode_editar'] as bool?) ?? true,
        podeExcluir: (m['pode_excluir'] as bool?) ?? true,
      );
}

class Permissao {
  const Permissao({
    required this.id,
    required this.role,
    required this.pagina,
    this.podeVisualizar = false,
    this.podeCriar = false,
    this.podeEditar = false,
    this.podeExcluir = false,
  });

  final String id;
  final String role;
  final String pagina;
  final bool podeVisualizar;
  final bool podeCriar;
  final bool podeEditar;
  final bool podeExcluir;

  bool value(String campo) => switch (campo) {
        'pode_visualizar' => podeVisualizar,
        'pode_criar' => podeCriar,
        'pode_editar' => podeEditar,
        'pode_excluir' => podeExcluir,
        _ => false,
      };

  Permissao copyWith({
    bool? podeVisualizar,
    bool? podeCriar,
    bool? podeEditar,
    bool? podeExcluir,
  }) {
    return Permissao(
      id: id,
      role: role,
      pagina: pagina,
      podeVisualizar: podeVisualizar ?? this.podeVisualizar,
      podeCriar: podeCriar ?? this.podeCriar,
      podeEditar: podeEditar ?? this.podeEditar,
      podeExcluir: podeExcluir ?? this.podeExcluir,
    );
  }

  factory Permissao.fromMap(Map<String, dynamic> m) => Permissao(
        id: m['id'] as String,
        role: (m['role'] as String?) ?? '',
        pagina: (m['pagina'] as String?) ?? '',
        podeVisualizar: (m['pode_visualizar'] as bool?) ?? false,
        podeCriar: (m['pode_criar'] as bool?) ?? false,
        podeEditar: (m['pode_editar'] as bool?) ?? false,
        podeExcluir: (m['pode_excluir'] as bool?) ?? false,
      );
}

class PerfilAcesso {
  const PerfilAcesso({
    required this.id,
    required this.nome,
    required this.slug,
    this.descricao,
    this.isSistema = false,
  });

  final String id;
  final String nome;
  final String slug;
  final String? descricao;
  final bool isSistema;

  factory PerfilAcesso.fromMap(Map<String, dynamic> m) => PerfilAcesso(
        id: m['id'] as String,
        nome: (m['nome'] as String?) ?? '',
        slug: (m['slug'] as String?) ?? '',
        descricao: m['descricao'] as String?,
        isSistema: (m['is_sistema'] as bool?) ?? false,
      );
}

/// Páginas do sistema (mesma lista do webapp `ALL_PAGES`).
const List<String> allPages = [
  'dashboard',
  'obras',
  'indicadores',
  'painel-fabrica',
  'planejamento',
  'pecas',
  'visao-geral',
  'estoque',
  'orcamentos',
  'leitor-consulta',
  'leitor-armada',
  'leitor-concretada',
  'leitor-estoque',
  'leitor-montagem',
  'qualidade-dashboard',
  'qualidade-ensaios',
  'qualidade-rastreabilidade',
  'financeiro-dashboard',
  'financeiro-contas-pagar',
  'financeiro-contas-receber',
  'financeiro-conciliacao',
  'financeiro-integracoes',
  'fiscal-emitir',
  'fiscal-notas',
  'fiscal-recebidas',
  'fiscal-configuracao',
  'clientes',
  'fornecedores',
  'equipe',
  'frota',
  'financeiro-centros-custo',
  'financeiro-categorias',
  'configuracoes',
];

const Map<String, String> paginaLabels = {
  'dashboard': 'Dashboard',
  'obras': 'Obras',
  'indicadores': 'Indicadores',
  'painel-fabrica': 'Painel Fábrica',
  'planejamento': 'Planejamento',
  'pecas': 'Catálogo de Peças',
  'visao-geral': 'Status Geral',
  'estoque': 'Estoque',
  'orcamentos': 'Orçamentos',
  'leitor-consulta': 'Leitor Consulta',
  'leitor-armada': 'Leitor Armada',
  'leitor-concretada': 'Leitor Concretada',
  'leitor-estoque': 'Leitor Estoque',
  'leitor-montagem': 'Leitor Montagem',
  'qualidade-dashboard': 'Qualidade · Dashboard',
  'qualidade-ensaios': 'Qualidade · Lotes & Ensaios',
  'qualidade-rastreabilidade': 'Qualidade · Rastreabilidade',
  'financeiro-dashboard': 'Financeiro · Dashboard',
  'financeiro-contas-pagar': 'Financeiro · Contas a Pagar',
  'financeiro-contas-receber': 'Financeiro · Contas a Receber',
  'financeiro-conciliacao': 'Financeiro · Conciliação',
  'financeiro-integracoes': 'Financeiro · Integrações',
  'fiscal-emitir': 'Fiscal · Emitir Nota',
  'fiscal-notas': 'Fiscal · Notas Emitidas',
  'fiscal-recebidas': 'Fiscal · Notas Recebidas',
  'fiscal-configuracao': 'Fiscal · Configuração',
  'clientes': 'Clientes',
  'fornecedores': 'Fornecedores',
  'equipe': 'Equipe',
  'frota': 'Frota',
  'financeiro-centros-custo': 'Centros de Custo',
  'financeiro-categorias': 'Categorias',
  'configuracoes': 'Configurações',
};

String paginaLabel(String pagina) => paginaLabels[pagina] ?? pagina;
