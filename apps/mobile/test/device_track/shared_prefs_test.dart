import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('SharedPrefsStore round-trips and removes values', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPrefsStore(await SharedPreferences.getInstance());
    expect(store.getBool('k'), isNull);
    await store.setBool('k', value: true);
    expect(store.getBool('k'), isTrue);
    await store.setBool('k', value: false);
    expect(store.getBool('k'), isFalse);
    await store.remove('k');
    expect(store.getBool('k'), isNull);
  });

  test('a value of the wrong type reads as not set', () async {
    SharedPreferences.setMockInitialValues({'k': 'text'});
    final store = SharedPrefsStore(await SharedPreferences.getInstance());
    expect(store.getBool('k'), isNull);
  });

  test('persists across a new SharedPreferences instance (restart)', () async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsStore(await SharedPreferences.getInstance())
        .setBool('mc.data_saver', value: true);
    final again = SharedPrefsStore(await SharedPreferences.getInstance());
    expect(again.getBool('mc.data_saver'), isTrue);
  });
}
