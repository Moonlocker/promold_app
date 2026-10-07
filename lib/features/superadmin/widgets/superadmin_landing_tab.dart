import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/superadmin_providers.dart';
import '../../../providers/supabase_providers.dart';

/// SuperAdmin — Editor da Landing Page (registro `landing_page_config`).
///
/// A estrutura do conteúdo é complexa (hero, seções, passos). No mobile,
/// editamos o JSON do conteúdo diretamente, com validação, e a opção de
/// restaurar o padrão (o web aplica os defaults sobre o que estiver salvo).
class SuperAdminLandingTab extends ConsumerStatefulWidget {
  const SuperAdminLandingTab({super.key});

  @override
  ConsumerState<SuperAdminLandingTab> createState() =>
      _SuperAdminLandingTabState();
}

class _SuperAdminLandingTabState extends ConsumerState<SuperAdminLandingTab> {
  final _controller = TextEditingController();
  bool _carregado = false;
  bool _salvando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(landingContentProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (content) {
        if (!_carregado) {
          _controller.text = const JsonEncoder.withIndent('  ')
              .convert(content.isEmpty ? <String, dynamic>{} : content);
          _carregado = true;
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Text('Conteúdo da Landing Page',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'Edite o JSON acima. Campos ausentes usam o padrão do sistema.',
              style: TextStyle(
                  fontSize: 11.5, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: null,
              minLines: 18,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _salvando ? null : _restaurarPadrao,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Restaurar padrão'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _salvando ? null : _salvar,
                    icon: const Icon(Icons.save, size: 18),
                    label: Text(_salvando ? 'Salvando...' : 'Salvar'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _salvar() async {
    Object? parsed;
    try {
      parsed = jsonDecode(_controller.text);
    } catch (e) {
      _snack('JSON inválido: $e');
      return;
    }
    if (parsed is! Map) {
      _snack('O conteúdo deve ser um objeto JSON.');
      return;
    }
    setState(() => _salvando = true);
    try {
      await ref
          .read(superAdminRepositoryProvider)
          .saveLandingContent(Map<String, dynamic>.from(parsed));
      ref.invalidate(landingContentProvider);
      _snack('Landing atualizada');
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _restaurarPadrao() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar padrão'),
        content: const Text(
            'Isso remove o conteúdo customizado e volta ao padrão do sistema.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _salvando = true);
    try {
      await ref
          .read(superAdminRepositoryProvider)
          .saveLandingContent(<String, dynamic>{});
      _controller.text = '{}';
      ref.invalidate(landingContentProvider);
      _snack('Conteúdo restaurado ao padrão');
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
