import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marriage_connect/src/core/storage/local_prefs.dart';

/// Who a visitor says they are, kept ON THE DEVICE ONLY (never sent anywhere
/// with an identity): enough to show the right people before any account
/// exists. [gender] is `male` | `female`; [seeking] is the opposite one
/// (opposite-gender matching only, CLAUDE.md rule 11).
class GuestSession {
  const GuestSession({required this.gender, required this.birthDate});

  final String gender;
  final DateTime birthDate;

  String get seeking => gender == 'male' ? 'female' : 'male';
}

const guestGenderPrefKey = 'mc.guest.gender';
const guestBirthPrefKey = 'mc.guest.birth';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The guest session, or null when the visitor has not chosen yet (then the
/// router sends them to Welcome). Persisted in [LocalPrefs].
class GuestSessionController extends Notifier<GuestSession?> {
  @override
  GuestSession? build() {
    final prefs = ref.read(localPrefsProvider);
    final gender = prefs.getString(guestGenderPrefKey);
    final birth = DateTime.tryParse(prefs.getString(guestBirthPrefKey) ?? '');
    if ((gender != 'male' && gender != 'female') || birth == null) return null;
    return GuestSession(gender: gender!, birthDate: birth);
  }

  void start({required String gender, required DateTime birthDate}) {
    final prefs = ref.read(localPrefsProvider);
    state = GuestSession(gender: gender, birthDate: birthDate);
    prefs
      ..setString(guestGenderPrefKey, gender)
      ..setString(guestBirthPrefKey, _iso(birthDate));
  }

  void clear() {
    final prefs = ref.read(localPrefsProvider);
    state = null;
    prefs
      ..remove(guestGenderPrefKey)
      ..remove(guestBirthPrefKey);
  }
}

final guestSessionProvider =
    NotifierProvider<GuestSessionController, GuestSession?>(
  GuestSessionController.new,
);
