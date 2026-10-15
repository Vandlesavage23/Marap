import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/auth/session_controller.dart';
import 'package:marriage_connect/src/core/network/providers.dart';
import 'package:marriage_connect/src/core/storage/app_database.dart';
import 'package:marriage_connect/src/features/chat/application/chat_hub.dart';
import 'package:marriage_connect/src/features/chat/data/api_chat_repository.dart';
import 'package:marriage_connect/src/features/chat/data/chat_socket.dart';
import 'package:marriage_connect/src/features/chat/data/media_services.dart';
import 'package:marriage_connect/src/features/chat/data/outbox_repository.dart';
import 'package:marriage_connect/src/features/chat/domain/chat_repository.dart';
import 'package:marriage_connect/src/features/matches/application/matches_controller.dart';

final outboxRepositoryProvider = Provider<OutboxRepository>(
  (ref) => OutboxRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(dioProvider),
  ),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ApiChatRepository(
    ref.watch(dioProvider),
    ref.watch(appDatabaseProvider),
  ),
);

final chatChannelFactoryProvider = Provider<ChatChannelFactory>(
  (ref) => WebSocketChatChannel.new,
);

final chatSocketProvider = Provider<ChatSocketClient>((ref) {
  final env = ref.watch(envProvider);
  final dio = ref.watch(dioProvider);
  final client = ChatSocketClient(
    url: Uri.parse('${env.wsUrl}/ws/chat'),
    factory: ref.watch(chatChannelFactoryProvider),
    token: () => ref.read(tokenStoreProvider).accessToken,
    // Any authenticated call refreshes an expired access token (and signs the
    // user out if the session is really gone).
    refreshSession: () async {
      try {
        await dio.get<void>('/me/entitlements');
      } on Object {
        // handled by the HTTP layer
      }
    },
  );
  ref.onDispose(() => unawaited(client.dispose()));
  return client;
});

/// The realtime hub. Reading it starts the socket; leaving the session stops it.
final chatHubProvider = Provider<ChatHub>((ref) {
  final hub = ChatHub(
    outbox: ref.watch(outboxRepositoryProvider),
    repo: ref.watch(chatRepositoryProvider),
    socket: ref.watch(chatSocketProvider),
  );
  final ended = hub.events.listen((e) {
    if (e is MatchEndedEvent) {
      if (ref.exists(matchesControllerProvider)) {
        unawaited(
          ref.read(matchesControllerProvider.notifier).ended(e.matchId),
        );
      } else {
        unawaited(ref.read(matchesRepositoryProvider).removeLocal(e.matchId));
      }
    }
  });
  ref
    ..listen(sessionProvider, (_, s) {
      if (s == SessionState.signedOut) unawaited(hub.stop());
    })
    ..onDispose(() {
      unawaited(ended.cancel());
      unawaited(hub.dispose());
    });
  hub.start();
  return hub;
});

final socketStatusProvider = StreamProvider<SocketStatus>((ref) async* {
  final hub = ref.watch(chatHubProvider);
  yield hub.status;
  yield* hub.statusChanges;
});

final capabilitiesProvider = FutureProvider.autoDispose<Capabilities>(
  (ref) => ref.watch(chatRepositoryProvider).capabilities(),
);

final imagePickerServiceProvider =
    Provider<ImagePickerService>((ref) => DeviceImagePicker());
final voiceRecorderProvider =
    Provider<VoiceRecorder>((ref) => DeviceVoiceRecorder());

/// One player per voice bubble (created on first play, disposed with it).
final voicePlayerFactoryProvider =
    Provider<VoicePlayer Function()>((ref) => JustAudioVoicePlayer.new);
final mediaUploaderProvider = Provider<MediaUploader>(
  (ref) => ApiMediaUploader(ref.watch(dioProvider)),
);

final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);
