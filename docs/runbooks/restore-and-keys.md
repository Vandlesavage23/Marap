# Restore from backup and key rotation
**Restore drill (MC-124, not yet performed):** restore the latest snapshot to a new instance, run `manage.py migrate --check`,
point a staging API at it, verify `/ready` and a sign-in. Record RTO/RPO evidence.

**Key rotation:** field-encryption keyring is versioned (`v1:` prefix in ciphertext). Add a new key version, deploy, then
re-encrypt in a background job; keep old versions until no `vN:` rows remain. JWT signing keys: add the new key first,
wait out the access-token lifetime (15 min), then retire the old one. After rotating, revoke sessions if a key was exposed.
