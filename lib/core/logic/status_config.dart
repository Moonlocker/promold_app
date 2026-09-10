import 'package:flutter/material.dart';

import '../../models/obra_peca.dart';
import '../../models/processo_etapa.dart';

/// Porte de `src/lib/statusColors.ts` e `src/lib/statusWeights.ts`.

const List<String> statusOrdem = [
  'pendente',
  'armada',
  'concretada',
  'em_estoque',
  'carregada',
  'montada',
];

/// Status selecionáveis na UI (o webapp omite `carregada` nos seletores).
const List<String> statusSelecionaveis = [
  'pendente',
  'armada',
  'concretada',
  'em_estoque',
  'montada',
];

const Map<String, String> statusLabels = {
  'pendente': 'Pendente',
  'armada': 'Armada',
  'concretada': 'Concretada',
  'em_estoque': 'Em Estoque',
  'carregada': 'Carregada',
  'montada': 'Montada',
};

const Map<String, Color> defaultStatusColors = {
  'pendente': Color(0xFF64748B),
  'armada': Color(0xFF7C3AED),
  'concretada': Color(0xFF06B6D4),
  'em_estoque': Color(0xFFF59E0B),
  'carregada': Color(0xFF3B82F6),
  'montada': Color(0xFF10B981),
};

const Map<String, double> defaultStatusWeights = {
  'pendente': 0,
  'armada': 25,
  'concretada': 50,
  'em_estoque': 75,
  'carregada': 100,
  'montada': 100,
};

const Map<String, String> statusColorConfigKeys = {
  'pendente': 'status_cor_pendente',
  'armada': 'status_cor_armada',
  'concretada': 'status_cor_concretada',
  'em_estoque': 'status_cor_em_estoque',
  'carregada': 'status_cor_carregada',
  'montada': 'status_cor_montada',
};

const Map<String, String> statusWeightConfigKeys = {
  'pendente': 'status_peso_pendente',
  'armada': 'status_peso_armada',
  'concretada': 'status_peso_concretada',
  'em_estoque': 'status_peso_em_estoque',
  'carregada': 'status_peso_carregada',
  'montada': 'status_peso_montada',
};

String normalizarStatus(String? status) {
  final v = (status ?? 'pendente').toLowerCase();
  if (v == 'armada' ||
      v == 'concretada' ||
      v == 'em_estoque' ||
      v == 'carregada' ||
      v == 'montada') {
    return v;
  }
  return 'pendente';
}

String statusLabel(String? status) =>
    statusLabels[normalizarStatus(status)] ?? 'Pendente';

Color statusColor(String? status, [Map<String, Color>? colors]) {
  final key = normalizarStatus(status);
  return colors?[key] ?? defaultStatusColors[key]!;
}

double statusWeight(String? status, [Map<String, double>? weights]) {
  final key = normalizarStatus(status);
  final v = weights?[key] ?? defaultStatusWeights[key]!;
  return v.isFinite ? v : defaultStatusWeights[key]!;
}

/// `status ∈ {em_estoque, montada}` — usado como "concluída" no detalhe.
bool statusConcluido(String? status) =>
    status == 'em_estoque' || status == 'montada';

/// Converte `#RRGGBB` em [Color]. Retorna null se inválido.
Color? hexToColor(String? hex) {
  if (hex == null) return null;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 3) {
    h = h.split('').map((c) => '$c$c').join();
  }
  if (h.length != 6) return null;
  final value = int.tryParse(h, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

/// Progresso geral (porte de `computeProgressoGeral`).
///
/// Cada peça contribui com seu peso; cada item de etapa manual contribui
/// 0/50/100. Denominador = nº de peças + nº de itens de etapa.
int computeProgressoGeral({
  required String obraId,
  required List<ObraPeca> pecas,
  required List<ProcessoEtapa> processos,
  required List<ProcessoEtapaItem> etapasItens,
  required List<ObraEtapaStatus> etapaStatus,
  Map<String, double>? weights,
}) {
  final pecasObra = pecas.where((p) => p.obraId == obraId).toList();
  var wSum = pecasObra.fold<double>(
    0,
    (acc, p) => acc + statusWeight(p.status, weights),
  );
  var wTot = pecasObra.length.toDouble();

  for (final proc in processos) {
    final itens = etapasItens.where((it) => it.processoId == proc.id);
    if (itens.isEmpty) continue;
    for (final it in itens) {
      final match = etapaStatus
          .where((x) => x.obraId == obraId && x.etapaItemId == it.id)
          .toList();
      final st = match.isNotEmpty ? match.first.status : 'pendente';
      if (st == 'concluido') {
        wSum += 100;
      } else if (st == 'em_andamento') {
        wSum += 50;
      }
      wTot += 1;
    }
  }

  return wTot > 0 ? (wSum / wTot).round() : 0;
}
