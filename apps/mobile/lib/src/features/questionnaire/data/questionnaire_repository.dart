import 'package:dio/dio.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/features/onboarding/data/auth_repository.dart';
import 'package:marriage_connect/src/features/questionnaire/data/questionnaire_models.dart';

abstract class QuestionnaireRepository {
  Future<List<Question>> questions();
  Future<AnswerSet> answers();

  /// Upserts the given answers (all-or-nothing, at most 60). Returns the full
  /// stored set. Special answers are refused with `validation_error` +
  /// `missing_consent` unless the consent was recorded first.
  Future<AnswerSet> save(List<Answer> answers);

  /// Records one optional consent (special_religion / special_finance).
  Future<void> grantConsent(String kind);
}

class ApiQuestionnaireRepository implements QuestionnaireRepository {
  ApiQuestionnaireRepository(this._dio);
  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      throw e.failure;
    } on AppFailure {
      rethrow;
    } on Object {
      // An answer we could not read (wrong shape, bad JSON) is a failed
      // call, never an unhandled error that leaves a spinner running.
      throw const AppFailure(code: 'unknown');
    }
  }

  @override
  Future<List<Question>> questions() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/questions');
        return [
          for (final x in r.data!['items'] as List<dynamic>)
            Question.fromJson(x as Map<String, dynamic>),
        ];
      });

  @override
  Future<AnswerSet> answers() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/me/answers');
        return AnswerSet.fromJson(r.data!);
      });

  @override
  Future<AnswerSet> save(List<Answer> answers) => _guard(() async {
        final r = await _dio.put<Map<String, dynamic>>(
          '/me/answers',
          data: {
            'answers': [for (final a in answers) a.toJson()],
          },
        );
        return AnswerSet.fromJson(r.data!);
      });

  @override
  Future<void> grantConsent(String kind) => _guard(
        () => _dio.post<void>(
          '/me/consents',
          data: {
            'source': 'app',
            'consents': [
              {'kind': kind, 'version': consentVersion, 'granted': true},
            ],
          },
        ),
      );
}
