import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_providers.dart';
import 'leitor_atalhos.dart';

/// Acesso rápido aos leitores QRCode — a ferramenta de campo mais usada.
class LeitoresHubScreen extends ConsumerWidget {
  const LeitoresHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).value;
    final itens = leitorAtalhos
        .where((l) => user?.podeAcessarPagina(l.pagina) ?? true)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Leitores QR')),
      body: itens.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum leitor liberado para o seu perfil.',
                  style: TextStyle(color: AppColors.mutedForeground),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Escolha o leitor para registrar a intervenção',
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 12),
                for (final l in itens) ...[
                  LeitorCard(item: l, onTap: () => context.push(l.rota)),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

/// Cartão de um leitor, reutilizado no hub e no atalho flutuante.
class LeitorCard extends StatelessWidget {
  const LeitorCard({super.key, required this.item, required this.onTap});

  final LeitorAtalho item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: item.cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icone, color: item.cor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.titulo,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(item.descricao,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.mutedForeground)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}
