import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Outgoing chat messages waiting to be sent (Bible §5.4). `clientMsgId` is
/// the idempotency key reused on every retry, so a flaky network never
/// creates duplicates.
class OutboxMessages extends Table {
  TextColumn get clientMsgId => text()();
  TextColumn get matchId => text()();
  TextColumn get body => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {clientMsgId};
}

@DriftDatabase(tables: [OutboxMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  factory AppDatabase.open() => AppDatabase(
        LazyDatabase(() async {
          final dir = await getApplicationDocumentsDirectory();
          return NativeDatabase.createInBackground(
            File(p.join(dir.path, 'mc.sqlite')),
          );
        }),
      );

  @override
  int get schemaVersion => 1;
}
