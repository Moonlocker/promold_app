import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/ausencia.dart';
import '../models/cargo.dart';
import '../models/funcionario.dart';
import '../models/setor.dart';

/// Módulo Equipe: funcionários, setores, cargos e ausências.
class EquipeRepository {
  EquipeRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  // ------------------------------------------------------------ Funcionários
  Future<List<Funcionario>> listFuncionarios() async {
    final rows = await _client
        .from('funcionarios')
        .select('*, cargos(nome), setores(nome)')
        .order('nome');
    return rows
        .map((e) => Funcionario.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> createFuncionario(Map<String, dynamic> data) async {
    await _client.from('funcionarios').insert(data);
  }

  Future<void> updateFuncionario(String id, Map<String, dynamic> data) async {
    await _client.from('funcionarios').update(data).eq('id', id);
  }

  Future<void> deleteFuncionario(String id) async {
    await _client.from('funcionarios').delete().eq('id', id);
  }

  Future<String> uploadFotoFuncionario({
    required List<int> bytes,
    required String extensao,
  }) async {
    final path = 'funcionario-${DateTime.now().millisecondsSinceEpoch}.$extensao';
    await _client.storage.from('funcionarios').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: 'image/$extensao'),
        );
    return _client.storage.from('funcionarios').getPublicUrl(path);
  }

  // ------------------------------------------------------------------ Setores
  Future<List<Setor>> listSetores() async {
    final rows = await _client.from('setores').select().order('nome');
    return rows.map((e) => Setor.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> createSetor(Map<String, dynamic> data) async {
    await _client.from('setores').insert(data);
  }

  Future<void> updateSetor(String id, Map<String, dynamic> data) async {
    await _client.from('setores').update(data).eq('id', id);
  }

  Future<void> deleteSetor(String id) async {
    await _client.from('setores').delete().eq('id', id);
  }

  // ------------------------------------------------------------------- Cargos
  Future<List<Cargo>> listCargos() async {
    final rows =
        await _client.from('cargos').select('*, setores(nome)').order('nome');
    return rows.map((e) => Cargo.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> createCargo(Map<String, dynamic> data) async {
    await _client.from('cargos').insert(data);
  }

  Future<void> updateCargo(String id, Map<String, dynamic> data) async {
    await _client.from('cargos').update(data).eq('id', id);
  }

  Future<void> deleteCargo(String id) async {
    await _client.from('cargos').delete().eq('id', id);
  }

  // --------------------------------------------------------------- Ausências
  Future<List<Ausencia>> listAusencias() async {
    final rows = await _client
        .from('ausencias')
        .select('*, funcionarios(nome)')
        .order('data_inicio', ascending: false);
    return rows
        .map((e) => Ausencia.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Ausencia>> listAusenciasByFuncionario(String funcionarioId) async {
    final rows = await _client
        .from('ausencias')
        .select()
        .eq('funcionario_id', funcionarioId)
        .order('data_inicio', ascending: false);
    return rows
        .map((e) => Ausencia.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> createAusencia(Map<String, dynamic> data) async {
    await _client.from('ausencias').insert(data);
  }

  Future<void> updateAusencia(String id, Map<String, dynamic> data) async {
    await _client.from('ausencias').update(data).eq('id', id);
  }

  Future<void> deleteAusencia(String id) async {
    await _client.from('ausencias').delete().eq('id', id);
  }
}
