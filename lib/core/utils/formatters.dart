/// Utilidades de formatação (pt-BR), alinhadas ao webapp.
class Formatters {
  Formatters._();

  /// Data de hoje no fuso America/Sao_Paulo (UTC-3), no formato `yyyy-MM-dd`.
  static String hojeBr() {
    final agora = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    return _iso(agora);
  }

  /// Domingo (início da semana) e sábado (fim), no fuso de São Paulo.
  static (String inicio, String fim) semanaAtualBr() {
    final agora = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    final diasDesdeDomingo = agora.weekday % 7; // Sun=7 -> 0
    final domingo = agora.subtract(Duration(days: diasDesdeDomingo));
    final sabado = domingo.add(const Duration(days: 6));
    return (_iso(domingo), _iso(sabado));
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Data no formato `yyyy-MM-dd` (fuso local do dispositivo).
  static String iso(DateTime d) => _iso(d);

  static String dataBr(DateTime? d) {
    if (d == null) return '--';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static const List<String> _meses = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  static String dataHoraBr(DateTime? d) {
    if (d == null) return '--';
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    final ano = d.year.toString().substring(2);
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$ano $h:$min';
  }

  static String dataLonga(DateTime? d) {
    if (d == null) return '--';
    return '${d.day} de ${_meses[d.month - 1]} de ${d.year}';
  }

  /// Formata bytes (porte de `formatFileSize`).
  static String arquivoTamanho(int? bytes) {
    if (bytes == null || bytes <= 0) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Formata número no padrão pt-BR (porte de `formatNumber`).
  static String numero(num? value, [int decimais = 0]) {
    if (value == null || !value.isFinite) return '0';
    final negativo = value < 0;
    final abs = value.abs();
    final fixo = abs.toStringAsFixed(decimais);
    final partes = fixo.split('.');
    final inteiro = partes[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => '.',
    );
    final texto = partes.length > 1 ? '$inteiro,${partes[1]}' : inteiro;
    return negativo ? '-$texto' : texto;
  }

  static String moeda(num valor) {
    final inteiro = valor.truncate();
    final centavos = ((valor - inteiro) * 100).round().abs().toString().padLeft(
      2,
      '0',
    );
    final texto = inteiro.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => '.',
    );
    return 'R\$ $texto,$centavos';
  }
}
