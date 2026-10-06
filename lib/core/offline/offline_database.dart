import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'connectivity.dart';
import 'pending_mutation.dart';

/// Banco local (SQLite) com duas responsabilidades:
///
/// 1. **cache** de leitura — permite abrir telas e consultar dados já vistos
///    mesmo sem internet;
/// 2. **outbox** — fila de mutações feitas offline, reenviadas ao reconectar.
///
/// É opcional: se o banco não puder ser aberto (ex.: testes), todos os métodos
/// degradam com segurança para o modo online, sem quebrar a aplicação.
class OfflineDatabase {
  OfflineDatabase._();
  static final OfflineDatabase instance = OfflineDatabase._();

  Database? _db;
  bool get isReady => _db != null;

  Future<void> init() async {
    if (_db != null) return;
    try {
      final dir = await getDatabasesPath();
      final path = p.join(dir, 'promold_offline.db');
      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE cache ('
            'key TEXT PRIMARY KEY, '
            'data TEXT, '
            'updated_at INTEGER)',
          );
          await db.execute(
            'CREATE TABLE outbox ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'table_name TEXT NOT NULL, '
            'op TEXT NOT NULL, '
            'payload TEXT, '
            'match_json TEXT, '
            'on_conflict TEXT, '
            'created_at INTEGER NOT NULL, '
            'attempts INTEGER NOT NULL DEFAULT 0, '
            'last_error TEXT)',
          );
        },
      );
    } catch (_) {
      _db = null;
    }
  }

  // ------------------------------------------------------------------ cache
  Future<void> writeCache(String key, Object? data) async {
    final db = _db;
    if (db == null) return;
    await db.insert(
      'cache',
      {
        'key': key,
        'data': jsonEncode(data),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Object?> readCache(String key) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query(
      'cache',
      columns: ['data'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['data'] as String);
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> cacheUpdatedAt(String key) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query(
      'cache',
      columns: ['updated_at'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final millis = rows.first['updated_at'] as int?;
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> clearCache() async {
    final db = _db;
    if (db == null) return;
    await db.delete('cache');
  }

  /// Lê do cache quando estiver offline; caso contrário busca no remoto e
  /// atualiza o cache. Se o remoto falhar, faz fallback para o cache.
  Future<List<Map<String, dynamic>>> cachedRows(
    String key,
    Future<List<Map<String, dynamic>>> Function() remote,
  ) async {
    final db = _db;
    if (db != null && !AppConnectivity.instance.isOnline) {
      final cached = await readCache(key);
      if (cached is List) return _asRows(cached);
    }
    try {
      final data = await remote();
      if (db != null) {
        try {
          await writeCache(key, data);
        } catch (_) {}
      }
      return data;
    } catch (_) {
      if (db != null) {
        final cached = await readCache(key);
        if (cached is List) return _asRows(cached);
      }
      rethrow;
    }
  }

  /// Versão de [cachedRows] para um único registro (ou `null`).
  Future<Map<String, dynamic>?> cachedRow(
    String key,
    Future<Map<String, dynamic>?> Function() remote,
  ) async {
    final db = _db;
    if (db != null && !AppConnectivity.instance.isOnline) {
      final cached = await readCache(key);
      if (cached is Map) return Map<String, dynamic>.from(cached);
    }
    try {
      final data = await remote();
      if (db != null && data != null) {
        try {
          await writeCache(key, data);
        } catch (_) {}
      }
      return data;
    } catch (_) {
      if (db != null) {
        final cached = await readCache(key);
        if (cached is Map) return Map<String, dynamic>.from(cached);
      }
      rethrow;
    }
  }

  static List<Map<String, dynamic>> _asRows(Object cached) => (cached as List)
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  // ----------------------------------------------------------------- outbox
  Future<int> enqueue(PendingMutation mutation) async {
    final db = _db;
    if (db == null) return -1;
    return db.insert('outbox', mutation.toRow());
  }

  Future<List<PendingMutation>> pending() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('outbox', orderBy: 'id ASC');
    return rows.map(PendingMutation.fromRow).toList();
  }

  Future<int> pendingCount() async {
    final db = _db;
    if (db == null) return 0;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM outbox');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> removePending(int id) async {
    final db = _db;
    if (db == null) return;
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markAttempt(int id, String error) async {
    final db = _db;
    if (db == null) return;
    await db.rawUpdate(
      'UPDATE outbox SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      [error, id],
    );
  }

  Future<void> clearOutbox() async {
    final db = _db;
    if (db == null) return;
    await db.delete('outbox');
  }
}
