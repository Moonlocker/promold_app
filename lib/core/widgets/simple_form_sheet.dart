import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Opção para um campo de seleção do formulário simples.
class SimpleOption {
  const SimpleOption(this.value, this.label);

  final String value;
  final String label;
}

/// Campo de texto para um formulário simples em bottom sheet.
class SimpleField {
  const SimpleField({
    required this.key,
    required this.label,
    this.initial,
    this.required = false,
    this.maxLines = 1,
    this.uppercase = false,
    this.keyboardType,
    this.hint,
    this.options,
  });

  final String key;
  final String label;
  final String? initial;
  final bool required;
  final int maxLines;
  final bool uppercase;
  final TextInputType? keyboardType;
  final String? hint;

  /// Quando informado, renderiza um dropdown em vez de campo de texto.
  final List<SimpleOption>? options;
}

/// Abre um formulário simples de campos de texto. Retorna os valores por chave,
/// ou `null` se cancelado. Campos opcionais vazios retornam `''`.
Future<Map<String, String>?> showSimpleFormSheet(
  BuildContext context, {
  required String title,
  required List<SimpleField> fields,
  String submitLabel = 'Salvar',
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SimpleFormSheet(
      title: title,
      fields: fields,
      submitLabel: submitLabel,
    ),
  );
}

class _SimpleFormSheet extends StatefulWidget {
  const _SimpleFormSheet({
    required this.title,
    required this.fields,
    required this.submitLabel,
  });

  final String title;
  final List<SimpleField> fields;
  final String submitLabel;

  @override
  State<_SimpleFormSheet> createState() => _SimpleFormSheetState();
}

class _SimpleFormSheetState extends State<_SimpleFormSheet> {
  late final Map<String, TextEditingController> _controllers = {
    for (final f in widget.fields)
      f.key: TextEditingController(text: f.initial ?? ''),
  };

  late final Map<String, String> _selects = {
    for (final f in widget.fields)
      if (f.options != null)
        f.key: (f.initial != null &&
                f.options!.any((o) => o.value == f.initial))
            ? f.initial!
            : (f.options!.isNotEmpty ? f.options!.first.value : ''),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _salvar() {
    for (final f in widget.fields) {
      if (f.options != null) continue;
      if (f.required && _controllers[f.key]!.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Informe ${f.label.replaceAll(' *', '')}')),
        );
        return;
      }
    }
    final result = <String, String>{};
    for (final f in widget.fields) {
      if (f.options != null) {
        result[f.key] = _selects[f.key] ?? '';
        continue;
      }
      var v = _controllers[f.key]!.text.trim();
      if (f.uppercase) v = v.toUpperCase();
      result[f.key] = v;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final f in widget.fields) ...[
              if (f.options != null)
                DropdownButtonFormField<String>(
                  initialValue: _selects[f.key],
                  decoration: InputDecoration(labelText: f.label),
                  items: f.options!
                      .map((o) => DropdownMenuItem(
                            value: o.value,
                            child: Text(o.label),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selects[f.key] = v ?? ''),
                )
              else
                TextField(
                  controller: _controllers[f.key],
                  maxLines: f.maxLines,
                  keyboardType: f.keyboardType,
                  decoration:
                      InputDecoration(labelText: f.label, hintText: f.hint),
                ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            FilledButton(onPressed: _salvar, child: Text(widget.submitLabel)),
          ],
        ),
      ),
    );
  }
}
