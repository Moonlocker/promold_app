import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/status_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/obra_ifc.dart';
import '../../../models/obra_peca.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../widgets/obra_3d_viewer.dart';
import '../widgets/obra_ifc_viewer.dart';
import '../widgets/obra_peca_edit_sheet.dart';

/// Aba 3D da obra: visualizador nativo das peças + visualizador IFC opcional.
class Obra3DTab extends ConsumerStatefulWidget {
  const Obra3DTab({super.key, required this.obraId});

  final String obraId;

  @override
  ConsumerState<Obra3DTab> createState() => _Obra3DTabState();
}

class _Obra3DTabState extends ConsumerState<Obra3DTab> {
  String _modo = '3d'; // '3d' | 'ifc'
  ObraPeca? _selecionada;
  String? _ifcSelecionadoId;
  bool _enviando = false;

  @override
  Widget build(BuildContext context) {
    final pecasAsync = ref.watch(obrasPecasProvider(widget.obraId));
    final statusConfig =
        ref.watch(statusConfigProvider).value ?? StatusConfig.defaults;
    final arquivosAsync = ref.watch(obraIfcArquivosProvider(widget.obraId));

    final pecas = pecasAsync.value ?? const <ObraPeca>[];
    final arquivos = arquivosAsync.value ?? const <ObraIfcArquivo>[];
    final temIfc = arquivos.isNotEmpty;

    if (pecasAsync.isLoading) return const LoadingView();

    if (_modo == 'ifc' && !temIfc) _modo = '3d';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: '3d',
                      icon: Icon(Icons.view_in_ar_outlined, size: 18),
                      label: Text('3D'),
                    ),
                    ButtonSegment(
                      value: 'ifc',
                      icon: Icon(Icons.account_tree_outlined, size: 18),
                      label: Text('IFC'),
                    ),
                  ],
                  selected: {_modo},
                  onSelectionChanged: (s) =>
                      setState(() => _modo = s.first),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _modo == '3d'
              ? _buildNativo(pecas, statusConfig)
              : _buildIfc(arquivos, pecas, statusConfig),
        ),
      ],
    );
  }

  Widget _buildNativo(List<ObraPeca> pecas, StatusConfig statusConfig) {
    if (pecas.isEmpty) {
      return const EmptyState(
        icon: Icons.view_in_ar_outlined,
        title: 'Nenhuma peça na obra',
        message: 'Adicione peças para visualizar o modelo 3D.',
      );
    }
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Obra3DViewer(
                pecas: pecas,
                statusConfig: statusConfig,
                selectedId: _selecionada?.id,
                onSelect: (p) => setState(() => _selecionada = p),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: _LegendaStatus(statusConfig: statusConfig),
              ),
            ],
          ),
        ),
        if (_selecionada != null)
          _CartaoSelecionada(
            peca: _selecionada!,
            statusConfig: statusConfig,
            onFechar: () => setState(() => _selecionada = null),
            onEditar: () async {
              final ok = await showPecaEditSheet(
                context,
                ref,
                peca: _selecionada!,
                todas: pecas,
              );
              if (ok == true) {
                ref.invalidate(obrasPecasProvider(widget.obraId));
                setState(() => _selecionada = null);
              }
            },
          ),
      ],
    );
  }

  Widget _buildIfc(
    List<ObraIfcArquivo> arquivos,
    List<ObraPeca> pecas,
    StatusConfig statusConfig,
  ) {
    if (arquivos.isEmpty) {
      return EmptyState(
        icon: Icons.upload_file_outlined,
        title: 'Nenhum arquivo IFC',
        message:
            'Envie um arquivo .ifc para visualizar o modelo real do projeto.',
        action: FilledButton.icon(
          onPressed: _enviando ? null : _enviarIfc,
          icon: const Icon(Icons.upload, size: 18),
          label: Text(_enviando ? 'Enviando...' : 'Enviar IFC'),
        ),
      );
    }

    final ativo = arquivos.firstWhere(
      (a) => a.id == _ifcSelecionadoId,
      orElse: () => arquivos.firstWhere((a) => a.ativo,
          orElse: () => arquivos.first),
    );

    // Cores por status: globalId -> #RRGGBB (somente peças deste arquivo).
    final cores = <String, String>{};
    for (final p in pecas) {
      final gid = p.ifcGlobalId;
      if (gid == null || gid.isEmpty) continue;
      if (p.ifcArquivoId != null && p.ifcArquivoId != ativo.id) continue;
      cores[gid] = _hex(statusConfig.colorOf(p.status));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: ativo.id,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                      labelText: 'Arquivo IFC', isDense: true),
                  items: arquivos
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              '${a.ativo ? '● ' : ''}${a.nome}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _ifcSelecionadoId = v);
                    ref.read(obraIfcRepositoryProvider).setAtivo(v, widget.obraId);
                  },
                ),
              ),
              IconButton(
                tooltip: 'Enviar IFC',
                onPressed: _enviando ? null : _enviarIfc,
                icon: const Icon(Icons.upload_file),
              ),
              IconButton(
                tooltip: 'Gerenciar arquivos',
                onPressed: () => _gerenciar(arquivos),
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ObraIfcViewer(
            key: ValueKey(ativo.id),
            url: ativo.url,
            statusColors: cores,
            onSelect: (info) => _mostrarInfoIfc(info, pecas, statusConfig),
            onError: (msg) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('IFC: $msg')));
              }
            },
          ),
        ),
      ],
    );
  }

  static String _hex(Color c) {
    final v = c.toARGB32();
    return '#${v.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  Future<void> _enviarIfc() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ifc'],
    );
    if (files.isEmpty) return;
    setState(() => _enviando = true);
    try {
      final bytes = await files.first.readAsBytes();
      final arquivo = await ref.read(obraIfcRepositoryProvider).upload(
            obraId: widget.obraId,
            bytes: bytes,
            nomeArquivo: files.first.name,
          );
      ref.invalidate(obraIfcArquivosProvider(widget.obraId));
      setState(() {
        _modo = 'ifc';
        _ifcSelecionadoId = arquivo.id;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arquivo IFC enviado!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _gerenciar(List<ObraIfcArquivo> arquivos) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Arquivos IFC',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ...arquivos.map((a) => ListTile(
                  leading: Icon(
                    a.ativo ? Icons.check_circle : Icons.circle_outlined,
                    color: a.ativo ? AppColors.success : AppColors.mutedForeground,
                  ),
                  title: Text(a.nome),
                  subtitle: Text(
                      '${Formatters.arquivoTamanho(a.tamanhoBytes)} · ${a.createdAt != null ? Formatters.dataBr(a.createdAt) : ''}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.destructive),
                    onPressed: () async {
                      await ref
                          .read(obraIfcRepositoryProvider)
                          .delete(a);
                      ref.invalidate(obraIfcArquivosProvider(widget.obraId));
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _mostrarInfoIfc(
    Map<String, dynamic>? info,
    List<ObraPeca> pecas,
    StatusConfig statusConfig,
  ) {
    if (info == null) return;
    final gid = info['globalId'] as String?;
    ObraPeca? peca;
    if (gid != null && gid.isNotEmpty) {
      peca = pecas.where((p) => p.ifcGlobalId == gid).firstOrNull;
    }
    final nome = (info['name'] as String?)?.trim();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                peca?.identificador ?? (nome?.isNotEmpty == true ? nome! : 'Elemento'),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
              if (peca != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusConfig
                            .colorOf(peca.status)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel(peca.status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusConfig.colorOf(peca.status),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(peca.nomePeca,
                        style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          final ok = await showPecaEditSheet(
                            context,
                            ref,
                            peca: peca!,
                            todas: pecas,
                          );
                          if (ok == true) {
                            ref.invalidate(
                                obrasPecasProvider(widget.obraId));
                          }
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Editar peça'),
                      ),
                    ),
                  ],
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Este elemento não está vinculado a uma peça da obra.',
                    style: TextStyle(color: AppColors.mutedForeground),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoSelecionada extends StatelessWidget {
  const _CartaoSelecionada({
    required this.peca,
    required this.statusConfig,
    required this.onFechar,
    required this.onEditar,
  });

  final ObraPeca peca;
  final StatusConfig statusConfig;
  final VoidCallback onFechar;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 44,
                decoration: BoxDecoration(
                  color: statusConfig.colorOf(peca.status),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(peca.identificador,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(
                      '${peca.nomePeca} · ${statusLabel(peca.status)}'
                      '${peca.comprimento != null ? ' · ${peca.comprimento}m' : ''}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onEditar,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar'),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onFechar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendaStatus extends StatelessWidget {
  const _LegendaStatus({required this.statusConfig});

  final StatusConfig statusConfig;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: statusOrdem.map((s) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusConfig.colorOf(s),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(statusLabel(s),
                    style: const TextStyle(fontSize: 10.5)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
