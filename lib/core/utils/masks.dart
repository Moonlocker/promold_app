/// Máscaras de documento/telefone/CEP (porte de `src/lib/masks.ts`).
class Masks {
  Masks._();

  static String onlyDigits(String? value) {
    if (value == null) return '';
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static String maskCPF(String value) {
    final d = onlyDigits(value);
    final buf = StringBuffer();
    for (var i = 0; i < d.length && i < 11; i++) {
      if (i == 3 || i == 6) buf.write('.');
      if (i == 9) buf.write('-');
      buf.write(d[i]);
    }
    return buf.toString();
  }

  static String maskCNPJ(String value) {
    final d = onlyDigits(value);
    final buf = StringBuffer();
    for (var i = 0; i < d.length && i < 14; i++) {
      if (i == 2 || i == 5) buf.write('.');
      if (i == 8) buf.write('/');
      if (i == 12) buf.write('-');
      buf.write(d[i]);
    }
    return buf.toString();
  }

  static String maskCpfCnpj(String value) {
    final d = onlyDigits(value);
    return d.length <= 11 ? maskCPF(d) : maskCNPJ(d);
  }

  static String maskCEP(String value) {
    final d = onlyDigits(value);
    if (d.length <= 5) return d;
    return '${d.substring(0, 5)}-${d.substring(5, d.length.clamp(0, 8))}';
  }

  static String maskPhone(String value) {
    final d = onlyDigits(value);
    if (d.isEmpty) return '';
    if (d.length <= 10) {
      final buf = StringBuffer();
      for (var i = 0; i < d.length; i++) {
        if (i == 0) buf.write('(');
        if (i == 2) buf.write(') ');
        if (i == 6) buf.write('-');
        buf.write(d[i]);
      }
      return buf.toString();
    }
    final buf = StringBuffer();
    for (var i = 0; i < d.length && i < 11; i++) {
      if (i == 0) buf.write('(');
      if (i == 2) buf.write(') ');
      if (i == 7) buf.write('-');
      buf.write(d[i]);
    }
    return buf.toString();
  }
}
