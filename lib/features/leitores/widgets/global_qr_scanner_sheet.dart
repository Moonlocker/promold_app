import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/qr_scanner_view.dart';
import '../../../providers/supabase_providers.dart';

/// Scanner QR global (como no Header do sistema web): lê uma peça por QR Code
/// ou busca manual e devolve o código para abrir a Consulta.
Future<String?> showGlobalQrScanner(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _GlobalQrScannerSheet(),
  );
}

class _GlobalQrScannerSheet extends ConsumerStatefulWidget {
  const _GlobalQrScannerSheet();

  @override
  ConsumerState<_GlobalQrScannerSheet> createState() =>
      _GlobalQrScannerSheetState();
}

class _GlobalQrScannerSheetState extends ConsumerState<_GlobalQrScannerSheet> {
  bool _manual = false;
  final _busca = TextEditingController();
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    super.dispose();
  }

  void _onChanged(String termo) {
    _debounce?.cancel();
    final q = termo.trim();
    if (q.isEmpty) {
      setState(() {
        _resultados = [];
        _buscando = false;
      });
      return;
    }
    setState(() => _buscando = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final res =
          await ref.read(leitorServiceProvider).buscarPecasManual(q);
      if (!mounted) return;
      setState(() {
        _resultados = res;
        _buscando = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final altura = MediaQuery.of(context).size.height * 0.82;

    return SizedBox(
      height: altura,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 12 + bottom + safeBottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Consultar peça',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    icon: Icon(Icons.qr_code),
                    label: Text('QR Code')),
                ButtonSegment(
                    value: true,
                    icon: Icon(Icons.keyboard),
                    label: Text('Manual')),
              ],
              selected: {_manual},
              onSelectionChanged: (s) => setState(() => _manual = s.first),
            ),
            const SizedBox(height: 12),
            Expanded(child: _manual ? _manualView() : _qrView()),
          ],
        ),
      ),
    );
  }

  Widget _qrView() {
    return Column(
      children: [
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: QrScannerView(
              height: double.infinity,
              hint: 'Aponte para o QR Code da peça',
              onDetected: (code) => Navigator.pop(context, code),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'A peça será aberta na tela de Consulta.',
          style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
        ),
      ],
    );
  }

  Widget _manualView() {
    final termo = _busca.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _busca,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
          },
          decoration: const InputDecoration(
            hintText: 'Identificador da peça (ex.: P-12)',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _buscando
              ? const Center(child: CircularProgressIndicator())
              : _resultados.isEmpty
                  ? Center(
                      child: Text(
                        termo.isEmpty
                            ? 'Digite para buscar uma peça'
                            : 'Nenhuma peça encontrada',
                        style: const TextStyle(
                            color: AppColors.mutedForeground),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _resultados.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = _resultados[i];
                        final obra = r['obra'];
                        return ListTile(
                          title: Text(
                            r['identificador']?.toString() ?? '',
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            (obra is Map
                                    ? obra['nome']
                                    : 'Obra')?.toString() ??
                                '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            (r['status']?.toString() ?? '').toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.mutedForeground),
                          ),
                          onTap: () {
                            final id = r['identificador']?.toString();
                            if (id != null && id.isNotEmpty) {
                              Navigator.pop(context, id);
                            }
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
