import 'package:drift/drift.dart';

/// Browsers have no database file. The real app is a phone app; only Demo
/// mode runs on the web, and it supplies its own in-memory database.
QueryExecutor openAppDatabaseFile() =>
    throw UnsupportedError('The on-device database needs Android or iOS.');
