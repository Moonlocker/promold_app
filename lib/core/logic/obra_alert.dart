/// Porte de `calculateObraAlertStatus` (src/lib/notifications.ts).
///
/// Sinaliza atenção quando o avanço da produção está atrás do tempo decorrido.
class ObraAlertStatus {
  const ObraAlertStatus({
    required this.needsAttention,
    required this.timeElapsedPercent,
    required this.productionPercent,
  });

  final bool needsAttention;
  final double timeElapsedPercent;
  final double productionPercent;
}

ObraAlertStatus calculateObraAlertStatus({
  DateTime? dataInicio,
  DateTime? dataPrevisao,
  required int produzido,
  required int totalPecas,
}) {
  const none = ObraAlertStatus(
    needsAttention: false,
    timeElapsedPercent: 0,
    productionPercent: 0,
  );
  if (dataInicio == null || dataPrevisao == null || totalPecas == 0) {
    return none;
  }

  final hoje = DateTime.now();
  final inicio = DateTime(dataInicio.year, dataInicio.month, dataInicio.day, 12);
  final previsao =
      DateTime(dataPrevisao.year, dataPrevisao.month, dataPrevisao.day, 12);
  final productionPercent = (produzido / totalPecas) * 100;

  if (hoje.isBefore(inicio)) {
    return ObraAlertStatus(
      needsAttention: false,
      timeElapsedPercent: 0,
      productionPercent: productionPercent,
    );
  }
  if (hoje.isAfter(previsao)) {
    return ObraAlertStatus(
      needsAttention: produzido < totalPecas,
      timeElapsedPercent: 100,
      productionPercent: productionPercent,
    );
  }

  final totalDays = previsao.difference(inicio).inMilliseconds / 86400000;
  final elapsedDays = hoje.difference(inicio).inMilliseconds / 86400000;
  final double timeElapsedPercent = totalDays > 0 ? (elapsedDays / totalDays) * 100 : 0;

  return ObraAlertStatus(
    needsAttention: productionPercent < timeElapsedPercent,
    timeElapsedPercent: timeElapsedPercent,
    productionPercent: productionPercent,
  );
}
