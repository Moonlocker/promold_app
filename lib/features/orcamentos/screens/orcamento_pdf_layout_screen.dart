import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/sistema_providers.dart';
import '../../../providers/supabase_providers.dart';

const _variaveis = [
  '{{cliente}}',
  '{{endereco}}',
  '{{numero_orcamento}}',
  '{{data_emissao}}',
  '{{data_validade}}',
  '{{prazo_estimado}}',
  '{{contato_responsavel}}',
  '{{telefone_contato}}',
  '{{metros_quadrados}}',
  '{{valor_total}}',
  '{{empresa_nome}}',
  '{{observacoes}}',
];

const _tiposBloco = <String, String>{
  'title': 'Título',
  'text': 'Texto',
  'spacer': 'Espaçador',
  'line': 'Linha',
  'image': 'Imagem (URL)',
};

/// Editor de Layout do PDF do orçamento (cabeçalho/rodapé).
class OrcamentoPdfLayoutScreen extends ConsumerStatefulWidget {
  const OrcamentoPdfLayoutScreen({super.key});

  @override
  ConsumerState<OrcamentoPdfLayoutScreen> createState() =>
      _OrcamentoPdfLayoutScreenState();
}

class _OrcamentoPdfLayoutScreenState
    extends ConsumerState<OrcamentoPdfLayoutScreen> {
  List<Map<String, dynamic>> _header = [];
  List<Map<String, dynamic>> _footer = [];
  bool _carregado = false;
  bool _salvando = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orcamentoPdfLayoutProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Layout do PDF'),
          actions: [
            IconButton(
              tooltip: 'Restaurar padrão',
              icon: const Icon(Icons.restart_alt),
              onPressed: _salvando ? null : _restaurar,
            ),
            IconButton(
              tooltip: 'Salvar',
              icon: const Icon(Icons.save),
              onPressed: _salvando ? null : _salvar,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Cabeçalho'),
              Tab(text: 'Rodapé'),
            ],
          ),
        ),
        body: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (config) {
            if (!_carregado) {
              _header = ((config['header_blocks'] as List?) ?? const [])
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
              _footer = ((config['footer_blocks'] as List?) ?? const [])
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
              _carregado = true;
            }
            return TabBarView(
              children: [
                _blocksTab(true),
                _blocksTab(false),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _blocksTab(bool isHeader) {
    final blocos = isHeader ? _header : _footer;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: PopupMenuButton<String>(
            child: const Chip(
              avatar: Icon(Icons.add, size: 16),
              label: Text('Adicionar bloco'),
            ),
            onSelected: (t) => _addBloco(isHeader, t),
            itemBuilder: (_) => _tiposBloco.entries
                .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        if (blocos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Nenhum bloco. O PDF usa o layout padrão.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedForeground)),
          )
        else
          for (var i = 0; i < blocos.length; i++)
            _BlocoCard(
              bloco: blocos[i],
              onEdit: () => _editarBloco(isHeader, i),
              onUp: i > 0 ? () => setState(() => _mover(blocos, i, -1)) : null,
              onDown: i < blocos.length - 1
                  ? () => setState(() => _mover(blocos, i, 1))
                  : null,
              onDelete: () => setState(() => blocos.removeAt(i)),
            ),
        const SizedBox(height: 20),
        const Text('Variáveis disponíveis',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _variaveis
              .map((v) => Chip(
                    label: Text(v,
                        style: const TextStyle(
                            fontSize: 11, fontFamily: 'monospace')),
                    visualDensity: VisualDensity.compact,
                  ))
              .toList(),
        ),
      ],
    );
  }

  void _mover(List<Map<String, dynamic>> lista, int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= lista.length) return;
    final tmp = lista[i];
    lista[i] = lista[j];
    lista[j] = tmp;
  }

  void _addBloco(bool isHeader, String tipo) {
    final bloco = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'type': tipo,
      'content': tipo == 'title'
          ? 'Promold'
          : tipo == 'text'
              ? '{{empresa_nome}}'
              : '',
      'align': 'left',
      'fontSize': tipo == 'title' ? 16 : 10,
      'bold': tipo == 'title',
      'italic': false,
      'height': 12,
      'imageUrl': '',
    };
    setState(() => (isHeader ? _header : _footer).add(bloco));
    _editarBloco(isHeader, (isHeader ? _header : _footer).length - 1);
  }

  Future<void> _editarBloco(bool isHeader, int index) async {
    final lista = isHeader ? _header : _footer;
    final bloco = lista[index];
    final tipo = bloco['type'] as String? ?? 'text';
    final content =
        TextEditingController(text: bloco['content'] as String? ?? '');
    final fontSize = TextEditingController(
        text: ((bloco['fontSize'] as num?) ?? 10).toString());
    final height = TextEditingController(
        text: ((bloco['height'] as num?) ?? 12).toString());
    final imageUrl =
        TextEditingController(text: bloco['imageUrl'] as String? ?? '');
    String align = (bloco['align'] as String?) ?? 'left';
    bool bold = (bloco['bold'] as bool?) ?? false;
    bool italic = (bloco['italic'] as bool?) ?? false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Bloco: ${_tiposBloco[tipo] ?? tipo}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                if (tipo == 'title' || tipo == 'text')
                  TextField(
                    controller: content,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Conteúdo (use {{variaveis}})'),
                  ),
                if (tipo == 'image')
                  TextField(
                    controller: imageUrl,
                    decoration: const InputDecoration(labelText: 'URL da imagem'),
                  ),
                if (tipo == 'spacer')
                  TextField(
                    controller: height,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Altura'),
                  ),
                if (tipo == 'title' || tipo == 'text') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: align,
                          decoration:
                              const InputDecoration(labelText: 'Alinhamento'),
                          items: const [
                            DropdownMenuItem(
                                value: 'left', child: Text('Esquerda')),
                            DropdownMenuItem(
                                value: 'center', child: Text('Centro')),
                            DropdownMenuItem(
                                value: 'right', child: Text('Direita')),
                          ],
                          onChanged: (v) => setSheet(() => align = v ?? 'left'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: fontSize,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Fonte'),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Negrito'),
                    value: bold,
                    onChanged: (v) => setSheet(() => bold = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Itálico'),
                    value: italic,
                    onChanged: (v) => setSheet(() => italic = v),
                  ),
                ],
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok == true) {
      setState(() {
        bloco['content'] = content.text;
        bloco['fontSize'] = double.tryParse(fontSize.text) ?? 10;
        bloco['height'] = double.tryParse(height.text) ?? 12;
        bloco['imageUrl'] = imageUrl.text.trim();
        bloco['align'] = align;
        bloco['bold'] = bold;
        bloco['italic'] = italic;
      });
    }
    content.dispose();
    fontSize.dispose();
    height.dispose();
    imageUrl.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await ref.read(sistemaRepositoryProvider).savePdfLayout(
            header: _header,
            footer: _footer,
          );
      ref.invalidate(orcamentoPdfLayoutProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Layout salvo')));
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

  Future<void> _restaurar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar padrão'),
        content: const Text('Remover o layout customizado (volta ao padrão)?'),
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
    if (ok != true) return;
    setState(() {
      _header = [];
      _footer = [];
    });
    await _salvar();
  }
}

class _BlocoCard extends StatelessWidget {
  const _BlocoCard({
    required this.bloco,
    required this.onEdit,
    required this.onUp,
    required this.onDown,
    required this.onDelete,
  });

  final Map<String, dynamic> bloco;
  final VoidCallback onEdit;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tipo = bloco['type'] as String? ?? 'text';
    final content = (bloco['content'] as String? ?? '').trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onEdit,
        leading: const Icon(Icons.drag_indicator),
        title: Text(_tiposBloco[tipo] ?? tipo,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: content.isEmpty
            ? null
            : Text(content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                onPressed: onUp),
            IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                onPressed: onDown),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.destructive),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
