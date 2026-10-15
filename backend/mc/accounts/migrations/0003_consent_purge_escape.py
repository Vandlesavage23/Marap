from django.db import migrations

FORWARD = """
CREATE OR REPLACE FUNCTION accounts_consent_forbid_mutation() RETURNS trigger AS $$
BEGIN
    -- Only the account hard-delete service (privacy/GDPR-style erasure) may remove rows, and it must
    -- say so explicitly with SET LOCAL mc.purge_consents = 'on' inside its transaction.
    IF TG_OP = 'DELETE' AND current_setting('mc.purge_consents', true) = 'on' THEN
        RETURN OLD;
    END IF;
    RAISE EXCEPTION 'accounts_consentrecord is append-only: % is forbidden', TG_OP
        USING ERRCODE = 'integrity_constraint_violation';
END;
$$ LANGUAGE plpgsql;
"""
REVERSE = """
CREATE OR REPLACE FUNCTION accounts_consent_forbid_mutation() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'accounts_consentrecord is append-only: % is forbidden', TG_OP
        USING ERRCODE = 'integrity_constraint_violation';
END;
$$ LANGUAGE plpgsql;
"""


class Migration(migrations.Migration):
    dependencies = [("accounts", "0002_consent_append_only")]
    operations = [migrations.RunSQL(FORWARD, REVERSE)]
