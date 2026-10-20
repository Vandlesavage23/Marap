// The rules of the demo "server" (DemoWorld) and its HTTP face (DemoApi):
// they must behave like the backend the real app will meet.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/auth/token_store.dart';
import 'package:marriage_connect/src/core/network/api_client.dart';
import 'package:marriage_connect/src/core/network/app_failure.dart';
import 'package:marriage_connect/src/demo/demo_api.dart';
import 'package:marriage_connect/src/demo/demo_world.dart';

class _Clock {
  _Clock([DateTime? start]) : t = start ?? DateTime.utc(2026, 10, 21, 9);
  DateTime t; // a Wednesday
  DateTime now() => t;
  void advance(Duration d) => t = t.add(d);
}

/// Captures scheduled callbacks so a test runs them when it wants.
class _Later {
  final jobs = <(Duration, void Function())>[];
  void call(Duration d, void Function() f) => jobs.add((d, f));
  void runAll() {
    final todo = [...jobs]..sort((a, b) => a.$1.compareTo(b.$1));
    jobs.clear();
    for (final j in todo) {
      j.$2();
    }
  }
}

DemoWorld _world(
  DemoScenario s, {
  _Clock? clock,
  _Later? later,
  DemoConfig? config,
}) =>
    DemoWorld(
      scenario: s,
      now: clock?.now,
      config: config,
      schedule: later?.call,
    );

DemoProblem _problem(void Function() f) {
  try {
    f();
  } on DemoProblem catch (p) {
    return p;
  }
  fail('expected a DemoProblem');
}

String _someCandidate(DemoWorld w) => w.deck.first.id;

