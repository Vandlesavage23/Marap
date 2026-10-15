from django.db import migrations

FORWARD = """
CREATE OR REPLACE FUNCTION accounts_consent_forbid_mutation() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'accounts_consentrecord is append-only: % is forbidden', TG_OP
        USING ERRCODE = 'integrity_constraint_violation';
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER consent_no_update_delete
BEFORE UPDATE OR DELETE ON accounts_consentrecord
FOR EACH ROW EXECUTE FUNCTION accounts_consent_forbid_mutation();
"""
REVERSE = """
DROP TRIGGER IF EXISTS consent_no_update_delete ON accounts_consentrecord;
DROP FUNCTION IF EXISTS accounts_consent_forbid_mutation();
"""


class Migration(migrations.Migration):
    dependencies = [("accounts", "0001_initial")]
    operations = [migrations.RunSQL(FORWARD, REVERSE)]
