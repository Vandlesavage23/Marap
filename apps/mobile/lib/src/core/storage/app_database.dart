import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/storage/app_database_open.dart';

part 'app_database.g.dart';

/// Outgoing chat messages waiting to be sent (Bible §5.4). `clientMsgId` is
/// the idempotency key reused on every retry, so a flaky network never
/// creates duplicates.
class OutboxMessages extends Table {
  TextColumn get clientMsgId => text()();
  TextColumn get matchId => text()();
  // Empty for photo / voice rows.
  TextColumn get body => text()();
  // text | image | voice. Media rows keep a durable copy of the file
  // (`mediaPath`) so a send queued offline survives a restart; `mediaId` is set
  // once the upload finished, so a lost send response never re-uploads.
  TextColumn get kind => text().withDefault(const Constant('text'))();
  TextColumn get mediaPath => text().nullable()();
  TextColumn get mediaMime => text().nullable()();
  IntColumn get mediaBytes => integer().nullable()();
  IntColumn get mediaDurationMs => integer().nullable()();
  TextColumn get mediaId => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  // Set when the server permanently refused the message (shown as "not sent").
  TextColumn get failedCode => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {clientMsgId};
}

/// Matches cache (Bible §5.4 "Offline"). The whole table is replaced on every
/// successful sync, so ended matches disappear. `position` keeps server order.
class CachedMatches extends Table {
  TextColumn get id => text()();
  TextColumn get memberId => text()(); // the other member's public profile id
  TextColumn get displayName => text()();
  IntColumn get age => integer().nullable()();
  TextColumn get district => text().withDefault(const Constant(''))();
  TextColumn get maritalStatusLabel => text().nullable()();
  BoolColumn get photoVerified =>
      boolean().withDefault(const Constant(false))();
  TextColumn get photoUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Chat history cache so a conversation can be read offline. Media URLs are
/// signed and short-lived, so only the metadata JSON is kept (`mediaJson`).
class CachedMessages extends Table {
  TextColumn get id => text()();
  TextColumn get matchId => text()();
  TextColumn get clientMsgId => text().nullable()();
  TextColumn get sender => text()(); // me | them | system
  TextColumn get kind => text()(); // text | image | voice | system
  TextColumn get body => text().nullable()();
  TextColumn get mediaJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();
  BoolColumn get safetyTip => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [OutboxMessages, CachedMatches, CachedMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The on-device database file (the app); a browser has no such file, so
  /// the web build never calls this (Demo mode brings its own in-memory one).
  factory AppDatabase.open() => AppDatabase(openAppDatabaseFile());

  /// Sign-out: drops the matches and chat-history caches. (The outbox is
  /// cleared by `OutboxRepository.clearAll`, which also frees queued media.)
  Future<void> clearCaches() => transaction(() async {
        await delete(cachedMatches).go();
        await delete(cachedMessages).go();
      });

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(cachedMatches);
            await m.createTable(cachedMessages);
          }
          if (from < 3) {
            // Offline photo / voice sends (MC-081).
            await m.addColumn(outboxMessages, outboxMessages.kind);
            await m.addColumn(outboxMessages, outboxMessages.mediaPath);
            await m.addColumn(outboxMessages, outboxMessages.mediaMime);
            await m.addColumn(outboxMessages, outboxMessages.mediaBytes);
            await m.addColumn(outboxMessages, outboxMessages.mediaDurationMs);
            await m.addColumn(outboxMessages, outboxMessages.mediaId);
          }
        },
      );
}

/// One database for the whole app. Closed with the container.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});
