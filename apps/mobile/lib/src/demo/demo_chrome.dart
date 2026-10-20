// What the member sees of Demo mode itself: the DEMO ribbon, the floating
// controls button, the controls sheet, and the three pretend screens (store,
// ID capture, sample photos). The product's own screens are untouched.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/app.dart';
import 'package:marriage_connect/src/core/illustrations/sample_avatar.dart';
import 'package:marriage_connect/src/demo/demo_controller.dart';
import 'package:marriage_connect/src/demo/demo_devices.dart';
import 'package:marriage_connect/src/demo/demo_world.dart';
import 'package:marriage_connect/src/features/shell/shell_routes.dart';

/// The demo app: the real [App] inside the controller's current container,
/// plus the ribbon and controls. [showChrome] is false only in tests that
/// compare screenshots with the real app.
class DemoHost extends StatefulWidget {
  const DemoHost({required this.controller, this.showChrome = true, super.key});

  final DemoController controller;
  final bool showChrome;

  @override
  State<DemoHost> createState() => _DemoHostState();
}

class _DemoHostState extends State<DemoHost> {
  DemoController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    c.ui
      ..capture = _capture
      ..store = _store
      ..samplePhoto = _samplePhoto;
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    c.ui
      ..capture = null
      ..store = null
      ..samplePhoto = null;
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  BuildContext? get _navContext => shellRootNavigatorKey.currentContext;

  Future<bool> _capture(Duration total) async {
    final ctx = _navContext;
    if (ctx == null) return true;
    return await showDialog<bool>(
          context: ctx,
          barrierDismissible: false,
          builder: (_) => _CaptureDialog(total: total),
        ) ??
        false;
  }

  Future<bool?> _store(String productId) async {
    final ctx = _navContext;
    if (ctx == null) return null;
    return showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Simulated store'),
        content: Text(
          'This stands in for the Play Store / App Store purchase sheet.\n\n'
          'Product: $productId\nNo money moves in Demo mode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Buy'),
          ),
        ],
      ),
    );
  }

  Future<String?> _samplePhoto() async {
    final ctx = _navContext;
    if (ctx == null) return demoSamplePhotoSeeds.first;
    return showModalBottomSheet<String>(
      context: ctx,
      builder: (_) => _SamplePhotos(woman: c.world.viewerIsWoman),
    );
  }

  Widget _wrap(BuildContext context, Widget? child) {
    final mq = MediaQuery.of(context);
    final Widget app = MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(c.view.textScale)),
      child: child ?? const SizedBox.shrink(),
    );
    if (!widget.showChrome) return app;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        Positioned.fill(child: app),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: _ribbonWidth,
          child: _Ribbon(onTap: () => showDemoControls(c)),
        ),
        _FloatingDemoButton(onTap: () => showDemoControls(c)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!c.ready) {
      return const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Colors.white,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return UncontrolledProviderScope(
      key: ValueKey(c.generation),
      container: c.container,
      child: App(
        builder: _wrap,
        themeMode: c.view.dark ? ThemeMode.dark : ThemeMode.system,
      ),
    );
  }
}

/// Opens the controls sheet over the app (no-op before the app is built).
Future<void> showDemoControls(DemoController c) async {
  final ctx = shellRootNavigatorKey.currentContext;
  if (ctx == null) return;
  await showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DemoControlsSheet(controller: c),
  );
}

const _demoOrange = Color(0xFFD9480F);
const _ribbonWidth = 14.0;

