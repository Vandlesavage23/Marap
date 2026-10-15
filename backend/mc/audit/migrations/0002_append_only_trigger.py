from django.db import migrations

FORWARD = """
CREATE OR REPLACE FUNCTION audit_event_forbid_mutation() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'audit_auditevent is append-only: % is forbidden', TG_OP
        USING ERRCODE = 'integrity_constraint_violation';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_event_no_update_delete
BEFORE UPDATE OR DELETE ON audit_auditevent
FOR EACH ROW EXECUTE FUNCTION audit_event_forbid_mutation();
"""

REVERSE = """
DROP TRIGGER IF EXISTS audit_event_no_update_delete ON audit_auditevent;
DROP FUNCTION IF EXISTS audit_event_forbid_mutation();
"""


class Migration(migrations.Migration):
    dependencies = [("audit", "0001_initial")]
    operations = [migrations.RunSQL(FORWARD, REVERSE)]
