import pytest
from django.db import connection, models
from django.test import override_settings

from mc.common import crypto

pytestmark = pytest.mark.django_db


def test_round_trip_unicode():
    for text in ["", "Christian", "Muslim — mosque, Kampala ✝☪", "x" * 5000]:
        assert crypto.decrypt_text(crypto.encrypt_text(text)) == text


def test_ciphertext_differs_per_write_and_hides_plaintext():
    a, b = crypto.encrypt_text("secret"), crypto.encrypt_text("secret")
    assert a != b
    assert "secret" not in a
    assert a.startswith("v1:k1:")


def test_tampered_ciphertext_fails():
    token = crypto.encrypt_text("secret")
    head, _, payload = token.rpartition(":")
    flipped = payload[:-4] + ("AAAA" if payload[-4:] != "AAAA" else "BBBB")
    with pytest.raises(Exception):  # noqa: B017 - InvalidTag
        crypto.decrypt_text(f"{head}:{flipped}")


def test_key_id_is_bound_as_aad():
    token = crypto.encrypt_text("secret")
    swapped = token.replace(":k1:", ":k2:", 1)
    with pytest.raises(Exception):  # noqa: B017
        crypto.decrypt_text(swapped)


def test_key_rotation_decrypts_old_data():
    old = crypto.encrypt_text("rotate-me")
    assert old.startswith("v1:k1:")
    with override_settings(MC_DATA_KEY_CURRENT="k2"):
        new = crypto.encrypt_text("rotate-me")
        assert new.startswith("v1:k2:")
        assert crypto.decrypt_text(old) == "rotate-me"  # old row still readable
        assert crypto.decrypt_text(new) == "rotate-me"


def test_unknown_key_id_rejected():
    with pytest.raises(ValueError, match="unknown data key id"):
        crypto.decrypt_text("v1:k99:AAAA")


def test_hmac_stable_and_purpose_separated():
    a1 = crypto.hmac_value("CM12345678", purpose="id_number")
    a2 = crypto.hmac_value("CM12345678", purpose="id_number")
    assert a1 == a2 and len(a1) == 32
    assert a1 != crypto.hmac_value("CM12345679", purpose="id_number")
    assert a1 != crypto.hmac_value("CM12345678", purpose="phone")
    with pytest.raises(ValueError):
        crypto.hmac_value("x", purpose="nope")


def test_encrypted_field_is_ciphertext_in_db_and_plaintext_in_python():
    class Secret(models.Model):
        value = crypto.EncryptedTextField(null=True)

        class Meta:
            app_label = "common"

    with connection.schema_editor() as editor:
        editor.create_model(Secret)
    try:
        row = Secret.objects.create(value="Anglican")
        Secret.objects.create(value=None)
        with connection.cursor() as cur:
            cur.execute(f"SELECT value FROM {Secret._meta.db_table} WHERE id = %s", [row.id])
            raw = cur.fetchone()[0]
        assert raw.startswith("v1:") and "Anglican" not in raw  # DB inspection test
        assert Secret.objects.get(id=row.id).value == "Anglican"
        assert Secret.objects.filter(value__isnull=True).count() == 1
        with pytest.raises(TypeError):
            Secret.objects.filter(value="Anglican").count()
    finally:
        with connection.schema_editor() as editor:
            editor.delete_model(Secret)