void main() {
  group('sign-in', () {
    test('any six digits sign in; anything else is refused', () {
      for (final code in ['000000', '123456', '999999', '482913']) {
        final w = _world(DemoScenario.freshVisitor);
        expect(w.signedIn, isFalse);
        w.verifyOtp('+256772000111', code);
        expect(w.signedIn, isTrue, reason: code);
      }
      for (final bad in ['', '12345', '1234567', 'abc123', '12 456']) {
        final w = _world(DemoScenario.freshVisitor);
        final p = _problem(() => w.verifyOtp('+256772000111', bad));
        expect(p.code, 'validation_error', reason: bad);
        expect(w.signedIn, isFalse);
      }
    });

    test('a stranger has no profile; /me says so', () {
      final w = _world(DemoScenario.freshVisitor)
        ..verifyOtp('+256772000111', '123456');
      expect(w.me()['profile_status'], 'none');
      expect(w.me()['verification_status'], 'not_started');
      expect(_problem(w.ownProfile).code, 'not_found');
    });
  });

  group('scenarios', () {
    test('each start is what its label says', () {
      final fresh = _world(DemoScenario.freshVisitor);
      expect(fresh.signedIn, isFalse);

      final limited = _world(DemoScenario.signedInNotVerified);
      expect(limited.signedIn, isTrue);
      expect(limited.verified, isFalse);
      expect(limited.me()['profile_status'], 'draft');

      final free = _world(DemoScenario.verifiedFree);
      expect(free.verified, isTrue);
      expect(free.interestsUsed, 2);
      expect(free.entitlementState, 'none');

      final quota = _world(DemoScenario.quotaUsed);
      expect(quota.interestsUsed, 3);
      expect(quota.entitlementState, 'none');

      final member = _world(DemoScenario.member);
      expect(member.entitlementState, 'member');
      expect(member.premium, isTrue);

      final expired = _world(DemoScenario.expiredMember);
      expect(expired.entitlementState, 'expired');
      expect(expired.premium, isFalse);
      expect(expired.interestsUsed, 3);
    });

    test('a verified member arrives with interests, matches and notes', () {
      final w = _world(DemoScenario.verifiedFree);
      expect(w.receivedPending, 3);
      expect(w.matchCount, 3);
      expect(w.unreadNotifications, greaterThan(0));
      final matches = (w.matchesJson()['items']! as List).cast<Json>();
      expect(matches, hasLength(3));
      expect(
        matches.map((m) => m['unread_count']! as int).where((n) => n > 0),
        isNotEmpty,
        reason: 'at least one chat opens with unread messages',
      );
      for (final id in w.matchIds) {
        expect(w.messagesOf(id), isNotEmpty);
      }
    });

    test('a new world is a clean slate (nothing leaks between jumps)', () {
      final a = _world(DemoScenario.verifiedFree);
      a.sendInterest(_someCandidate(a), 'k1');
      expect(a.interestsUsed, 3);
      final b = _world(DemoScenario.verifiedFree);
      expect(b.interestsUsed, 2);
      expect(identical(a.members, b.members), isFalse);
    });

    test('the sample people are ~60 invented Ugandans with photos', () {
      final w = _world(DemoScenario.freshVisitor);
      expect(w.members.length, greaterThanOrEqualTo(60));
      expect(w.members.where((m) => m.woman), hasLength(30));
      for (final m in w.members) {
        expect(m.photoUrls, isNotEmpty);
        expect(m.photoUrls.first, startsWith('demo://avatar/'));
        expect(m.intro.length, greaterThan(100));
        expect(m.why, isNotEmpty);
        expect(m.age, inInclusiveRange(18, 45));
      }
      expect(w.members.map((m) => m.id).toSet(), hasLength(w.members.length));
    });
  });

  group('interests', () {
    test('unverified members are asked to verify, nothing is used', () {
      final w = _world(DemoScenario.signedInNotVerified);
      final p = _problem(() => w.sendInterest(_someCandidate(w), 'k'));
      expect(p.code, 'verification_required');
      expect(p.extra['capability'], 'send_interest');
      expect(w.interestsUsed, 0);
    });

    test('3 free interests, then the offer with can_start_trial', () {
      final w = _world(DemoScenario.verifiedFree);
      final deck = w.deck;
      final r = w.sendInterest(deck[0].id, 'a');
      expect(r['status'], 'pending');
      expect(r['remaining_today'], 0);
      final p = _problem(() => w.sendInterest(deck[1].id, 'b'));
      expect(p.code, 'interest_quota_reached');
      expect(p.status, 403);
      expect(p.extra['limit'], 3);
      expect(p.extra['can_start_trial'], isTrue);
      expect(
        DateTime.parse('${p.extra['resets_at']}').weekday,
        DateTime.monday,
      );
      expect(w.interestsUsed, 3);
    });

    test('a retry with the same key never uses another free interest', () {
      final w = _world(DemoScenario.verifiedFree);
      final id = _someCandidate(w);
      final first = w.sendInterest(id, 'same-key');
      final again = w.sendInterest(id, 'same-key');
      expect(again, first);
      expect(w.interestsUsed, 3);
    });

    test('the same person twice is a conflict', () {
      final w = _world(DemoScenario.verifiedFree);
      final id = _someCandidate(w);
      w.sendInterest(id, 'a');
      expect(_problem(() => w.sendInterest(id, 'b')).code, 'conflict');
    });

    test('the quota renews on Monday', () {
      final clock = _Clock();
      final w = _world(DemoScenario.quotaUsed, clock: clock);
      expect(w.interestsUsed, 3);
      clock.t = DateTime.utc(2026, 10, 26, 0, 1); // the next Monday
      expect(w.interestsUsed, 0);
      expect(
        w.sendInterest(_someCandidate(w), 'new-week')['status'],
        'pending',
      );
    });

    test('accepting a received interest makes a match with a chat', () {
      final w = _world(DemoScenario.verifiedFree);
      final received = (w.received()['items']! as List).cast<Json>();
      expect(received, hasLength(3));
      final before = w.matchCount;
      final matchId = w.acceptInterest(received.first['id']! as String);
      expect(matchId['match_id'], isNotNull);
      expect(w.matchCount, before + 1);
      expect(w.received()['items']! as List, hasLength(2));
    });

    test('sending to someone who already wrote to you is a match', () {
      final w = _world(DemoScenario.verifiedFree);
      final sender =
          ((w.received()['items']! as List).first as Json)['sender']! as Json;
      final r = w.sendInterest(sender['id']! as String, 'mutual');
      expect(r['status'], 'accepted');
      expect(r['match_id'], isNotNull);
    });
  });

  group('trial and membership', () {
    test('24 h trial: once, explicit, raises the limit, then ends', () {
      final clock = _Clock();
      final w = _world(DemoScenario.quotaUsed, clock: clock);
      var e = w.entitlements();
      expect((e['trial']! as Map)['available'], isTrue);
      e = w.startTrial('t1');
      expect(e['state'], 'trial');
      expect((e['interests']! as Map)['limit'], 20);
      expect(
        w.sendInterest(_someCandidate(w), 'during-trial')['status'],
        'pending',
      );
      expect(_problem(() => w.startTrial('t2')).code, 'trial_already_used');

      clock.advance(const Duration(hours: 25));
      e = w.entitlements();
      expect(e['state'], 'expired');
      expect((e['trial']! as Map)['available'], isFalse);
      expect((e['interests']! as Map)['limit'], 3);
    });

    test('an unverified member cannot start the trial', () {
      final w = _world(DemoScenario.signedInNotVerified);
      expect(_problem(() => w.startTrial('t')).code, 'verification_required');
    });

    test('a store purchase makes a member (1 month and 3 months)', () {
      final clock = _Clock();
      final w = _world(DemoScenario.expiredMember, clock: clock);
      var e = w.verifyPurchase({
        'platform': 'android',
        'product_id': 'membership_1m',
        'purchase_token': 'x',
      });
      expect(e['state'], 'member');
      final ends1 =
          DateTime.parse((e['membership']! as Map)['ends_at']! as String);
      expect(ends1.difference(clock.t).inDays, inInclusiveRange(29, 30));
      e = w.verifyPurchase({
        'platform': 'android',
        'product_id': 'membership_3m',
        'purchase_token': 'y',
      });
      final ends2 =
          DateTime.parse((e['membership']! as Map)['ends_at']! as String);
      expect(ends2.difference(ends1).inDays, 90);
    });

    test('products are placeholders in UGX with store ids', () {
      final items =
          (_world(DemoScenario.freshVisitor).products()['items']! as List)
              .cast<Json>();
      expect(items.map((p) => p['currency']).toSet(), {'UGX'});
      expect(
        items.every((p) => (p['store_product_id']! as String).isNotEmpty),
        isTrue,
      );
    });
  });

  group('verification', () {
    test('capture -> pending -> passed after the delay', () {
      final clock = _Clock();
      final w = _world(
        DemoScenario.signedInNotVerified,
        clock: clock,
        config: DemoConfig()..verificationDelay = const Duration(seconds: 6),
      );
      expect(w.verificationStatus()['status'], 'not_started');
      final s = w.createVerificationSession('NATIONAL_ID');
      expect(w.verificationStatus()['status'], 'created');
      w.markSubmitted(s['attempt_id']! as String);
      expect(w.verificationStatus()['status'], 'submitted');
      expect(w.verified, isFalse);
      clock.advance(const Duration(seconds: 5));
      expect(w.verificationStatus()['status'], 'submitted');
      clock.advance(const Duration(seconds: 2));
      expect(w.verificationStatus()['status'], 'passed');
      expect(w.verified, isTrue);
      expect(w.entitlements()['verification'], {'status': 'passed'});
      expect(
        (w.entitlements()['capabilities']! as Map)['send_interest'],
        isTrue,
      );
      expect(w.receivedPending, greaterThan(0));
    });

    test('a refused check can be appealed and then passes', () {
      final clock = _Clock();
      final cfg = DemoConfig()
        ..verificationDelay = const Duration(seconds: 1)
        ..failNextVerification = true;
      final w =
          _world(DemoScenario.signedInNotVerified, clock: clock, config: cfg);
      final s = w.createVerificationSession('PASSPORT');
      w.markSubmitted(s['attempt_id']! as String);
      clock.advance(const Duration(seconds: 2));
      final st = w.verificationStatus();
      expect(st['status'], 'failed');
      expect(st['reason'], 'face_mismatch');
      expect(cfg.failNextVerification, isFalse);
      w.appealVerification();
      expect(w.verificationStatus()['status'], 'needs_review');
      clock.advance(const Duration(seconds: 2));
      expect(w.verificationStatus()['status'], 'passed');
    });

    test('go live needs verification, then a complete profile', () {
      final w = _world(DemoScenario.signedInNotVerified);
      expect(_problem(w.goLive).code, 'verification_required');
      final clock = _Clock();
      final v = _world(DemoScenario.signedInNotVerified, clock: clock);
      final s = v.createVerificationSession('NATIONAL_ID');
      v.markSubmitted(s['attempt_id']! as String);
      clock.advance(const Duration(minutes: 1));
      final p = _problem(v.goLive);
      expect(p.code, 'profile_incomplete');
      expect(
        p.extra['missing'],
        containsAll(['district', 'photos', 'description', 'questionnaire']),
      );
    });
  });

  group('profile', () {
    test('about you: 18+ gate, name required', () {
      final w = _world(DemoScenario.freshVisitor)
        ..verifyOtp('+256772000111', '123456');
      expect(
        _problem(() => w.updateProfile({'birth_date': '2015-01-01'})).code,
        'validation_error',
      );
      expect(
        _problem(() => w.updateProfile({'display_name': '  '})).code,
        'validation_error',
      );
      final p = w.updateProfile({
        'display_name': 'Grace',
        'gender': 'female',
        'birth_date': '1998-04-12',
      });
      expect(p['age'], greaterThan(18));
      expect(w.me()['profile_status'], 'draft');
    });

    test('questions: the full set, special ones need consent', () {
      final w = _world(DemoScenario.signedInNotVerified);
      final qs = (w.questions()['items']! as List).cast<Json>();
      expect(qs.length, greaterThanOrEqualTo(15));
      expect(qs.where((q) => q['is_core'] == true), hasLength(10));
      expect(qs.map((q) => q['type']).toSet(), {'single', 'multi', 'scale'});
      expect(
        _problem(
          () => w.saveAnswers([
            {'question': 'q15', 'value': 'very_important'},
          ]),
        ).code,
        'consent_required',
      );
      w
        ..setConsents([
          {'kind': 'special_religion', 'granted': true},
        ])
        ..saveAnswers([
          {'question': 'q15', 'value': 'very_important'},
        ]);
      expect(w.answersJson()['items']! as List, hasLength(1));
    });

    test('a picked sample photo becomes the next uploaded photo', () {
      final w = _world(DemoScenario.verifiedFree);
      final before = (w.listPhotos()['items']! as List).length;
      w.queuePhotoSeed('sample-photo-4');
      final up = w.createUpload({'purpose': 'profile_photo'});
      w.completeMedia(up['id']! as String);
      expect(w.mediaInfo(up['id']! as String)['status'], 'ready');
      final photo = w.addPhoto(up['id']! as String);
      expect(photo['url'], contains('sample-photo-4'));
      expect(w.listPhotos()['items']! as List, hasLength(before + 1));
    });
  });

  group('discovery', () {
    test('unverified viewers get limited cards, verified full ones', () {
      final limited = _world(DemoScenario.signedInNotVerified);
      final card = (limited.discovery(null)['items']! as List).first as Json;
      expect(card['locked'], isTrue);
      expect(card['locked_reason'], 'verify_to_see_more');
      expect(card['why'], isEmpty);
      expect(
        limited.publicProfile(card['profile_id']! as String)['description'],
        isNull,
      );

      final full = _world(DemoScenario.verifiedFree);
      final c2 = (full.discovery(null)['items']! as List).first as Json;
      expect(c2['locked'], isNull);
      expect(c2['why'], isNotEmpty);
      expect(
        full.publicProfile(c2['profile_id']! as String)['description'],
        isNotNull,
      );
    });

    test('opposite gender only, pages of 10, passes disappear', () {
      final w = _world(DemoScenario.verifiedFree);
      final page = w.discovery(null);
      final items = (page['items']! as List).cast<Json>();
      expect(items, hasLength(10));
      expect(page['next_cursor'], isNotNull);
      for (final c in items) {
        expect(w.member(c['profile_id']! as String)!.woman, isFalse);
      }
      final first = items.first['profile_id']! as String;
      w.discoveryFeedback(first, 'pass');
      final again = (w.discovery(null)['items']! as List).cast<Json>();
      expect(again.map((c) => c['profile_id']), isNot(contains(first)));
    });

    test('blocking removes someone everywhere', () {
      final w = _world(DemoScenario.verifiedFree);
      final matchMember = (w.matchesJson()['items']! as List).first as Json;
      final memberId = (matchMember['member']! as Json)['id']! as String;
      final before = w.matchCount;
      w.block(memberId);
      expect(w.matchCount, before - 1);
      expect(_problem(() => w.publicProfile(memberId)).code, 'not_found');
      expect(w.blocks()['items']! as List, hasLength(1));
      w.unblock(memberId);
      expect(w.blocks()['items']! as List, isEmpty);
    });
  });

  group('chat', () {
    test('a match answers after the delay, and reads your message first', () {
      final later = _Later();
      final cfg = DemoConfig()..replyDelay = const Duration(seconds: 3);
      final w = _world(DemoScenario.verifiedFree, later: later, config: cfg);
      final frames = <Json>[];
      final sub = w.frames.stream.listen(frames.add);
      addTearDown(sub.cancel);
      final id = w.matchIds.first;
      final before = w.messagesOf(id).length;

      final sent = w.sendMessage(
        id,
        clientMsgId: 'c1',
        kind: 'text',
        body: 'Good evening, how are you?',
      );
      expect(sent['sender'], 'me');
      expect(later.jobs, hasLength(2), reason: 'a "read" and a reply');
      expect(
        later.jobs.map((j) => j.$1),
        containsAll([const Duration(seconds: 1), const Duration(seconds: 3)]),
      );
      later.runAll();
      return Future<void>.delayed(Duration.zero, () {
        expect(frames.map((f) => f['type']), ['msg.read', 'msg.new']);
        expect(frames.first['up_to_message_id'], sent['id']);
        final reply = frames.last['message']! as Json;
        expect(reply['sender'], 'them');
        expect(reply['body'], isNotEmpty);
        expect(w.messagesOf(id).length, before + 2);
      });
    });

    test('a retried send is the same message (client_msg_id)', () {
      final w = _world(DemoScenario.verifiedFree, later: _Later());
      final id = w.matchIds.first;
      final a = w.sendMessage(id, clientMsgId: 'dup', kind: 'text', body: 'Hi');
      final b = w.sendMessage(id, clientMsgId: 'dup', kind: 'text', body: 'Hi');
      expect(b['id'], a['id']);
      expect(
        w.messagesOf(id).where((m) => m.clientMsgId == 'dup'),
        hasLength(1),
      );
    });

    test('contact details are blocked in a new match; photos are locked', () {
      final w = _world(DemoScenario.verifiedFree, later: _Later());
      final fresh = w.acceptInterest(
        ((w.received()['items']! as List).first as Json)['id']! as String,
      )['match_id']! as String;
      expect(
        _problem(
          () => w.sendMessage(
            fresh,
            clientMsgId: 'n1',
            kind: 'text',
            body: 'Call me on 0772 123 456',
          ),
        ).code,
        'contact_details_blocked',
      );
      final media = w.registerChatMedia(image: true);
      expect(
        _problem(
          () => w.sendMessage(
            fresh,
            clientMsgId: 'n2',
            kind: 'image',
            mediaId: media,
          ),
        ).code,
        'photo_locked',
      );
      // An old, busy chat (seeded) is past both rules for photos.
      final busy = w.matchIds.last;
      expect(w.messagesOf(busy), isNotEmpty);
    });

    test('reading clears the unread count and the notification', () {
      final w = _world(DemoScenario.verifiedFree);
      final unreadMatch = (w.matchesJson()['items']! as List)
          .cast<Json>()
          .firstWhere((m) => (m['unread_count']! as int) > 0);
      final id = unreadMatch['id']! as String;
      final last = w.history(id)['items']! as List;
      w.markRead(id, (last.first as Json)['id']! as String);
      final after = (w.matchesJson()['items']! as List)
          .cast<Json>()
          .firstWhere((m) => m['id'] == id);
      expect(after['unread_count'], 0);
    });

    test('history pages newest first with a cursor', () {
      final w = _world(DemoScenario.verifiedFree);
      final id = w.matchIds.first;
      final page = w.history(id, limit: 3);
      final items = (page['items']! as List).cast<Json>();
      expect(items, hasLength(3));
      expect(page['next_cursor'], isNotNull);
      final older = w.history(id, before: page['next_cursor'] as String?);
      final all = [...items, ...(older['items']! as List).cast<Json>()];
      final times = [
        for (final m in all) DateTime.parse(m['created_at']! as String),
      ];
      final sorted = [...times]..sort((a, b) => b.compareTo(a));
      expect(times, orderedEquals(sorted));
    });

    test('chat is for verified members only', () {
      final w = _world(DemoScenario.signedInNotVerified);
      expect(_problem(w.matchesJson).code, 'entitlement_required');
    });
  });

  group('the HTTP face', () {
    Dio dio(DemoWorld w) => Dio(
          BaseOptions(
            baseUrl: 'https://demo.invalid/api/v1',
            validateStatus: (s) => s != null && s >= 200 && s < 300,
          ),
        )..httpClientAdapter = DemoApi(w);

    test('offline fails like a lost connection', () async {
      final w = _world(
        DemoScenario.verifiedFree,
        config: DemoConfig()..offline = true,
      );
      await expectLater(
        dio(w).get<dynamic>('/me/entitlements'),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionError,
          ),
        ),
      );
    });

    test('"fail the next request" fails exactly one real request', () async {
      final cfg = DemoConfig()..failNext = true;
      final w = _world(DemoScenario.verifiedFree, config: cfg);
      final d = dio(w);
      await d.post<dynamic>('/events', data: {'name': 'x'}); // background ping
      expect(cfg.failNext, isTrue, reason: 'pings do not use it up');
      await expectLater(
        d.get<dynamic>('/me/entitlements'),
        throwsA(
          isA<DioException>()
              .having((e) => e.response?.statusCode, 'status', 500),
        ),
      );
      expect(cfg.failNext, isFalse);
      expect((await d.get<dynamic>('/me/entitlements')).statusCode, 200);
    });

    test('slow network waits before answering', () async {
      final w = _world(
        DemoScenario.verifiedFree,
        config: DemoConfig()..latency = const Duration(milliseconds: 150),
      );
      final sw = Stopwatch()..start();
      await dio(w).get<dynamic>('/me');
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(140));
    });

    test('signed out is a 401 problem+json', () async {
      final w = _world(DemoScenario.freshVisitor);
      await expectLater(
        dio(w).get<dynamic>('/discovery'),
        throwsA(
          isA<DioException>().having(
            (e) => (e.response?.data as Map)['code'],
            'code',
            'unauthenticated',
          ),
        ),
      );
    });

    test('the real client turns refusals into AppFailure (quota extras)',
        () async {
      final w = _world(DemoScenario.quotaUsed);
      final real = buildDio(
        baseUrl: 'https://demo.invalid/api/v1',
        tokens: MemoryTokenStore(access: 'a', refresh: 'r'),
        onSignedOut: () {},
        adapter: DemoApi(w),
      );
      try {
        await real.post<dynamic>(
          '/interests',
          data: {'recipient_id': _someCandidate(w)},
        );
        fail('should be refused');
      } on DioException catch (e) {
        final f = e.failure;
        expect(f.code, 'interest_quota_reached');
        expect(f.status, 403);
        expect(f.extra['can_start_trial'], isTrue);
        expect(f, isA<AppFailure>());
      }
    });

    test('storage upload url answers 204 (the presigned POST)', () async {
      final w = _world(DemoScenario.verifiedFree);
      final r =
          await dio(w).post<dynamic>('https://demo.invalid/upload/media-1');
      expect(r.statusCode, 204);
    });
  });

  test('disposing the world cancels its timers and closes the frames', () {
    final w = _world(DemoScenario.verifiedFree);
    w.sendMessage(
      w.matchIds.first,
      clientMsgId: 'x',
      kind: 'text',
      body: 'hello there',
    );
    w.dispose();
    expect(w.frames.isClosed, isTrue);
  });
}
