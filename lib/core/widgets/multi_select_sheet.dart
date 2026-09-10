import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Opção de um filtro de seleção múltipla.
class MultiSelectOption {
  const MultiSelectOption(this.value, this.label);

  final String value;
  final String label;
}

/// Abre uma folha de seleção múltipla com busca. Retorna o novo conjunto de
/// valores selecionados, ou `null` se o usuário cancelar.
Future<Set<String>?> showMultiSelectSheet({
  required BuildContext context,
  required String title,
  required List<MultiSelectOption> options,
  required Set<String> selected,
  String searchPlaceholder = 'Buscar...',
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _MultiSelectSheet(
      title: title,
      options: options,
      selected: selected,
      searchPlaceholder: searchPlaceholder,
    ),
  );
}

class _MultiSelectSheet extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchPlaceholder,
  });

  final String title;
  final List<MultiSelectOption> options;
  final Set<String> selected;
  final String searchPlaceholder;

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late Set<String> _selected = {...widget.selected};
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final filtradas = widget.options
        .where((o) => o.label.toLowerCase().contains(_busca.toLowerCase()))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selected = {}),
                    child: const Text('Limpar'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => setState(() => _busca = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: widget.searchPlaceholder,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtradas.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma opção encontrada.',
                        style: TextStyle(color: AppColors.mutedForeground),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtradas.length,
                      itemBuilder: (context, i) {
                        final opt = filtradas[i];
                        final marcado = _selected.contains(opt.value);
                        return CheckboxListTile(
                          value: marcado,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(opt.value);
                            } else {
                              _selected.remove(opt.value);
                            }
                          }),
                          title: Text(opt.label),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: Text(
                    _selected.isEmpty
                        ? 'Aplicar (todos)'
                        : 'Aplicar (${_selected.length})',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
