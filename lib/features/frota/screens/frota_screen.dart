import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/auth_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/simple_form_sheet.dart';
import '../../../models/veiculo.dart';
import '../../../providers/equipe_providers.dart';
import '../../../providers/sistema_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Módulo Frota: cadastro de veículos.
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
              label: const Text('Novo Veículo'),
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
                      title: 'Nenhum veículo cadastrado',
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
    final funcionarios =
        ref.read(funcionariosListProvider).value ?? const [];
    final result = await showSimpleFormSheet(
      context,
      title: veiculo == null ? 'Novo Veículo' : 'Editar Veículo',
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
            SimpleOption('caminhao', 'Caminhão'),
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
            SimpleOption('propria', 'Própria'),
            SimpleOption('terceirizada', 'Terceirizada'),
            SimpleOption('agregada', 'Agregada'),
          ],
        ),
        SimpleField(
            key: 'capacidade',
            label: 'Capacidade (t)',
            initial: veiculo?.capacidade?.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        SimpleField(
          key: 'motorista_padrao_id',
          label: 'Motorista padrão',
          initial: veiculo?.motoristaPadraoId ?? '',
          options: [
            const SimpleOption('', '— Nenhum —'),
            for (final f in funcionarios) SimpleOption(f.id, f.nome),
          ],
        ),
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
      'motorista_padrao_id': (result['motorista_padrao_id'] ?? '').isEmpty
          ? null
          : result['motorista_padrao_id'],
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
    final funcs = ref.watch(funcionariosListProvider).value ?? const [];
    final motoristaNome = funcs
        .where((f) => f.id == veiculo.motoristaPadraoId)
        .firstOrNull
        ?.nome;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: ref.podeEditar('frota')
            ? () async {
                await _editar(context, ref);
              }
            : null,
        leading: veiculo.fotoUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  veiculo.fotoUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _avatarIcone(),
                ),
              )
            : _avatarIcone(),
        title: Text('${veiculo.placa} · ${veiculo.modelo}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${veiculo.tipo ?? '-'} · ${veiculo.propriedade}'
          '${veiculo.capacidade != null ? ' · ${veiculo.capacidade}t' : ''}'
          '${motoristaNome != null ? '\nMotorista: $motoristaNome' : ''}',
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: (ref.podeEditar('frota') || ref.podeExcluir('frota'))
            ? PopupMenuButton<String>(
          onSelected: (v) async {
            final repo = ref.read(sistemaRepositoryProvider);
            switch (v) {
              case 'editar':
                await _editar(context, ref);
              case 'foto':
                await _alterarFoto(context, ref);
              case 'toggle':
                await repo.updateVeiculo(veiculo.id, {'ativo': !veiculo.ativo});
                onChanged();
              case 'excluir':
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Excluir veículo'),
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
              const PopupMenuItem(value: 'foto', child: Text('Alterar foto')),
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

  Widget _avatarIcone() => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.local_shipping_outlined,
            size: 18, color: AppColors.primary),
      );

  Future<void> _editar(BuildContext context, WidgetRef ref) async {
    final funcionarios =
        ref.read(funcionariosListProvider).value ?? const [];
    final result = await showSimpleFormSheet(
      context,
      title: 'Editar Veículo',
      fields: [
        SimpleField(key: 'placa', label: 'Placa *', initial: veiculo.placa, required: true),
        SimpleField(key: 'modelo', label: 'Modelo *', initial: veiculo.modelo, required: true),
        SimpleField(
          key: 'tipo',
          label: 'Tipo',
          initial: veiculo.tipo ?? 'caminhao',
          options: const [
            SimpleOption('caminhao', 'Caminhão'),
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
            SimpleOption('propria', 'Própria'),
            SimpleOption('terceirizada', 'Terceirizada'),
            SimpleOption('agregada', 'Agregada'),
          ],
        ),
        SimpleField(
            key: 'capacidade',
            label: 'Capacidade (t)',
            initial: veiculo.capacidade?.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        SimpleField(
          key: 'motorista_padrao_id',
          label: 'Motorista padrão',
          initial: veiculo.motoristaPadraoId ?? '',
          options: [
            const SimpleOption('', '— Nenhum —'),
            for (final f in funcionarios) SimpleOption(f.id, f.nome),
          ],
        ),
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
      'motorista_padrao_id': (result['motorista_padrao_id'] ?? '').isEmpty
          ? null
          : result['motorista_padrao_id'],
    });
    onChanged();
  }

  Future<void> _alterarFoto(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 1600,
    );
    if (img == null) return;
    try {
      final bytes = await img.readAsBytes();
      final ext = img.name.contains('.')
          ? img.name.split('.').last.toLowerCase()
          : 'jpg';
      final client = ref.read(supabaseClientProvider);
      final path =
          'veiculo-${veiculo.id}-${DateTime.now().millisecondsSinceEpoch}.$ext';
      await client.storage.from('veiculos').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );
      final url = client.storage.from('veiculos').getPublicUrl(path);
      await ref
          .read(sistemaRepositoryProvider)
          .updateVeiculo(veiculo.id, {'foto_url': url});
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao enviar foto: $e')));
      }
    }
  }
}
