// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $OutboxMessagesTable extends OutboxMessages
    with TableInfo<$OutboxMessagesTable, OutboxMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientMsgIdMeta =
      const VerificationMeta('clientMsgId');
  @override
  late final GeneratedColumn<String> clientMsgId = GeneratedColumn<String>(
      'client_msg_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _matchIdMeta =
      const VerificationMeta('matchId');
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
      'match_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _failedCodeMeta =
      const VerificationMeta('failedCode');
  @override
  late final GeneratedColumn<String> failedCode = GeneratedColumn<String>(
      'failed_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [clientMsgId, matchId, body, attempts, failedCode, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_messages';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_msg_id')) {
      context.handle(
          _clientMsgIdMeta,
          clientMsgId.isAcceptableOrUnknown(
              data['client_msg_id']!, _clientMsgIdMeta));
    } else if (isInserting) {
      context.missing(_clientMsgIdMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(_matchIdMeta,
          matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta));
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('failed_code')) {
      context.handle(
          _failedCodeMeta,
          failedCode.isAcceptableOrUnknown(
              data['failed_code']!, _failedCodeMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientMsgId};
  @override
  OutboxMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxMessage(
      clientMsgId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_msg_id'])!,
      matchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}match_id'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      failedCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}failed_code']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $OutboxMessagesTable createAlias(String alias) {
    return $OutboxMessagesTable(attachedDatabase, alias);
  }
}

class OutboxMessage extends DataClass implements Insertable<OutboxMessage> {
  final String clientMsgId;
  final String matchId;
  final String body;
  final int attempts;
  final String? failedCode;
  final DateTime createdAt;
  const OutboxMessage(
      {required this.clientMsgId,
      required this.matchId,
      required this.body,
      required this.attempts,
      this.failedCode,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_msg_id'] = Variable<String>(clientMsgId);
    map['match_id'] = Variable<String>(matchId);
    map['body'] = Variable<String>(body);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || failedCode != null) {
      map['failed_code'] = Variable<String>(failedCode);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxMessagesCompanion toCompanion(bool nullToAbsent) {
    return OutboxMessagesCompanion(
      clientMsgId: Value(clientMsgId),
      matchId: Value(matchId),
      body: Value(body),
      attempts: Value(attempts),
      failedCode: failedCode == null && nullToAbsent
          ? const Value.absent()
          : Value(failedCode),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxMessage(
      clientMsgId: serializer.fromJson<String>(json['clientMsgId']),
      matchId: serializer.fromJson<String>(json['matchId']),
      body: serializer.fromJson<String>(json['body']),
      attempts: serializer.fromJson<int>(json['attempts']),
      failedCode: serializer.fromJson<String?>(json['failedCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientMsgId': serializer.toJson<String>(clientMsgId),
      'matchId': serializer.toJson<String>(matchId),
      'body': serializer.toJson<String>(body),
      'attempts': serializer.toJson<int>(attempts),
      'failedCode': serializer.toJson<String?>(failedCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxMessage copyWith(
          {String? clientMsgId,
          String? matchId,
          String? body,
          int? attempts,
          Value<String?> failedCode = const Value.absent(),
          DateTime? createdAt}) =>
      OutboxMessage(
        clientMsgId: clientMsgId ?? this.clientMsgId,
        matchId: matchId ?? this.matchId,
        body: body ?? this.body,
        attempts: attempts ?? this.attempts,
        failedCode: failedCode.present ? failedCode.value : this.failedCode,
        createdAt: createdAt ?? this.createdAt,
      );
  OutboxMessage copyWithCompanion(OutboxMessagesCompanion data) {
    return OutboxMessage(
      clientMsgId:
          data.clientMsgId.present ? data.clientMsgId.value : this.clientMsgId,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      body: data.body.present ? data.body.value : this.body,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      failedCode:
          data.failedCode.present ? data.failedCode.value : this.failedCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxMessage(')
          ..write('clientMsgId: $clientMsgId, ')
          ..write('matchId: $matchId, ')
          ..write('body: $body, ')
          ..write('attempts: $attempts, ')
          ..write('failedCode: $failedCode, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(clientMsgId, matchId, body, attempts, failedCode, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxMessage &&
          other.clientMsgId == this.clientMsgId &&
          other.matchId == this.matchId &&
          other.body == this.body &&
          other.attempts == this.attempts &&
          other.failedCode == this.failedCode &&
          other.createdAt == this.createdAt);
}

class OutboxMessagesCompanion extends UpdateCompanion<OutboxMessage> {
  final Value<String> clientMsgId;
  final Value<String> matchId;
  final Value<String> body;
  final Value<int> attempts;
  final Value<String?> failedCode;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const OutboxMessagesCompanion({
    this.clientMsgId = const Value.absent(),
    this.matchId = const Value.absent(),
    this.body = const Value.absent(),
    this.attempts = const Value.absent(),
    this.failedCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxMessagesCompanion.insert({
    required String clientMsgId,
    required String matchId,
    required String body,
    this.attempts = const Value.absent(),
    this.failedCode = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : clientMsgId = Value(clientMsgId),
        matchId = Value(matchId),
        body = Value(body),
        createdAt = Value(createdAt);
  static Insertable<OutboxMessage> custom({
    Expression<String>? clientMsgId,
    Expression<String>? matchId,
    Expression<String>? body,
    Expression<int>? attempts,
    Expression<String>? failedCode,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientMsgId != null) 'client_msg_id': clientMsgId,
      if (matchId != null) 'match_id': matchId,
      if (body != null) 'body': body,
      if (attempts != null) 'attempts': attempts,
      if (failedCode != null) 'failed_code': failedCode,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxMessagesCompanion copyWith(
      {Value<String>? clientMsgId,
      Value<String>? matchId,
      Value<String>? body,
      Value<int>? attempts,
      Value<String?>? failedCode,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return OutboxMessagesCompanion(
      clientMsgId: clientMsgId ?? this.clientMsgId,
      matchId: matchId ?? this.matchId,
      body: body ?? this.body,
      attempts: attempts ?? this.attempts,
      failedCode: failedCode ?? this.failedCode,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientMsgId.present) {
      map['client_msg_id'] = Variable<String>(clientMsgId.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (failedCode.present) {
      map['failed_code'] = Variable<String>(failedCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxMessagesCompanion(')
          ..write('clientMsgId: $clientMsgId, ')
          ..write('matchId: $matchId, ')
          ..write('body: $body, ')
          ..write('attempts: $attempts, ')
          ..write('failedCode: $failedCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OutboxMessagesTable outboxMessages = $OutboxMessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [outboxMessages];
}

typedef $$OutboxMessagesTableCreateCompanionBuilder = OutboxMessagesCompanion
    Function({
  required String clientMsgId,
  required String matchId,
  required String body,
  Value<int> attempts,
  Value<String?> failedCode,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$OutboxMessagesTableUpdateCompanionBuilder = OutboxMessagesCompanion
    Function({
  Value<String> clientMsgId,
  Value<String> matchId,
  Value<String> body,
  Value<int> attempts,
  Value<String?> failedCode,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$OutboxMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxMessagesTable> {
  $$OutboxMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientMsgId => $composableBuilder(
      column: $table.clientMsgId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get matchId => $composableBuilder(
      column: $table.matchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get failedCode => $composableBuilder(
      column: $table.failedCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$OutboxMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxMessagesTable> {
  $$OutboxMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientMsgId => $composableBuilder(
      column: $table.clientMsgId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get matchId => $composableBuilder(
      column: $table.matchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get failedCode => $composableBuilder(
      column: $table.failedCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$OutboxMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxMessagesTable> {
  $$OutboxMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientMsgId => $composableBuilder(
      column: $table.clientMsgId, builder: (column) => column);

  GeneratedColumn<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get failedCode => $composableBuilder(
      column: $table.failedCode, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxMessagesTable,
    OutboxMessage,
    $$OutboxMessagesTableFilterComposer,
    $$OutboxMessagesTableOrderingComposer,
    $$OutboxMessagesTableAnnotationComposer,
    $$OutboxMessagesTableCreateCompanionBuilder,
    $$OutboxMessagesTableUpdateCompanionBuilder,
    (
      OutboxMessage,
      BaseReferences<_$AppDatabase, $OutboxMessagesTable, OutboxMessage>
    ),
    OutboxMessage,
    PrefetchHooks Function()> {
  $$OutboxMessagesTableTableManager(
      _$AppDatabase db, $OutboxMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientMsgId = const Value.absent(),
            Value<String> matchId = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> failedCode = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxMessagesCompanion(
            clientMsgId: clientMsgId,
            matchId: matchId,
            body: body,
            attempts: attempts,
            failedCode: failedCode,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientMsgId,
            required String matchId,
            required String body,
            Value<int> attempts = const Value.absent(),
            Value<String?> failedCode = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxMessagesCompanion.insert(
            clientMsgId: clientMsgId,
            matchId: matchId,
            body: body,
            attempts: attempts,
            failedCode: failedCode,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OutboxMessagesTable, OutboxMessage>(table),
                    BaseReferences<_$AppDatabase, $OutboxMessagesTable,
                        OutboxMessage>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxMessagesTable,
    OutboxMessage,
    $$OutboxMessagesTableFilterComposer,
    $$OutboxMessagesTableOrderingComposer,
    $$OutboxMessagesTableAnnotationComposer,
    $$OutboxMessagesTableCreateCompanionBuilder,
    $$OutboxMessagesTableUpdateCompanionBuilder,
    (
      OutboxMessage,
      BaseReferences<_$AppDatabase, $OutboxMessagesTable, OutboxMessage>
    ),
    OutboxMessage,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OutboxMessagesTableTableManager get outboxMessages =>
      $$OutboxMessagesTableTableManager(_db, _db.outboxMessages);
}
