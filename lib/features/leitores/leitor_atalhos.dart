import 'package:flutter/material.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';

/// Atalho para um leitor QRCode.
class LeitorAtalho {
  const LeitorAtalho({
    required this.titulo,
    required this.descricao,
    required this.icone,
    required this.rota,
    required this.pagina,
    required this.cor,
  });

  final String titulo;
  final String descricao;
  final IconData icone;
  final String rota;
  final String pagina;
  final Color cor;
}

/// Leitores disponíveis (espelha os leitores do sistema web).
const List<LeitorAtalho> leitorAtalhos = [
  LeitorAtalho(
    titulo: 'Consulta',
    descricao: 'Consultar peça, lote e posição no mapa',
    icone: Icons.search,
    rota: AppRoutes.leitorConsulta,
    pagina: 'leitor-consulta',
    cor: AppColors.info,
  ),
  LeitorAtalho(
    titulo: 'Armada',
    descricao: 'Marcar peça como armada',
    icone: Icons.construction,
    rota: AppRoutes.leitorArmada,
    pagina: 'leitor-armada',
    cor: AppColors.primary,
  ),
  LeitorAtalho(
    titulo: 'Concretada',
    descricao: 'Marcar peça como concretada',
    icone: Icons.water,
    rota: AppRoutes.leitorConcretada,
    pagina: 'leitor-concretada',
    cor: AppColors.accent,
  ),
  LeitorAtalho(
    titulo: 'Estoque',
    descricao: 'Vincular peça a um estoque',
    icone: Icons.warehouse_outlined,
    rota: AppRoutes.leitorEstoque,
    pagina: 'leitor-estoque',
    cor: AppColors.success,
  ),
  LeitorAtalho(
    titulo: 'Montagem',
    descricao: 'Marcar peça como montada',
    icone: Icons.handyman_outlined,
    rota: AppRoutes.leitorMontagem,
    pagina: 'leitor-montagem',
    cor: AppColors.warning,
  ),
];
