import 'package:marriage_connect/src/features/chat/domain/chat_message.dart';
import 'package:marriage_connect/src/features/discovery/domain/paged.dart';

class Capabilities {
  const Capabilities({
    this.state = 'none',
    this.sendMessage = false,
    this.readConversations = false,
  });

  factory Capabilities.fromJson(Map<String, dynamic> j) {
    final c = j.obj('capabilities') ?? const <String, dynamic>{};
    return Capabilities(
      state: j.str('state', 'none'),
      sendMessage: c.flag('send_message'),
      readConversations: c.flag('read_conversations'),
    );
  }

  final String state;
  final bool sendMessage;
  final bool readConversations;
}

abstract class ChatRepository {
  /// Offline copy of a conversation, newest first.
  Future<List<ChatMessage>> cached(String matchId);

  /// Network history, newest first; also refreshes the offline copy.
  Future<Paged<ChatMessage>> history(String matchId, {String? cursor});

  Future<void> cache(String matchId, List<ChatMessage> messages);

  /// Mark the other person's messages read up to [upToMessageId].
  Future<void> markRead(String matchId, String upToMessageId);

  /// Send an image/voice message whose media is already uploaded. The
  /// [clientMsgId] is reused on every retry of the same action.
  Future<ChatMessage> sendMedia({
    required String matchId,
    required String clientMsgId,
    required MessageKind kind,
    required String mediaId,
  });

  Future<Capabilities> capabilities();
}
