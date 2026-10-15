import 'package:marriage_connect/src/features/discovery/domain/candidate.dart';
import 'package:marriage_connect/src/features/discovery/domain/paged.dart';

/// Everything discovery needs from the backend. Implementations throw
/// `AppFailure`; the UI never sees Dio.
abstract class DiscoveryRepository {
  Future<Paged<Candidate>> page({String? cursor});
  Future<void> feedback(String profileId, DiscoveryFeedback action);
  Future<PublicProfile> profile(String profileId);
  Future<DiscoveryFilters> filters();
  Future<DiscoveryFilters> saveFilters(DiscoveryFilters filters);
}
