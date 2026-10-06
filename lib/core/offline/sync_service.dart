import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'connectivity.dart';
import 'offline_database.dart';
import 'pending_mutation.dart';

/// Estado observável do sincronizador.
class SyncState {
  const SyncState({
    required this.online,
    required this.pending,
    required this.syncing,
    this.lastSync,
    this.message,
  });

  final bool online;
  final int pending;
  final bool syncing;
  final DateTime? lastSync;
  final String? message;

  static const SyncState initial =
      SyncState(online: true, pending: 0, syncing: false);

  SyncState copyWith({
    bool? online,
    int? pending,
    bool? syncing,
    DateTime? lastSync,
    String? message,
    bool clearMessage = false,
  }) {
    return SyncState(
      online: online ?? this.online,
      pending: pending ?? this.pending,
      syncing: syncing ?? this.syncing,
      lastSync: lastSync ?? this.lastSync,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

/// Executa a fila de mutações pendentes (outbox) contra o Supabase e mantém
/// o estado de sincronização observável pela UI.
class SyncService {
  SyncService({required this.db, required this.client});

  final OfflineDatabase db;
  final SupabaseClient client;

  final StreamController<SyncState> _controller =
      StreamController<SyncState>.broadcast();

  SyncState _state = SyncState.initial;
  SyncState get state => _state;
  Stream<SyncState> get stream => _controller.stream;

  bool _flushing = false;

  Future<void> refreshPending() async {
    final pending = await db.pendingCount();
    _emit(_state.copyWith(pending: pending));
  }

  /// Enfileira uma mutação para sincronizar depois.
  Future<void> enqueue({
    required String table,
    required MutationOp op,
    Map<String, dynamic>? values,
    Map<String, dynamic>? match,
    String? onConflict,
  }) async {
    await db.enqueue(
      PendingMutation(
        table: table,
        op: op,
        values: values,
        match: match,
        onConflict: onConflict,
        createdAt: DateTime.now(),
      ),
    );
    await refreshPending();
  }

  /// Aplica a mutação agora; se falhar (offline), enfileira.
  /// Retorna `true` se foi aplicada remotamente na hora.
  Future<bool> mutate({
    required String table,
    required MutationOp op,
    Map<String, dynamic>? values,
    Map<String, dynamic>? match,
    String? onConflict,
  }) async {
    if (db.isReady && AppConnectivity.instance.isOnline) {
      try {
        await _apply(table, op, values, match, onConflict);
        return true;
      } catch (_) {
        // offline/erro de rede — cai para a fila.
      }
    }
    await enqueue(
      table: table,
      op: op,
      values: values,
      match: match,
      onConflict: onConflict,
    );
    return false;
  }

  /// Processa toda a fila de pendências em ordem de criação.
  Future<void> flush() async {
    if (_flushing || !db.isReady) return;
    _flushing = true;
    _emit(_state.copyWith(syncing: true, clearMessage: true));
    var failed = 0;
    try {
      final ops = await db.pending();
      for (final op in ops) {
        try {
          await _apply(op.table, op.op, op.values, op.match, op.onConflict);
          if (op.id != null) await db.removePending(op.id!);
        } catch (e) {
          failed++;
          if (op.id != null) await db.markAttempt(op.id!, e.toString());
        }
      }
      final pending = await db.pendingCount();
      _emit(
        SyncState(
          online: true,
          pending: pending,
          syncing: false,
          lastSync: DateTime.now(),
          message: failed > 0
              ? '$failed pendência(s) não sincronizada(s)'
              : null,
        ),
      );
    } finally {
      _flushing = false;
    }
  }

  Future<void> _apply(
    String table,
    MutationOp op,
    Map<String, dynamic>? values,
    Map<String, dynamic>? match,
    String? onConflict,
  ) async {
    switch (op) {
      case MutationOp.insert:
        await client.from(table).insert(values!);
      case MutationOp.upsert:
        await client.from(table).upsert(values!, onConflict: onConflict);
      case MutationOp.update:
        await client.from(table).update(values!).match(_matchObject(match));
      case MutationOp.delete:
        await client.from(table).delete().match(_matchObject(match));
    }
  }

  /// `.match()` exige `Map<String, Object>`; ignora valores nulos.
  Map<String, Object> _matchObject(Map<String, dynamic>? match) {
    final result = <String, Object>{};
    match?.forEach((key, value) {
      if (value != null) result[key] = value;
    });
    return result;
  }

  void _emit(SyncState state) {
    _state = state;
    if (!_controller.isClosed) _controller.add(state);
  }

  void dispose() {
    _controller.close();
  }
}
