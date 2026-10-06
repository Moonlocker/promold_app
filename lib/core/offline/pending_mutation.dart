import 'dart:convert';

/// Operações suportadas na fila de sincronização (outbox).
enum MutationOp { insert, upsert, update, delete }

MutationOp mutationOpFrom(String value) => MutationOp.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MutationOp.update,
    );

/// Mutação pendente de sincronização com o Supabase.
///
/// Guardada localmente quando o aparelho está offline e reenviada assim que a
/// conexão volta (ver `SyncService`).
class PendingMutation {
  const PendingMutation({
    this.id,
    required this.table,
    required this.op,
    this.values,
    this.match,
    this.onConflict,
    required this.createdAt,
    this.attempts = 0,
  });

  final int? id;
  final String table;
  final MutationOp op;
  final Map<String, dynamic>? values;
  final Map<String, dynamic>? match;
  final String? onConflict;
  final DateTime createdAt;
  final int attempts;

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'table_name': table,
        'op': op.name,
        'payload': values == null ? null : jsonEncode(values),
        'match_json': match == null ? null : jsonEncode(match),
        'on_conflict': onConflict,
        'created_at': createdAt.millisecondsSinceEpoch,
        'attempts': attempts,
      };

  factory PendingMutation.fromRow(Map<String, Object?> row) => PendingMutation(
        id: row['id'] as int?,
        table: row['table_name'] as String,
        op: mutationOpFrom(row['op'] as String),
        values: row['payload'] == null
            ? null
            : Map<String, dynamic>.from(
                jsonDecode(row['payload'] as String) as Map,
              ),
        match: row['match_json'] == null
            ? null
            : Map<String, dynamic>.from(
                jsonDecode(row['match_json'] as String) as Map,
              ),
        onConflict: row['on_conflict'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        attempts: (row['attempts'] as int?) ?? 0,
      );
}
