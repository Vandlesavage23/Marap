/// Where a notification or push opens. Pure and shared by the inbox and the
/// push tap handler, so both always agree.
///
/// Only ids matching [_id] are placed in a path (a push payload is data from
/// outside the app: it must never be able to build an arbitrary route). The
/// destination screen fetches its own content; nothing from the payload is
/// displayed.
class NotificationLinks {
  const NotificationLinks._();

  static final _id = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  static const inbox = '/notifications';

  /// Types the app knows. Anything else opens the inbox.
  static const knownTypes = {
    'interest_received',
    'match_created',
    'new_message',
    'trial_ending_soon',
    'trial_ended',
    'warning',
    'appeal_decided',
    'export_ready',
    'verification_decided',
    'new_device',
  };

  static String routeFor(String type, Map<String, String> data) {
    String? id(String key) {
      final v = data[key];
      return v != null && _id.hasMatch(v) ? v : null;
    }

    switch (type) {
      case 'interest_received':
        final i = id('interest_id');
        return i == null ? '/interests' : '/interests/$i';
      case 'match_created':
      case 'new_message':
        final m = id('match_id');
        return m == null ? '/matches' : '/matches/$m/chat';
      case 'trial_ending_soon':
      case 'trial_ended':
        return '/settings/membership';
      case 'warning':
      case 'appeal_decided':
        return '/safety/appeal';
      case 'export_ready':
        return '/settings/export';
      case 'verification_decided':
        return '/verification';
      case 'new_device':
        return '/settings/sessions';
      default:
        return inbox;
    }
  }
}
