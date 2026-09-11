import 'dart:convert';
import 'dart:io';

/// Dados retornados pelo ViaCEP.
class CepInfo {
  const CepInfo({
    this.logradouro,
    this.bairro,
    this.cidade,
    this.uf,
  });

  final String? logradouro;
  final String? bairro;
  final String? cidade;
  final String? uf;
}

/// Consulta um CEP no ViaCEP (mesmo serviço usado pelo webapp).
/// Retorna `null` em caso de erro ou CEP inválido.
Future<CepInfo?> buscarCep(String cep) async {
  final digits = cep.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 8) return null;
  try {
    final client = HttpClient();
    final uri = Uri.parse('https://viacep.com.br/ws/$digits/json/');
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != 200) {
      client.close();
      return null;
    }
    final body = await response.transform(utf8.decoder).join();
    client.close();
    final map = jsonDecode(body) as Map<String, dynamic>;
    if (map['erro'] == true) return null;
    return CepInfo(
      logradouro: map['logradouro'] as String?,
      bairro: map['bairro'] as String?,
      cidade: map['localidade'] as String?,
      uf: map['uf'] as String?,
    );
  } catch (_) {
    return null;
  }
}
