import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';

enum SessionState { unknown, signedOut, signedIn }

/// Single source of truth for "is there a session". Business gating (verified?
/// profile complete?) comes from the backend via `/me`, not from the client.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => SessionState.unknown;

  Future<void> restore() async {
    final refresh = await ref.read(tokenStoreProvider).readRefreshToken();
    state = refresh == null ? SessionState.signedOut : SessionState.signedIn;
  }

  void signedIn() => state = SessionState.signedIn;
  void signedOut() => state = SessionState.signedOut;
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
