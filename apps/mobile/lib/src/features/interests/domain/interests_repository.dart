import 'package:marriage_connect/src/features/discovery/domain/paged.dart';
import 'package:marriage_connect/src/features/interests/domain/interest.dart';

abstract class InterestsRepository {
  /// Idempotent: every call with the same [idempotencyKey] is the same action.
  Future<SendInterestResult> send({
    required String recipientProfileId,
    required String idempotencyKey,
  });

  Future<Paged<ReceivedInterest>> received({String? cursor});
  Future<Paged<SentInterest>> sent({String? cursor});

  /// Returns the new match id.
  Future<String> accept({
    required String interestId,
    required String idempotencyKey,
  });

  Future<void> pass(String interestId);

  /// Text of my current APPROVED description, or null if there is none.
  Future<String?> approvedDescription();
}
