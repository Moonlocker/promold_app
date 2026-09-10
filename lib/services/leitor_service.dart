import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../core/utils/formatters.dart';
import '../models/estoque.dart';
import '../models/leitor.dart';

/// Lógica dos leitores QRCode: resolução de código, atualização de status e
/// consulta detalhada. Espelha o comportamento do webapp.
class LeitorService {
  LeitorService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  String _sanitize(String codigo) =>
      codigo.trim().replaceAll(RegExp(r'[,()]'), '');

  /// Resolve uma peça por UUID ou identificador.
  Future<PecaLeitor?> buscarPeca(
    String codigo, {
    required String campoData,
    bool caseSensitive = false,
  }) async {
    final c = _sanitize(codigo);
    final filtro = caseSensitive
        ? 'id.eq.$c,identificador.eq.$c'
        : 'id.eq.$c,identificador.ilike.$c';
    final row = await _client
        .from('obras_pecas')
        .select(
            'id, identificador, status, $campoData, pecas_catalogo(nome), obras(nome)')
        .or(filtro)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return PecaLeitor.fromMap(Map<String, dynamic>.from(row), campoData);
  }

  /// Resolve um estoque por UUID ou nome.
  Future<Estoque?> resolverEstoque(String codigo) async {
    final c = _sanitize(codigo);
    final row = await _client
        .from('estoques')
        .select('id, nome, pecas_permitidas, categorias_permitidas')
        .or('id.eq.$c,nome.ilike.$c')
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return Estoque.fromMap(Map<String, dynamic>.from(row));
  }

  /// Marca um status e preenche a data correspondente se ainda estiver vazia.
  Future<void> marcarStatus({
    required String pecaId,
    required String status,
    required String campoData,
    DateTime? dataAtual,
  }) async {
    final update = <String, dynamic>{'status': status};
    if (dataAtual == null) update[campoData] = Formatters.hojeBr();
    await _client.from('obras_pecas').update(update).eq('id', pecaId);
  }

  /// Vincula a peça a um estoque (status `em_estoque`), preenchendo
  /// `data_concretagem` se vazia. Não grava `data_estoque` (igual ao webapp).
  Future<void> vincularEstoque({
    required String pecaId,
    required String estoqueId,
    DateTime? dataConcretagem,
  }) async {
    final update = <String, dynamic>{
      'estoque_id': estoqueId,
      'status': 'em_estoque',
    };
    if (dataConcretagem == null) {
      update['data_concretagem'] = Formatters.hojeBr();
    }
    await _client.from('obras_pecas').update(update).eq('id', pecaId);
  }

  /// Consulta detalhada de uma peça (obra, catálogo, posição e lote).
  Future<PecaConsulta?> consultar(String codigo) async {
    final c = _sanitize(codigo);
    final row = await _client
        .from('obras_pecas')
        .select(
            '*, pdf_url, obra:obras(id, nome, cor), '
            'catalogo:pecas_catalogo(nome, tipo_calculo, categoria_id, categoria:categorias_peca(nome)), '
            'posicao:mapa_montagem_celulas(coluna, linha, vista:mapa_montagem_vistas(descricao)), '
            'lote:qc_lote_id(id, codigo, fck_mpa, data_concretagem, fornecedor, volume_m3, slump)')
        .or('id.eq.$c,identificador.eq.$c')
        .maybeSingle();
    if (row == null) return null;
    return PecaConsulta.fromMap(Map<String, dynamic>.from(row));
  }

  /// Busca parcial por identificador (modo manual da consulta).
  Future<List<Map<String, dynamic>>> buscarPecasManual(String termo) async {
    final rows = await _client
        .from('obras_pecas')
        .select('id, identificador, status, obra:obras(nome, cor)')
        .ilike('identificador', '%${_sanitize(termo)}%')
        .order('identificador')
        .limit(20);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> corposProva(String loteId) async {
    final rows = await _client
        .from('qc_corpos_prova')
        .select('id, identificador, data_moldagem, idade_rompimento_dias')
        .eq('lote_id', loteId)
        .order('identificador');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> ensaios(String loteId) async {
    final rows = await _client
        .from('qc_ensaios')
        .select('id, data_ensaio, resistencia_mpa, corpo_prova:qc_corpos_prova(identificador)')
        .eq('lote_id', loteId)
        .order('data_ensaio');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // --- Modo manual do leitor de estoque -------------------------------------
  Future<List<Estoque>> listEstoquesAtivos() async {
    final rows = await _client
        .from('estoques')
        .select('id, nome, pecas_permitidas, categorias_permitidas')
        .eq('ativo', true)
        .neq('nome', Estoque.nomeSistema)
        .order('nome');
    return rows.map((e) => Estoque.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<Map<String, dynamic>>> listObrasAtivas() async {
    final rows = await _client
        .from('obras')
        .select('id, nome')
        .eq('status', 'ativa')
        .order('nome');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> listPecasDaObra(String obraId) async {
    final rows = await _client
        .from('obras_pecas')
        .select('id, identificador, peca_catalogo_id, pecas_catalogo(nome, categoria_id)')
        .eq('obra_id', obraId)
        .order('identificador');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
