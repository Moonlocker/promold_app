import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/modulo_comercial.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/onboarding_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Onboarding: cria a conta e a organização (mesmo fluxo do webapp).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  bool _loading = false;

  final _nomeUsuario = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();

  final _nomeEmpresa = TextEditingController();
  final _cnpj = TextEditingController();
  final _m3 = TextEditingController(text: '50');
  final Set<String> _modulos = {};

  @override
  void dispose() {
    _nomeUsuario.dispose();
    _email.dispose();
    _senha.dispose();
    _nomeEmpresa.dispose();
    _cnpj.dispose();
    _m3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modulosAsync = ref.watch(modulosComerciaisProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar conta da empresa'),
        leading: _step == 0
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.go(AppRoutes.login),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step--),
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _Passos(atual: _step),
          const SizedBox(height: 24),
          if (_step == 0) _buildConta(),
          if (_step == 1) _buildEmpresa(),
          if (_step == 2) _buildModulos(modulosAsync),
        ],
      ),
    );
  }

  Widget _buildConta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Sua conta de acesso',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Crie suas credenciais para acessar o sistema.',
            style: TextStyle(color: AppColors.mutedForeground)),
        const SizedBox(height: 16),
        TextField(
          controller: _nomeUsuario,
          decoration: const InputDecoration(labelText: 'Nome completo *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-mail *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _senha,
          obscureText: true,
          decoration: const InputDecoration(
              labelText: 'Senha *', hintText: 'Mínimo 6 caracteres'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _criarConta,
          child: Text(_loading ? 'Criando...' : 'Continuar'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Já tenho conta · Entrar'),
        ),
      ],
    );
  }

  Widget _buildEmpresa() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Sobre sua empresa',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        TextField(
          controller: _nomeEmpresa,
          decoration: const InputDecoration(labelText: 'Nome da empresa *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cnpj,
          decoration:
              const InputDecoration(labelText: 'CNPJ (opcional)'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            if (_nomeEmpresa.text.trim().length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Informe o nome da empresa')),
              );
              return;
            }
            setState(() => _step = 2);
          },
          child: const Text('Continuar'),
        ),
      ],
    );
  }

  Widget _buildModulos(AsyncValue<List<ModuloComercial>> modulosAsync) {
    return modulosAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: LoadingView(),
      ),
      error: (e, _) => Text('Erro: $e'),
      data: (todos) {
        final modulos = todos.where((m) => !m.core).toList();
        final selecionados =
            modulos.where((m) => _modulos.contains(m.id));
        final totalFixo =
            selecionados.fold<double>(0, (a, m) => a + m.valorMensal);
        final totalM3 =
            selecionados.fold<double>(0, (a, m) => a + m.precoPorM3);
        final m3 = double.tryParse(_m3.text.replaceAll(',', '.')) ?? 0;
        final total = totalFixo + totalM3 * m3;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Monte seu plano por módulos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
                'Escolha os módulos que sua operação precisa.',
                style: TextStyle(color: AppColors.mutedForeground)),
            const SizedBox(height: 12),
            ...modulos.map((m) {
              final sel = _modulos.contains(m.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  value: sel,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _modulos.add(m.id);
                    } else {
                      _modulos.remove(m.id);
                    }
                  }),
                  title: Text(m.nome,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${Formatters.moeda(m.valorMensal)}/mês'
                    '${m.precoPorM3 > 0 ? ' + ${Formatters.moeda(m.precoPorM3)}/m³' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            TextField(
              controller: _m3,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  labelText: 'Volume médio mensal (m³)'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total mensal estimado',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(Formatters.moeda(total),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (_loading || _modulos.isEmpty) ? null : _finalizar,
              child: Text(_loading ? 'Criando...' : 'Criar minha conta'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _criarConta() async {
    if (_nomeUsuario.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _senha.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Preencha nome, e-mail e senha (mín. 6 caracteres)')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final loggedIn = await ref.read(onboardingRepositoryProvider).signUp(
            email: _email.text.trim(),
            password: _senha.text,
            nome: _nomeUsuario.text.trim(),
          );
      if (!mounted) return;
      if (loggedIn) {
        setState(() => _step = 1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Conta criada! Confirme seu e-mail e faça login para continuar.')),
        );
        context.go(AppRoutes.login);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _finalizar() async {
    setState(() => _loading = true);
    try {
      await ref.read(onboardingRepositoryProvider).criarOrganizacao(
            nome: _nomeEmpresa.text.trim(),
            cnpj: _cnpj.text.trim().isEmpty ? null : _cnpj.text.trim(),
            moduloIds: _modulos.toList(),
            m3: double.tryParse(_m3.text.replaceAll(',', '.')),
          );
      ref.invalidate(appUserProvider);
      if (mounted) context.go(AppRoutes.dashboard);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _Passos extends StatelessWidget {
  const _Passos({required this.atual});

  final int atual;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final ativo = i <= atual;
        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            decoration: BoxDecoration(
              color: ativo ? AppColors.primary : AppColors.muted,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
