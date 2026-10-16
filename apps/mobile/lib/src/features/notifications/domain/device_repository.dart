// ignore_for_file: one_member_abstracts

/// `POST /me/devices`: registers (or, with a null token, unregisters) this
/// device's push token. The server upserts by `install_id`.
abstract class DeviceRepository {
  Future<void> register({
    required String installId,
    required String platform,
    required String appVersion,
    required String? pushToken,
  });
}
