import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screenshot support for UX audits: loads real fonts (the test default, Ahem, renders text as boxes) and writes
/// PNGs of the widget tree to `$SHOT_DIR` (default /tmp/shots). Run with `flutter test test/journeys`.
String get shotDir => Platform.environment['SHOT_DIR'] ?? '/tmp/shots';

Future<void> loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String f) async =>
      ByteData.sublistView(Uint8List.fromList(await File('$dir/$f').readAsBytes()));
  for (final family in ['McSans', 'McSerif', 'Roboto']) {
    final loader = FontLoader(family)
      ..addFont(read('Roboto-Regular.ttf'))
      ..addFont(read('Roboto-Medium.ttf'))
      ..addFont(read('Roboto-Bold.ttf'));
    await loader.load();
  }
  await (FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'))).load();
}

/// Phone-sized surface (390x844 logical px at 2x).
void phoneSurface(WidgetTester t, {double textScale = 1}) {
  t.view
    ..physicalSize = const Size(390 * 2, 844 * 2)
    ..devicePixelRatio = 2;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    t.view.reset();
    t.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

final _boundaryKey = GlobalKey();

/// Wrap the app in this to make it capturable.
Widget capturable(Widget child) => RepaintBoundary(key: _boundaryKey, child: child);

Future<void> snap(WidgetTester t, String name) async {
  await t.runAsync(() async {
    final boundary = _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final file = File('$shotDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes.buffer.asUint8List());
  });
}
