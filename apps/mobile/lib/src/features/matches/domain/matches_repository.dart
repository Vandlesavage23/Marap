import 'package:marriage_connect/src/features/matches/domain/match.dart';

abstract class MatchesRepository {
  /// Last synced list (offline copy), in server order.
  Future<List<Match>> cached();

  /// Fetches every page and REPLACES the offline copy, so a match that ended
  /// disappears. Throws `AppFailure` and leaves the cache untouched on failure.
  Future<List<Match>> sync();

  /// Drops one match (and its cached messages) locally, e.g. on `match.ended`.
  Future<void> removeLocal(String matchId);

  Future<void> unmatch(String matchId);
}