/// A thin, always-visible strip down the right edge (inside the gutter every
/// screen leaves, so it never covers a button): "DEMO". Tap it for controls.
class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Demo mode, sample data. Open demo controls',
      child: Material(
        key: const Key('demo-ribbon'),
        color: _demoOrange,
        child: InkWell(
          onTap: onTap,
          child: const ExcludeSemantics(
            child: RotatedBox(
              quarterTurns: 3,
              child: Center(
                child: Text(
                  'DEMO  ·  SAMPLE DATA  ·  TAP FOR CONTROLS',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    letterSpacing: 1.2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small round handle on the right edge (drag it out of the way).
class _FloatingDemoButton extends StatefulWidget {
  const _FloatingDemoButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_FloatingDemoButton> createState() => _FloatingDemoButtonState();
}

class _FloatingDemoButtonState extends State<_FloatingDemoButton> {
  Offset _drag = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Positioned(
      right: _ribbonWidth + 4 - _drag.dx,
      top: size.height * 0.4 + _drag.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _drag += d.delta),
        child: Semantics(
          button: true,
          label: 'Demo controls',
          child: Material(
            key: const Key('demo-controls-button'),
            color: _demoOrange.withValues(alpha: 0.92),
            elevation: 4,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
              child: const SizedBox.square(
                dimension: 40,
                child: Icon(Icons.tune, size: 20, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scenario jumps and toggles. Jumps reset the world and restart the router.
class DemoControlsSheet extends StatelessWidget {
  const DemoControlsSheet({required this.controller, super.key});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final cfg = controller.config;
        final t = Theme.of(context);
        Widget header(String s) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(s, style: t.textTheme.titleSmall),
            );
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Demo controls', style: t.textTheme.titleLarge),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    'Nothing here is real: no server, no SMS, no ID check, '
                    'no money. Jumping resets everything.',
                  ),
                ),
                header('Start from'),
                for (final s in DemoScenario.values)
                  ListTile(
                    key: Key('demo-scenario-${s.name}'),
                    dense: true,
                    leading: Icon(
                      s == controller.scenario
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(s.label),
                    onTap: () {
                      Navigator.of(context).pop();
                      unawaited(controller.jump(s));
                    },
                  ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.restart_alt),
                  title: const Text('Restart this scenario'),
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(controller.restart());
                  },
                ),
                header('Network'),
                SwitchListTile(
                  key: const Key('demo-slow'),
                  dense: true,
                  title: const Text('Slow network (+2.5 s per request)'),
                  value: cfg.slowNetwork,
                  onChanged: (v) => controller.setSlowNetwork(value: v),
                ),
                SwitchListTile(
                  key: const Key('demo-offline'),
                  dense: true,
                  title: const Text('Offline'),
                  value: cfg.offline,
                  onChanged: (v) => controller.setOffline(value: v),
                ),
                SwitchListTile(
                  key: const Key('demo-fail-next'),
                  dense: true,
                  title: const Text('Fail the next request (server error)'),
                  value: cfg.failNext,
                  onChanged: (v) => controller.armFailNext(value: v),
                ),
                header('Identity check'),
                SwitchListTile(
                  dense: true,
                  title: const Text('Next ID check is refused'),
                  value: cfg.failNextVerification,
                  onChanged: (v) => controller.armVerificationFailure(value: v),
                ),
                _chips<int>(
                  'Result arrives after',
                  const [(2, '2 s'), (6, '6 s'), (20, '20 s')],
                  cfg.verificationDelay.inSeconds,
                  (v) => controller.setVerificationDelay(Duration(seconds: v)),
                ),
                header('Looks'),
                _chips<double>(
                  'Text size',
                  const [(1.0, '100%'), (1.5, '150%'), (2.0, '200%')],
                  controller.view.textScale,
                  controller.setTextScale,
                  key: const Key('demo-text-size'),
                ),
                SwitchListTile(
                  key: const Key('demo-dark'),
                  dense: true,
                  title: const Text('Dark mode'),
                  value: controller.view.dark,
                  onChanged: controller.setDark,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A label and a row of choices that wraps (a segmented control would
/// overflow at 200% text).
Widget _chips<T>(
  String title,
  List<(T, String)> options,
  T selected,
  void Function(T) onSelected, {
  Key? key,
}) {
  return Padding(
    key: key,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        Wrap(
          spacing: 8,
          children: [
            for (final (value, label) in options)
              ChoiceChip(
                label: Text(label),
                selected: value == selected,
                onSelected: (_) => onSelected(value),
              ),
          ],
        ),
      ],
    ),
  );
}

class _CaptureDialog extends StatefulWidget {
  const _CaptureDialog({required this.total});
  final Duration total;

  @override
  State<_CaptureDialog> createState() => _CaptureDialogState();
}

class _CaptureDialogState extends State<_CaptureDialog> {
  late final Stopwatch _watch = Stopwatch()..start();
  Timer? _timer;

  static const _steps = [
    'Reading your ID…',
    'Taking a selfie…',
    'Sending it safely…',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_watch.elapsed >= widget.total) {
        _timer?.cancel();
        if (mounted) Navigator.of(context).pop(true);
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.total.inMilliseconds == 0
        ? 1.0
        : (_watch.elapsedMilliseconds / widget.total.inMilliseconds)
            .clamp(0.0, 1.0);
    return AlertDialog(
      title: const Text('Demo: simulated ID check'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The real app opens the ID scanner and the selfie camera here. '
            'In Demo mode this just waits a moment.',
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: p),
          const SizedBox(height: 8),
          Text(_steps[(p * (_steps.length - 0.001)).floor()]),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _SamplePhotos extends StatelessWidget {
  const _SamplePhotos({required this.woman});
  final bool woman;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a sample photo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text('Demo mode has no camera or gallery.'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final seed in demoSamplePhotoSeeds)
                  InkWell(
                    key: Key('sample-photo-$seed'),
                    onTap: () => Navigator.of(context).pop(seed),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SampleAvatar(seed: seed, woman: woman),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
