import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

/// Browser build of the demo database: sqlite compiled to WebAssembly, held
/// in memory. `web/sqlite3.wasm` is copied there by `tool/serve_demo_web.sh`.
QueryExecutor openDemoDatabase() => LazyDatabase(() async {
      final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
      sqlite3.registerVirtualFileSystem(
        InMemoryFileSystem(),
        makeDefault: true,
      );
      return WasmDatabase.inMemory(sqlite3);
    });
