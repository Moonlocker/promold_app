/// Helpers de conversão de valores vindos do PostgREST (dynamic) para tipos
/// Dart, tolerando null e numéricos em string.
class Parse {
  Parse._();

  static String? str(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static String strOr(dynamic v, [String fallback = '']) => str(v) ?? fallback;

  static num? numOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString().replaceAll(',', '.'));
  }

  static double dbl(dynamic v, [double fallback = 0]) =>
      numOrNull(v)?.toDouble() ?? fallback;

  static int intOr(dynamic v, [int fallback = 0]) =>
      numOrNull(v)?.toInt() ?? fallback;

  static bool boolean(dynamic v, [bool fallback = false]) {
    if (v == null) return fallback;
    if (v is bool) return v;
    return v.toString().toLowerCase() == 'true';
  }

  static DateTime? date(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static Map<String, dynamic> map(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  static List<dynamic> list(dynamic v) => v is List ? v : const [];
}
