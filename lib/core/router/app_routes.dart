/// Definição das rotas nomeadas do aplicativo.
class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const onboarding = '/onboarding';
  static const contaBloqueada = '/conta-bloqueada';
  static const dashboard = '/dashboard';
  static const obras = '/obras';
  static String obraDetalhe(String id) => '/obras/$id';
  static const producao = '/producao';
  static const estoque = '/estoque';
  static const mais = '/mais';

  // Demais módulos (navegáveis pela tela "Mais").
  static const painel = '/painel';
  static const planejamento = '/planejamento';
  static const pecas = '/pecas';
  static const visaoGeral = '/visao-geral';
  static const orcamentos = '/orcamentos';
  static const frota = '/frota';
  static const fornecedores = '/fornecedores';
  static const equipe = '/equipe';
  static const clientes = '/clientes';
  static const configuracoes = '/configuracoes';
  static const minhaFatura = '/minha-fatura';
  static const suporte = '/suporte';
  static const superAdmin = '/super-admin';

  static const leitorConsulta = '/leitor-consulta';
  static const leitorArmada = '/leitor-armada';
  static const leitorConcretada = '/leitor-concretada';
  static const leitorEstoque = '/leitor-estoque';
  static const leitorMontagem = '/leitor-montagem';

  static const qualidadeDashboard = '/qualidade/dashboard';
  static const qualidadeEnsaios = '/qualidade/ensaios';
  static const qualidadeRastreabilidade = '/qualidade/rastreabilidade';

  static const financeiroDashboard = '/financeiro/dashboard';
  static const financeiroContasPagar = '/financeiro/contas-pagar';
  static const financeiroContasReceber = '/financeiro/contas-receber';
  static const financeiroConciliacao = '/financeiro/conciliacao';
  static const financeiroIntegracoes = '/financeiro/integracoes';
  static const financeiroCentrosCusto = '/financeiro/centros-custo';
  static const financeiroCategorias = '/financeiro/categorias';

  static const fiscalEmitir = '/fiscal/emitir';
  static const fiscalNotas = '/fiscal/notas';
  static const fiscalRecebidas = '/fiscal/recebidas';
  static const fiscalConfiguracao = '/fiscal/configuracao';
}
