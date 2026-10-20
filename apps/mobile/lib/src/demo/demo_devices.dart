// Everything that would touch hardware or a vendor SDK, replaced for Demo
// mode: push, the app store, the ID + selfie capture, the photo picker, the
// voice recorder / player, SMS autofill. Each one asks the controls UI
// (`DemoUi`) when there is a screen to ask on, and otherwise answers on its
// own, so the same classes also run headless in tests.
import 'dart:async';

import 'package:marriage_connect/src/demo/demo_world.dart';
import 'package:marriage_connect/src/features/chat/data/media_services.dart';
import 'package:marriage_connect/src/features/membership/data/purchase_gateway.dart';
import 'package:marriage_connect/src/features/notifications/domain/push_gateway.dart';
import 'package:marriage_connect/src/features/profile/data/photo_pipeline.dart';
import 'package:marriage_connect/src/features/profile/data/profile_models.dart';
import 'package:marriage_connect/src/features/verification/data/identity_capture.dart';
import 'package:marriage_connect/src/features/verification/data/verification_models.dart';

/// The screens Demo mode can put in front of the member (a pretend store
/// sheet, a pretend ID capture, a sample-photo chooser). Null members mean
/// "no screen": the device fakes then decide by themselves.
class DemoUi {
  /// Shows the capture; true = finished, false = the member backed out.
  Future<bool> Function(Duration total)? capture;

  /// Shows the store sheet; true = buy, false = cancel, null = not asked.
  Future<bool?> Function(String productId)? store;

  /// Lets the member pick one of the built-in sample photos; returns its
  /// seed, or null when they cancel.
  Future<String?> Function()? samplePhoto;
}

const demoSamplePhotoSeeds = <String>[
  'sample-photo-1',
  'sample-photo-2',
  'sample-photo-3',
  'sample-photo-4',
  'sample-photo-5',
  'sample-photo-6',
];

/// Push: available, permission is granted when asked, nothing arrives.
class DemoPushGateway implements PushGateway {
  PushPermission _permission = PushPermission.notDetermined;
  final _opened = StreamController<PushMessageData>.broadcast();
  final _foreground = StreamController<PushMessageData>.broadcast();

  /// Pretend a push arrived in the foreground (for tests / future controls).
  void simulateForeground(PushMessageData m) => _foreground.add(m);

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<PushPermission> permission() async => _permission;

  @override
  Future<PushPermission> requestPermission() async =>
      _permission = PushPermission.granted;

  @override
  Future<String?> token() async => 'demo-push-token';

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Stream<PushMessageData> get opened => _opened.stream;

  @override
  Stream<PushMessageData> get foreground => _foreground.stream;

  @override
  Future<PushMessageData?> initialMessage() async => null;

  @override
  Future<void> deleteToken() async {}
}

/// The app store, simulated: a sheet that buys or cancels, then the normal
/// server verification (`/billing/store/verify`) grants the plan.
class DemoPurchaseGateway implements PurchaseGateway {
  DemoPurchaseGateway({
    required this.world,
    required this.ui,
    this.platform = 'android',
  });

  final DemoWorld world;
  final DemoUi ui;
  final String platform;
  final _events = StreamController<PurchaseEvent>.broadcast();
  var _n = 0;

  @override
  Future<bool> isAvailable() async => true;

  /// Empty: the paywall then shows the server's own UGX price.
  @override
  Future<Map<String, String>> prices(Set<String> productIds) async => {};

  @override
  Stream<PurchaseEvent> get events => _events.stream;

  PurchaseProof _proof(String productId, {bool restored = false}) =>
      PurchaseProof(
        platform: platform,
        productId: productId,
        verificationData: 'demo-purchase-${++_n}',
        restored: restored,
      );

