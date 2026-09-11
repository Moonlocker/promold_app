import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/financeiro_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Integrações Financeiras: configuração da conta Asaas (PIX/Boleto).
class IntegracoesFinanceirasScreen extends ConsumerStatefulWidget {
  const IntegracoesFinanceirasScreen({super.key});

  @override
  ConsumerState<IntegracoesFinanceirasScreen> createState() =>
      _IntegracoesFinanceirasScreenState();
}

class _IntegracoesFinanceirasScreenState
    extends ConsumerState<IntegracoesFinanceirasScreen> {
  final _apiKey = TextEditingController();
  final _token = TextEditingController();
  String _ambiente = 'sandbox';
  bool _ativo = false;
  String? _id;
  bool _carregado = false;
  bool _saving = false;

  @override
  void dispose() {
    _apiKey.dispose();
    _token.dispose();
    super.dispose();
  }

  String _gerarToken() {
    final u = const Uuid();
    return (u.v4().replaceAll('-', '') + u.v4().replaceAll('-', ''))
        .substring(0, 48);
  }

  String get _webhookUrl {
    final ref0 = Env.supabaseUrl.replaceFirst('https://', '').split('.').first;
    return 'https://$ref0.supabase.co/functions/v1/cliente-asaas-webhook?token=${_token.text}';
  }

  Future<void> _salvar() async {
    setState(() => _saving = true);
    final token = _token.text.trim().isEmpty ? _gerarToken() : _token.text.trim();
    final payload = <String, dynamic>{
      'asaas_api_key': _apiKey.text.trim().isEmpty ? null : _apiKey.text.trim(),
      'asaas_ambiente': _ambiente,
      'asaas_ativo': _ativo,
      'asaas_webhook_token': token,
    };
    try {
      await ref
          .read(financeiroRepositoryProvider)
          .saveIntegracao(payload, id: _id);
      _token.text = token;
      ref.invalidate(integracaoFinanceiraProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Integração salva')),
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
    final async = ref.watch(integracaoFinanceiraProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Integrações Financeiras')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (data) {
          if (!_carregado) {
            _id = data?['id'] as String?;
            _apiKey.text = (data?['asaas_api_key'] as String?) ?? '';
            _token.text = (data?['asaas_webhook_token'] as String?) ?? '';
            _ambiente = (data?['asaas_ambiente'] as String?) ?? 'sandbox';
            _ativo = (data?['asaas_ativo'] as bool?) ?? false;
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.bolt,
                                color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Asaas — Cobranças (PIX e Boleto)',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Switch(
                            value: _ativo,
                            onChanged: (v) => setState(() => _ativo = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _apiKey,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Chave de API do Asaas',
                          hintText: '\$aact_...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _ambiente,
                        decoration: const InputDecoration(labelText: 'Ambiente'),
                        items: const [
                          DropdownMenuItem(
                              value: 'sandbox', child: Text('Sandbox (teste)')),
                          DropdownMenuItem(
                              value: 'producao', child: Text('Produção')),
                        ],
                        onChanged: (v) =>
                            setState(() => _ambiente = v ?? 'sandbox'),
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
                      const Row(
                        children: [
                          Icon(Icons.verified_user_outlined,
                              size: 18, color: AppColors.success),
                          SizedBox(width: 8),
                          Text('Webhook do Asaas',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _token,
                        decoration: InputDecoration(
                          labelText: 'Token de autenticação',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            onPressed: () => setState(
                                () => _token.text = _gerarToken()),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        readOnly: true,
                        controller: TextEditingController(text: _webhookUrl),
                        decoration: InputDecoration(
                          labelText: 'URL do webhook',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: _webhookUrl));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('URL copiada')),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _salvar,
                icon: const Icon(Icons.save, size: 18),
                label: Text(_saving ? 'Salvando...' : 'Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
