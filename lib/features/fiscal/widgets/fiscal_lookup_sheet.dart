import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/supabase_providers.dart';

/// Busca NCM/CFOP na edge function `fiscal-consulta`. Retorna o código
/// selecionado ou `null`. Porte de `FiscalLookupDialog`.
Future<String?> showFiscalLookupSheet(
  BuildContext context, {
  required String tipo, // 'ncm' | 'cfop'
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FiscalLookupSheet(tipo: tipo),
  );
}

class _FiscalLookupSheet extends ConsumerStatefulWidget {
  const _FiscalLookupSheet({required this.tipo});

  final String tipo;

  @override
  ConsumerState<_FiscalLookupSheet> createState() => _FiscalLookupSheetState();
}

class _FiscalLookupSheetState extends ConsumerState<_FiscalLookupSheet> {
  final _busca = TextEditingController();
  List<Map<String, String>> _itens = const [];
  bool _carregando = false;
  bool _buscou = false;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() => _carregando = true);
    try {
      final itens = await ref
          .read(fiscalRepositoryProvider)
          .buscarFiscal(widget.tipo, _busca.text.trim());
      setState(() {
        _itens = itens;
        _buscou = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha na consulta: $e')));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Buscar ${widget.tipo.toUpperCase()}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _busca,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _buscar(),
                  decoration: InputDecoration(
                    hintText: widget.tipo == 'ncm'
                        ? 'Código ou descrição (ex: 7308)'
                        : 'Código ou descrição (ex: 5102)',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _carregando ? null : _buscar,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Buscar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_carregando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_itens.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _buscou
                    ? 'Nenhum resultado encontrado.'
                    : 'Digite e toque em Buscar.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedForeground),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _itens.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final it = _itens[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(it['codigo'] ?? '',
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(it['descricao'] ?? '',
                        style: const TextStyle(fontSize: 12)),
                    onTap: () => Navigator.pop(context, it['codigo']),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
