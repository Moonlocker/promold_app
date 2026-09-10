import 'package:flutter/material.dart';

import 'app_routes.dart';

/// Módulo navegável do aplicativo.
///
/// [pagina] é o slug de permissão usado pelo RPC `user_paginas_visiveis`
/// (o mesmo do webapp). Se for `null`, o módulo não tem restrição de página.
class AppModule {
  const AppModule({
    required this.label,
    required this.route,
    required this.icon,
    required this.group,
    this.pagina,
  });

  final String label;
  final String route;
  final IconData icon;
  final String group;
  final String? pagina;
}

/// Catálogo de módulos exibidos na aba "Mais" e usados para montar as rotas.
///
/// A ordem e a nomenclatura espelham o Sidebar do sistema web
/// (`src/components/layout/Sidebar.tsx`).
const List<AppModule> appModules = [
  // Operacional
  AppModule(
    label: 'Dashboard',
    route: AppRoutes.dashboard,
    icon: Icons.dashboard_outlined,
    group: 'Operacional',
    pagina: 'dashboard',
  ),
  AppModule(
    label: 'Obras',
    route: AppRoutes.obras,
    icon: Icons.business_outlined,
    group: 'Operacional',
    pagina: 'obras',
  ),
  AppModule(
    label: 'Indicadores',
    route: AppRoutes.producao,
    icon: Icons.bar_chart_outlined,
    group: 'Operacional',
    pagina: 'indicadores',
  ),
  AppModule(
    label: 'Painel Fábrica',
    route: AppRoutes.painel,
    icon: Icons.factory_outlined,
    group: 'Operacional',
    pagina: 'painel-fabrica',
  ),
  AppModule(
    label: 'Planejamento',
    route: AppRoutes.planejamento,
    icon: Icons.calendar_month_outlined,
    group: 'Operacional',
    pagina: 'planejamento',
  ),
  AppModule(
    label: 'Catálogo de Peças',
    route: AppRoutes.pecas,
    icon: Icons.extension_outlined,
    group: 'Operacional',
    pagina: 'pecas',
  ),
  AppModule(
    label: 'Status Geral',
    route: AppRoutes.visaoGeral,
    icon: Icons.visibility_outlined,
    group: 'Operacional',
    pagina: 'visao-geral',
  ),
  AppModule(
    label: 'Estoque',
    route: AppRoutes.estoque,
    icon: Icons.inventory_2_outlined,
    group: 'Operacional',
    pagina: 'estoque',
  ),

  // Comercial
  AppModule(
    label: 'Orçamentos',
    route: AppRoutes.orcamentos,
    icon: Icons.request_quote_outlined,
    group: 'Comercial',
    pagina: 'orcamentos',
  ),

  // Logística
  AppModule(
    label: 'Frota',
    route: AppRoutes.frota,
    icon: Icons.local_shipping_outlined,
    group: 'Logística',
    pagina: 'frota',
  ),

  // Leitores QRCode
  AppModule(
    label: 'Leitor Consulta',
    route: AppRoutes.leitorConsulta,
    icon: Icons.qr_code_scanner,
    group: 'Leitor QRCode',
    pagina: 'leitor-consulta',
  ),
  AppModule(
    label: 'Leitor Armada',
    route: AppRoutes.leitorArmada,
    icon: Icons.qr_code_scanner,
    group: 'Leitor QRCode',
    pagina: 'leitor-armada',
  ),
  AppModule(
    label: 'Leitor Concretada',
    route: AppRoutes.leitorConcretada,
    icon: Icons.qr_code_scanner,
    group: 'Leitor QRCode',
    pagina: 'leitor-concretada',
  ),
  AppModule(
    label: 'Leitor Estoque',
    route: AppRoutes.leitorEstoque,
    icon: Icons.qr_code_scanner,
    group: 'Leitor QRCode',
    pagina: 'leitor-estoque',
  ),
  AppModule(
    label: 'Leitor Montagem',
    route: AppRoutes.leitorMontagem,
    icon: Icons.qr_code_scanner,
    group: 'Leitor QRCode',
    pagina: 'leitor-montagem',
  ),

  // Qualidade
  AppModule(
    label: 'Qualidade',
    route: AppRoutes.qualidadeDashboard,
    icon: Icons.science_outlined,
    group: 'Qualidade',
    pagina: 'qualidade-dashboard',
  ),
  AppModule(
    label: 'Lotes & Ensaios',
    route: AppRoutes.qualidadeEnsaios,
    icon: Icons.biotech_outlined,
    group: 'Qualidade',
    pagina: 'qualidade-ensaios',
  ),
  AppModule(
    label: 'Rastreabilidade',
    route: AppRoutes.qualidadeRastreabilidade,
    icon: Icons.track_changes_outlined,
    group: 'Qualidade',
    pagina: 'qualidade-rastreabilidade',
  ),

  // Financeiro
  AppModule(
    label: 'Dashboard Financeiro',
    route: AppRoutes.financeiroDashboard,
    icon: Icons.trending_up,
    group: 'Financeiro',
    pagina: 'financeiro-dashboard',
  ),
  AppModule(
    label: 'Contas a Pagar',
    route: AppRoutes.financeiroContasPagar,
    icon: Icons.credit_card_outlined,
    group: 'Financeiro',
    pagina: 'financeiro-contas-pagar',
  ),
  AppModule(
    label: 'Contas a Receber',
    route: AppRoutes.financeiroContasReceber,
    icon: Icons.receipt_long_outlined,
    group: 'Financeiro',
    pagina: 'financeiro-contas-receber',
  ),
  AppModule(
    label: 'Conciliação',
    route: AppRoutes.financeiroConciliacao,
    icon: Icons.account_balance_outlined,
    group: 'Financeiro',
    pagina: 'financeiro-conciliacao',
  ),
  AppModule(
    label: 'Integrações',
    route: AppRoutes.financeiroIntegracoes,
    icon: Icons.bolt_outlined,
    group: 'Financeiro',
    pagina: 'financeiro-integracoes',
  ),
  AppModule(
    label: 'Centros de Custo',
    route: AppRoutes.financeiroCentrosCusto,
    icon: Icons.flag_outlined,
    group: 'Financeiro',
    pagina: 'financeiro-centros-custo',
  ),
  AppModule(
    label: 'Categorias',
    route: AppRoutes.financeiroCategorias,
    icon: Icons.sell_outlined,
    group: 'Financeiro',
    pagina: 'financeiro-categorias',
  ),

  // Fiscal
  AppModule(
    label: 'Emitir Nota',
    route: AppRoutes.fiscalEmitir,
    icon: Icons.note_add_outlined,
    group: 'Fiscal',
    pagina: 'fiscal-emitir',
  ),
  AppModule(
    label: 'Notas Emitidas',
    route: AppRoutes.fiscalNotas,
    icon: Icons.description_outlined,
    group: 'Fiscal',
    pagina: 'fiscal-notas',
  ),
  AppModule(
    label: 'Notas Recebidas',
    route: AppRoutes.fiscalRecebidas,
    icon: Icons.move_to_inbox_outlined,
    group: 'Fiscal',
    pagina: 'fiscal-recebidas',
  ),
  AppModule(
    label: 'Configuração Fiscal',
    route: AppRoutes.fiscalConfiguracao,
    icon: Icons.settings_suggest_outlined,
    group: 'Fiscal',
    pagina: 'fiscal-configuracao',
  ),

  // Cadastros
  AppModule(
    label: 'Clientes',
    route: AppRoutes.clientes,
    icon: Icons.person_outline,
    group: 'Cadastros',
    pagina: 'clientes',
  ),
  AppModule(
    label: 'Fornecedores',
    route: AppRoutes.fornecedores,
    icon: Icons.store_outlined,
    group: 'Cadastros',
    pagina: 'fornecedores',
  ),
  AppModule(
    label: 'Equipe',
    route: AppRoutes.equipe,
    icon: Icons.groups_outlined,
    group: 'Cadastros',
    pagina: 'equipe',
  ),

  // Sistema
  AppModule(
    label: 'Configurações',
    route: AppRoutes.configuracoes,
    icon: Icons.settings_outlined,
    group: 'Sistema',
    pagina: 'configuracoes',
  ),
  AppModule(
    label: 'Minha Fatura',
    route: AppRoutes.minhaFatura,
    icon: Icons.receipt_outlined,
    group: 'Sistema',
  ),
  AppModule(
    label: 'Suporte',
    route: AppRoutes.suporte,
    icon: Icons.support_agent_outlined,
    group: 'Sistema',
  ),
];