  @override
  Future<void> buy(String productId, {String? accountId}) async {
    final ask = ui.store;
    final buys = ask == null
        ? world.config.storeBuys
        : (await ask(productId) ?? world.config.storeBuys);
    // The store answers on its own schedule, like the real one.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (_events.isClosed) return;
        _events.add(
          buys
              ? PurchaseSucceeded(_proof(productId))
              : const PurchaseCancelled(),
        );
      }),
    );
  }

  @override
  Future<void> restore({String? accountId}) async {
    if (world.entitlementState != 'member') return;
    _events.add(PurchaseSucceeded(_proof('membership_1m', restored: true)));
  }

  @override
  Future<void> complete(PurchaseProof proof) async {}
}

/// The ID + selfie capture, simulated: a short "scanning" screen, then done.
class DemoIdentityCaptureLauncher implements IdentityCaptureLauncher {
  DemoIdentityCaptureLauncher({required this.world, required this.ui});

  final DemoWorld world;
  final DemoUi ui;

  @override
  Future<CaptureOutcome> capture(VerificationSession session) async {
    final total = world.config.captureDelay;
    final show = ui.capture;
    if (show == null) {
      await Future<void>.delayed(total);
      return CaptureOutcome.completed;
    }
    return await show(total)
        ? CaptureOutcome.completed
        : CaptureOutcome.cancelled;
  }
}

/// Profile photos come from a few built-in drawn photos, not the camera.
class DemoPhotoPipeline implements PhotoPipeline {
  DemoPhotoPipeline({required this.world, required this.ui});

  final DemoWorld world;
  final DemoUi ui;
  var _next = 0;

  @override
  Future<PreparedPhoto?> pick(PhotoSource source) async {
    final choose = ui.samplePhoto;
    final seed = choose == null
        ? demoSamplePhotoSeeds[_next++ % demoSamplePhotoSeeds.length]
        : await choose();
    if (seed == null) return null; // cancelled
    world.queuePhotoSeed(seed);
    return const PreparedPhoto(bytes: [1, 2, 3], mime: 'image/jpeg');
  }
}

/// Chat photos: the same built-in samples.
class DemoImagePickerService implements ImagePickerService {
  DemoImagePickerService({required this.ui});
  final DemoUi ui;

  @override
  Future<PickedMedia?> pick({required bool camera}) async {
    final choose = ui.samplePhoto;
    if (choose != null && await choose() == null) return null;
    return const PickedMedia(
      path: 'demo://sample-photo',
      mime: 'image/jpeg',
      bytes: 2048,
    );
  }
}

/// "Uploads" instantly: registers the media with the demo world.
class DemoMediaUploader implements MediaUploader {
  DemoMediaUploader(this.world);
  final DemoWorld world;

  @override
  Future<String> upload({
    required String purpose,
    required PickedMedia file,
    void Function(String mediaId)? onUploaded,
  }) async {
    final id = world.registerChatMedia(
      image: purpose == 'chat_image',
      durationMs: file.durationMs,
    );
    onUploaded?.call(id);
    return id;
  }

  @override
  Future<void> awaitReady(String mediaId) async {}
}

/// A voice note of whatever length the member held the button for.
class DemoVoiceRecorder implements VoiceRecorder {
  Stopwatch? _watch;

  @override
  Future<bool> start() async {
    _watch = Stopwatch()..start();
    return true;
  }

  @override
  Future<PickedMedia?> stop() async {
    final ms = _watch?.elapsedMilliseconds ?? 0;
    _watch = null;
    return PickedMedia(
      path: 'demo://voice-note',
      mime: 'audio/mp4',
      bytes: 4096,
      durationMs: ms < 1000 ? 1000 : ms,
    );
  }

  @override
  Future<void> cancel() async => _watch = null;
}

/// "Plays" a voice note for a couple of seconds (there is no audio to hear).
class DemoVoicePlayer implements VoicePlayer {
  final _playing = StreamController<bool>.broadcast();
  Timer? _timer;

  @override
  Future<void> play(String url) async {
    _timer?.cancel();
    _playing.add(true);
    _timer = Timer(const Duration(seconds: 3), () => _playing.add(false));
  }

  @override
  Future<void> pause() async {
    _timer?.cancel();
    _playing.add(false);
  }

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _playing.close();
  }
}
