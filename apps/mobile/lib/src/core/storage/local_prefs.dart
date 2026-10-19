import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny on-device key/value store for member preferences (data saver, push
/// opt-in). Never holds tokens or personal data; those are server-side or in
/// secure storage.
abstract class LocalPrefs {
  bool? getBool(String key);
  Future<void> setBool(String key, {required bool value});
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// Default for tests and previews; `bootstrap` swaps in [SharedPrefsStore].
class MemoryPrefs implements LocalPrefs {
  MemoryPrefs([Map<String, bool>? initial]) : _values = {...?initial};
  final Map<String, Object> _values;

  @override
  bool? getBool(String key) {
    final v = _values[key];
    return v is bool ? v : null;
  }

  @override
  Future<void> setBool(String key, {required bool value}) async =>
      _values[key] = value;

  @override
  String? getString(String key) {
    final v = _values[key];
    return v is String ? v : null;
  }

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}

class SharedPrefsStore implements LocalPrefs {
  SharedPrefsStore(this._prefs);
  final SharedPreferences _prefs;

  @override
  bool? getBool(String key) {
    try {
      return _prefs.getBool(key);
    } on Object {
      return null; // corrupted value: behave as "not set"
    }
  }

  @override
  Future<void> setBool(String key, {required bool value}) async {
    try {
      await _prefs.setBool(key, value);
    } on Object {
      // Preference storage failing must never break the screen.
    }
  }

  @override
  String? getString(String key) {
    try {
      return _prefs.getString(key);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> setString(String key, String value) async {
    try {
      await _prefs.setString(key, value);
    } on Object {
      // see above
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      await _prefs.remove(key);
    } on Object {
      // see above
    }
  }
}

final localPrefsProvider = Provider<LocalPrefs>((ref) => MemoryPrefs());
