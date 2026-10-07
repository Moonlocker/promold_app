/// Utilitários de entrada de data (aceita formatos comuns do usuário).
library;

/// Normaliza uma data digitada para `yyyy-MM-dd`.
///
/// Aceita `yyyy-MM-dd` (com eventual hora), `dd/MM/yyyy` e `dd-MM-yyyy`.
/// Retorna `null` quando vazio; devolve o texto original se não reconhecido.
String? normalizarDataBr(String? raw) {
  if (raw == null) return null;
  final v = raw.trim();
  if (v.isEmpty) return null;
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(v);
  if (iso != null) return '${iso[1]}-${iso[2]}-${iso[3]}';
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})').firstMatch(v);
  if (br != null) return '${br[3]}-${br[2]}-${br[1]}';
  final dash = RegExp(r'^(\d{2})-(\d{2})-(\d{4})').firstMatch(v);
  if (dash != null) return '${dash[3]}-${dash[2]}-${dash[1]}';
  return v;
}
