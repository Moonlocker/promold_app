import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/masks.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/fiscal_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Configuração fiscal da organização (dados do emitente + Focus NFe).
class FiscalConfiguracaoScreen extends ConsumerStatefulWidget {
  const FiscalConfiguracaoScreen({super.key});

  @override
  ConsumerState<FiscalConfiguracaoScreen> createState() =>
      _FiscalConfiguracaoScreenState();
}

class _FiscalConfiguracaoScreenState
    extends ConsumerState<FiscalConfiguracaoScreen> {
  final _c = <String, TextEditingController>{};
  String _ambiente = 'homologacao';
  String _regime = 'simples_nacional';
  bool _optanteSimples = true;
  String? _id;
  bool _carregado = false;
  bool _saving = false;

  static const _campos = [
    'focus_nfe_token',
    'cnpj',
    'razao_social',
    'nome_fantasia',
    'inscricao_estadual',
    'inscricao_municipal',
    'cnae_principal',
    'logradouro',
    'numero',
    'complemento',
    'bairro',
    'municipio',
    'uf',
    'cep',
    'codigo_municipio',
    'telefone',
    'email',
    'cfop_padrao',
    'ncm_padrao',
    'cst_padrao',
    'csosn_padrao',
    'cst_pis_cofins',
    'aliquota_icms',
    'aliquota_pis',
    'aliquota_cofins',
    'origem_mercadoria',
    'natureza_operacao_padrao',
    'serie_nfe',
    'proximo_numero',
    'informacoes_adicionais_padrao',
  ];

  static const _labels = {
    'focus_nfe_token': 'Token Focus NFe',
    'cnpj': 'CNPJ',
    'razao_social': 'Razão social',
    'nome_fantasia': 'Nome fantasia',
    'inscricao_estadual': 'Inscrição estadual',
    'inscricao_municipal': 'Inscrição municipal',
    'cnae_principal': 'CNAE principal',
    'logradouro': 'Logradouro',
    'numero': 'Número',
    'complemento': 'Complemento',
    'bairro': 'Bairro',
    'municipio': 'Município',
    'uf': 'UF',
    'cep': 'CEP',
    'codigo_municipio': 'Código IBGE município',
    'telefone': 'Telefone',
    'email': 'E-mail',
    'cfop_padrao': 'CFOP padrão',
    'ncm_padrao': 'NCM padrão',
    'cst_padrao': 'CST ICMS padrão',
    'csosn_padrao': 'CSOSN padrão',
    'cst_pis_cofins': 'CST PIS/COFINS',
    'aliquota_icms': 'Alíquota ICMS (%)',
    'aliquota_pis': 'Alíquota PIS (%)',
    'aliquota_cofins': 'Alíquota COFINS (%)',
    'origem_mercadoria': 'Origem mercadoria',
    'natureza_operacao_padrao': 'Natureza de operação padrão',
    'serie_nfe': 'Série NFe',
    'proximo_numero': 'Próximo número NFe',
    'informacoes_adicionais_padrao': 'Informações adicionais padrão',
  };

  @override
  void initState() {
    super.initState();
    for (final key in _campos) {
      _c[key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _nz(String key) {
    final v = _c[key]!.text.trim();
    return v.isEmpty ? null : v;
  }

  double? _num(String key) => double.tryParse(_c[key]!.text.replaceAll(',', '.'));

  Future<void> _salvar() async {
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'ambiente': _ambiente,
      'regime_tributario': _regime,
      'optante_simples': _optanteSimples,
      'focus_nfe_token': _nz('focus_nfe_token'),
      'cnpj': _nz('cnpj'),
      'razao_social': _nz('razao_social'),
      'nome_fantasia': _nz('nome_fantasia'),
      'inscricao_estadual': _nz('inscricao_estadual'),
      'inscricao_municipal': _nz('inscricao_municipal'),
      'cnae_principal': _nz('cnae_principal'),
      'logradouro': _nz('logradouro'),
      'numero': _nz('numero'),
      'complemento': _nz('complemento'),
      'bairro': _nz('bairro'),
      'municipio': _nz('municipio'),
      'uf': _nz('uf'),
      'cep': _nz('cep'),
      'codigo_municipio': _nz('codigo_municipio'),
      'telefone': _nz('telefone'),
      'email': _nz('email'),
      'cfop_padrao': _nz('cfop_padrao'),
      'ncm_padrao': _nz('ncm_padrao'),
      'cst_padrao': _nz('cst_padrao'),
      'csosn_padrao': _nz('csosn_padrao'),
      'cst_pis_cofins': _nz('cst_pis_cofins'),
      'aliquota_icms': _num('aliquota_icms'),
      'aliquota_pis': _num('aliquota_pis'),
      'aliquota_cofins': _num('aliquota_cofins'),
      'origem_mercadoria': int.tryParse(_c['origem_mercadoria']!.text),
      'natureza_operacao_padrao': _nz('natureza_operacao_padrao'),
      'serie_nfe': int.tryParse(_c['serie_nfe']!.text),
      'proximo_numero': int.tryParse(_c['proximo_numero']!.text),
      'informacoes_adicionais_padrao': _nz('informacoes_adicionais_padrao'),
    };
    try {
      await ref
          .read(fiscalRepositoryProvider)
          .saveConfig(payload, id: _id);
      ref.invalidate(fiscalConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuração salva')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _enviarCertificado() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pfx', 'p12'],
    );
    if (files.isEmpty) return;
    try {
      final bytes = await files.first.readAsBytes();
      await ref.read(fiscalRepositoryProvider).uploadCertificado(
            bytes: bytes,
            nomeArquivo: files.first.name,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificado enviado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(fiscalConfigProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Configuração Fiscal')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (data) {
          if (!_carregado) {
            _id = data?['id'] as String?;
            for (final key in _campos) {
              final v = data?[key];
              _c[key]!.text = v == null ? '' : '$v';
            }
            _ambiente = (data?['ambiente'] as String?) ?? 'homologacao';
            _regime =
                (data?['regime_tributario'] as String?) ?? 'simples_nacional';
            _optanteSimples = (data?['optante_simples'] as bool?) ?? true;
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
                      const Text('Gateway / Ambiente',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _ambiente,
                        decoration: const InputDecoration(labelText: 'Ambiente'),
                        items: const [
                          DropdownMenuItem(
                              value: 'homologacao',
                              child: Text('Homologação (teste)')),
                          DropdownMenuItem(
                              value: 'producao', child: Text('Produção')),
                        ],
                        onChanged: (v) =>
                            setState(() => _ambiente = v ?? 'homologacao'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _regime,
                        decoration:
                            const InputDecoration(labelText: 'Regime tributário'),
                        items: const [
                          DropdownMenuItem(
                              value: 'simples_nacional',
                              child: Text('Simples Nacional')),
                          DropdownMenuItem(
                              value: 'simples_nacional_excesso',
                              child: Text('Simples Nacional (excesso)')),
                          DropdownMenuItem(
                              value: 'lucro_presumido',
                              child: Text('Lucro Presumido')),
                          DropdownMenuItem(
                              value: 'lucro_real', child: Text('Lucro Real')),
                        ],
                        onChanged: (v) =>
                            setState(() => _regime = v ?? 'simples_nacional'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Optante pelo Simples Nacional'),
                        value: _optanteSimples,
                        onChanged: (v) =>
                            setState(() => _optanteSimples = v),
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
                      const Text('Emitente',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      ..._campos.map((key) {
                        final isToken = key == 'focus_nfe_token';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: _c[key],
                            obscureText: isToken,
                            maxLines:
                                key == 'informacoes_adicionais_padrao' ? 2 : 1,
                            decoration: InputDecoration(
                                labelText: _labels[key] ?? key),
                            onChanged: (v) {
                              if (key == 'cnpj') {
                                final m = Masks.maskCNPJ(v);
                                _c[key]!.value = TextEditingValue(
                                  text: m,
                                  selection:
                                      TextSelection.collapsed(offset: m.length),
                                );
                              }
                            },
                          ),
                        );
                      }),
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
                      const Text('Certificado digital',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text(
                        'Envie o certificado A1 (.pfx) usado para assinar as notas.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.mutedForeground),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _enviarCertificado,
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Enviar certificado'),
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
