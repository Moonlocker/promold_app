import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/simple_form_sheet.dart';
import '../../../models/veiculo.dart';
import '../../../providers/sistema_providers.dart';
import '../../../providers/supabase_providers.dart';

/// MÃ³dulo Frota: cadastro de veÃ­culos.
class FrotaScreen extends ConsumerStatefulWidget {
  const FrotaScreen({super.key});

  @override
  ConsumerState<FrotaScreen> createState() => _FrotaScreenState();
}

class _FrotaScreenState extends ConsumerState<FrotaScreen> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(veiculosListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Frota')),
      floatingActionButton: ref.podeCriar('frota')
          ? FloatingActionButton.extended(
              onPressed: () => _abrirForm(),
              icon: const Icon(Icons.add),
              label: const Text('Novo VeÃ­culo'),
            )
          : null,
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (veiculos) {
          final filtrados = veiculos.where((v) {
            final s = _busca.toLowerCase();
            return v.placa.toLowerCase().contains(s) ||
                v.modelo.toLowerCase().contains(s);
          }).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(veiculosListProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Buscar por placa ou modelo...',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                if (filtrados.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.local_shipping_outlined,
                      title: 'Nenhum veÃ­culo cadastrado',
                    ),
                  )
                else
                  ...filtrados.map((v) => _VeiculoCard(
                        veiculo: v,
                        onChanged: () => ref.invalidate(veiculosListProvider),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _abrirForm({Veiculo? veiculo}) async {
    final result = await showSimpleFormSheet(
      context,
      title: veiculo == null ? 'Novo VeÃ­culo' : 'Editar VeÃ­culo',
      submitLabel: veiculo == null ? 'Cadastrar' : 'Salvar',
      fields: [
        SimpleField(
            key: 'placa',
            label: 'Placa *',
            initial: veiculo?.placa,
            required: true,
            uppercase: true),
        SimpleField(
            key: 'modelo',
            label: 'Modelo *',
            initial: veiculo?.modelo,
            required: true),
        SimpleField(
          key: 'tipo',
          label: 'Tipo',
          initial: veiculo?.tipo ?? 'caminhao',
          options: const [
            SimpleOption('caminhao', 'CaminhÃ£o'),
            SimpleOption('carreta', 'Carreta'),
            SimpleOption('munck', 'Munck'),
            SimpleOption('carro', 'Carro'),
            SimpleOption('outro', 'Outro'),
          ],
        ),
        SimpleField(
          key: 'propriedade',
          label: 'Propriedade',
          initial: veiculo?.propriedade ?? 'propria',
          options: const [
            SimpleOption('propria', 'PrÃ³pria'),
            SimpleOption('terceirizada', 'Terceirizada'),
            SimpleOption('agregada', 'Agregada'),
          ],
        ),
        SimpleField(
            key: 'capacidade',
            label: 'Capacidade (t)',
            initial: veiculo?.capacidade?.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
      ],
    );
    if (result == null) return;
    final repo = ref.read(sistemaRepositoryProvider);
    final payload = <String, dynamic>{
      'placa': result['placa'],
      'modelo': result['modelo'],
      'tipo': result['tipo'],
      'propriedade': result['propriedade'],
      'capacidade':
          double.tryParse((result['capacidade'] ?? '').replaceAll(',', '.')),
    };
    if (veiculo == null) {
      await repo.createVeiculo({...payload, 'ativo': true});
    } else {
      await repo.updateVeiculo(veiculo.id, payload);
    }
    ref.invalidate(veiculosListProvider);
  }
}

class _VeiculoCard extends ConsumerWidget {
  const _VeiculoCard({required this.veiculo, required this.onChanged});

  final Veiculo veiculo;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: ref.podeEditar('frota')
            ? () async {
                await _editar(context, ref);
              }
            : null,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.local_shipping_outlined,
              size: 18, color: AppColors.primary),
        ),
        title: Text('${veiculo.placa} Â· ${veiculo.modelo}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${veiculo.tipo ?? '-'} Â· ${veiculo.propriedade}'
          '${veiculo.capacidade != null ? ' Â· ${veiculo.capacidade}t' : ''}',
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: (ref.podeEditar('frota') || ref.podeExcluir('frota'))
            ? PopupMenuButton<String>(
          onSelected: (v) async {
            final repo = ref.read(sistemaRepositoryProvider);
            switch (v) {
              case 'editar':
                await _editar(context, ref);
              case 'toggle':
                await repo.updateVeiculo(veiculo.id, {'ativo': !veiculo.ativo});
                onChanged();
              case 'excluir':
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Excluir veÃ­culo'),
                    content: Text('Excluir ${veiculo.placa}?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.destructive),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Excluir'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await repo.deleteVeiculo(veiculo.id);
                  onChanged();
                }
            }
          },
          itemBuilder: (_) => [
            if (ref.podeEditar('frota'))
              const PopupMenuItem(value: 'editar', child: Text('Editar')),
            if (ref.podeEditar('frota'))
              PopupMenuItem(
                value: 'toggle',
                child: Text(veiculo.ativo ? 'Desativar' : 'Ativar'),
              ),
            if (ref.podeExcluir('frota'))
              const PopupMenuItem(
                  value: 'excluir',
                  child: Text('Excluir',
                      style: TextStyle(color: AppColors.destructive))),
          ],
        )
            : null,
      ),
    );
  }

  Future<void> _editar(BuildContext context, WidgetRef ref) async {
    final result = await showSimpleFormSheet(
      context,
      title: 'Editar VeÃ­culo',
      fields: [
        SimpleField(key: 'placa', label: 'Placa *', initial: veiculo.placa, required: true),
        SimpleField(key: 'modelo', label: 'Modelo *', initial: veiculo.modelo, required: true),
        SimpleField(
          key: 'tipo',
          label: 'Tipo',
          initial: veiculo.tipo ?? 'caminhao',
          options: const [
            SimpleOption('caminhao', 'CaminhÃ£o'),
            SimpleOption('carreta', 'Carreta'),
            SimpleOption('munck', 'Munck'),
            SimpleOption('carro', 'Carro'),
            SimpleOption('outro', 'Outro'),
          ],
        ),
        SimpleField(
          key: 'propriedade',
          label: 'Propriedade',
          initial: veiculo.propriedade,
          options: const [
            SimpleOption('propria', 'PrÃ³pria'),
            SimpleOption('terceirizada', 'Terceirizada'),
            SimpleOption('agregada', 'Agregada'),
          ],
        ),
        SimpleField(
            key: 'capacidade',
            label: 'Capacidade (t)',
            initial: veiculo.capacidade?.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
      ],
    );
    if (result == null) return;
    await ref.read(sistemaRepositoryProvider).updateVeiculo(veiculo.id, {
      'placa': result['placa'],
      'modelo': result['modelo'],
      'tipo': result['tipo'],
      'propriedade': result['propriedade'],
      'capacidade':
          double.tryParse((result['capacidade'] ?? '').replaceAll(',', '.')),
    });
    onChanged();
  }
}
