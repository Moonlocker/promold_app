import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Aba Empresa: dados cadastrais da organização.
class EmpresaTab extends ConsumerStatefulWidget {
  const EmpresaTab({super.key});

  @override
  ConsumerState<EmpresaTab> createState() => _EmpresaTabState();
}

class _EmpresaTabState extends ConsumerState<EmpresaTab> {
  final _c = <String, TextEditingController>{
    'nome': TextEditingController(),
    'cnpj': TextEditingController(),
    'email': TextEditingController(),
    'telefone': TextEditingController(),
  };
  String? _orgId;
  bool _carregado = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _nullIfEmpty(String key) {
    final v = _c[key]!.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _salvar() async {
    if (_orgId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(sistemaRepositoryProvider).updateOrganizacao(_orgId!, {
        'nome': _c['nome']!.text.trim(),
        'cnpj': _nullIfEmpty('cnpj'),
        'email': _nullIfEmpty('email'),
        'telefone': _nullIfEmpty('telefone'),
      });
      ref.invalidate(appUserProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empresa atualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);
    return userAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (user) {
        final org = user?.organizacao;
        if (org == null) {
          return const Center(
            child: Text('Usuário sem organização vinculada.',
                style: TextStyle(color: AppColors.mutedForeground)),
          );
        }
        if (!_carregado) {
          _orgId = org.id;
          _c['nome']!.text = org.nome;
          _c['cnpj']!.text = org.cnpj ?? '';
          _c['email']!.text = org.email ?? '';
          _c['telefone']!.text = org.telefone ?? '';
          _carregado = true;
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _c['nome'],
                      decoration: const InputDecoration(labelText: 'Nome *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _c['cnpj'],
                      decoration: const InputDecoration(labelText: 'CNPJ'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _c['email'],
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _c['telefone'],
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Telefone'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _salvar,
              icon: const Icon(Icons.save, size: 18),
              label: Text(_saving ? 'Salvando...' : 'Salvar'),
            ),
          ],
        );
      },
    );
  }
}
