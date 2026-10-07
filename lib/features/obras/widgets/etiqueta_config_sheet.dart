import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/etiquetas_service.dart';

/// Abre a configuração de campos da etiqueta QR. Retorna a config escolhida
/// (ou `null` se cancelado).
Future<EtiquetaConfig?> showEtiquetaConfigSheet(
  BuildContext context, {
  required EtiquetaConfig config,
}) {
  return showModalBottomSheet<EtiquetaConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EtiquetaConfigSheet(config: config),
  );
}

class _EtiquetaConfigSheet extends StatefulWidget {
  const _EtiquetaConfigSheet({required this.config});

  final EtiquetaConfig config;

  @override
  State<_EtiquetaConfigSheet> createState() => _EtiquetaConfigSheetState();
}

class _EtiquetaConfigSheetState extends State<_EtiquetaConfigSheet> {
  late final EtiquetaConfig _cfg = EtiquetaConfig(
    obra: widget.config.obra,
    categoria: widget.config.categoria,
    identificador: widget.config.identificador,
    dimensoes: widget.config.dimensoes,
    volume: widget.config.volume,
    aco: widget.config.aco,
    peso: widget.config.peso,
    posicao: widget.config.posicao,
    qrcode: widget.config.qrcode,
    personalizados: widget.config.personalizados,
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Campos da etiqueta',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _check('Nome da obra', _cfg.obra, (v) => _cfg.obra = v),
            _check('Categoria', _cfg.categoria, (v) => _cfg.categoria = v),
            _check('Identificador', _cfg.identificador,
                (v) => _cfg.identificador = v),
            _check('Dimensões', _cfg.dimensoes, (v) => _cfg.dimensoes = v),
            _check('Volume', _cfg.volume, (v) => _cfg.volume = v),
            _check('Aço', _cfg.aco, (v) => _cfg.aco = v),
            _check('Peso', _cfg.peso, (v) => _cfg.peso = v),
            _check('Posição na montagem', _cfg.posicao,
                (v) => _cfg.posicao = v),
            _check('QR Code', _cfg.qrcode, (v) => _cfg.qrcode = v),
            _check('Campos personalizados', _cfg.personalizados,
                (v) => _cfg.personalizados = v),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, _cfg),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _check(String label, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onChanged: (v) => setState(() => onChanged(v ?? false)),
    );
  }
}
