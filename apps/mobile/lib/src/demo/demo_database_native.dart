import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// An in-memory database for the demo's offline copies (matches, chat
/// history, outbox): gone when the app closes, never written to disk.
QueryExecutor openDemoDatabase() => NativeDatabase.memory();
