import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/superadmin_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Chaves conhecidas das configurações globais.
const _globaisCampos = <String, String>{
  'whatsapp_flutuante_numero': 'WhatsApp flutuante — número',
  'whatsapp_flutuante_mensagem': 'WhatsApp flutuante — mensagem',
  'logo_landing_url': 'Logo da landing',
  'logo_login_url': 'Logo do login',
  'logo_sidebar_url': 'Logo da sidebar',
};

const _secretasCampos = <String, String>{
  'ASAAS_API_KEY': 'Asaas API Key',
  'ASAAS_WEBHOOK_TOKEN': 'Asaas Webhook Token',
  'ASAAS_AMBIENTE': 'Asaas Ambiente',
  'FOCUS_NFE_TOKEN': 'Focus NFe Token',
  'FOCUS_NFE_AMBIENTE': 'Focus NFe Ambiente',
  'RESEND_API_KEY': 'Resend API Key',
  'RESEND_FROM_EMAIL': 'Resend From E-mail',
  'RESEND_FROM_NAME': 'Resend From Nome',
  'RESEND_COBRANCA_TEMPLATE': 'Template de cobrança',
};

/// SuperAdmin — aba Configurações Globais.
class SuperAdminConfigGlobaisTab extends ConsumerStatefulWidget {
  const SuperAdminConfigGlobaisTab({super.key});

  @override
  ConsumerState<SuperAdminConfigGlobaisTab> createState() =>
      _SuperAdminConfigGlobaisTabState();
}

class _SuperAdminConfigGlobaisTabState
    extends ConsumerState<SuperAdminConfigGlobaisTab> {
  final _globais = <String, TextEditingController>{};
  final _secretas = <String, TextEditingController>{};
  bool _whatsappAtivo = false;
  bool _carregado = false;
  bool _salvando = false;

  @override
  void dispose() {
    for (final c in _globais.values) {
      c.dispose();
    }
    for (final c in _secretas.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final globaisAsync = ref.watch(configGlobaisProvider);
    final secretasAsync = ref.watch(configSecretasProvider);

    return globaisAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (globais) {
        if (!_carregado && secretasAsync.hasValue) {
          final gMap = {
            for (final g in globais)
              (g['chave'] as String): (g['valor'] as String? ?? ''),
          };
          _whatsappAtivo = gMap['whatsapp_flutuante_ativo'] == 'true';
          for (final key in _globaisCampos.keys) {
            _globais[key] = TextEditingController(text: gMap[key] ?? '');
          }
          final sMap = {
            for (final s in (secretasAsync.value ?? const []))
              (s['chave'] as String): (s['valor'] as String? ?? ''),
          };
          for (final key in _secretasCampos.keys) {
            _secretas[key] = TextEditingController(text: sMap[key] ?? '');
          }
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
                    const Text('Globais',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('WhatsApp flutuante ativo'),
                      value: _whatsappAtivo,
                      onChanged: (v) => setState(() => _whatsappAtivo = v),
                    ),
                    for (final e in _globaisCampos.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: _globais[e.key],
                          decoration: InputDecoration(
                              labelText: e.value, isDense: true),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Secretas',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                      'Chaves de integração (Asaas, Focus NFe, Resend).',
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.mutedForeground),
                    ),
                    const SizedBox(height: 8),
                    for (final e in _secretasCampos.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: _secretas[e.key],
                          obscureText: e.key.contains('KEY') ||
                              e.key.contains('TOKEN'),
                          decoration: InputDecoration(
                              labelText: e.value, isDense: true),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: const Icon(Icons.save, size: 18),
              label: Text(_salvando ? 'Salvando...' : 'Salvar configurações'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    final repo = ref.read(superAdminRepositoryProvider);
    try {
      await repo.upsertConfigGlobal(
          'whatsapp_flutuante_ativo', _whatsappAtivo ? 'true' : 'false');
      for (final e in _globais.entries) {
        await repo.upsertConfigGlobal(e.key, _nz(e.value.text));
      }
      for (final e in _secretas.entries) {
        await repo.upsertConfigSecreta(e.key, _nz(e.value.text));
      }
      ref.invalidate(configGlobaisProvider);
      ref.invalidate(configSecretasProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  static String? _nz(String v) => v.trim().isEmpty ? null : v.trim();
}
