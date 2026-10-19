from django.db import migrations

FORWARD = """
CREATE OR REPLACE FUNCTION accounts_funnel_event_guard() RETURNS trigger AS $$
BEGIN
    -- Append-only: rows are never updated; only the retention job may delete, and it must say so explicitly
    -- with SET LOCAL mc.purge_funnel_events = 'on' inside its transaction.
    IF TG_OP = 'DELETE' AND current_setting('mc.purge_funnel_events', true) = 'on' THEN
        RETURN OLD;
    END IF;
    RAISE EXCEPTION 'accounts_funnelevent is append-only: % is forbidden', TG_OP
        USING ERRCODE = 'integrity_constraint_violation';
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER funnel_event_no_update_delete
BEFORE UPDATE OR DELETE ON accounts_funnelevent
FOR EACH ROW EXECUTE FUNCTION accounts_funnel_event_guard();
"""
REVERSE = """
DROP TRIGGER IF EXISTS funnel_event_no_update_delete ON accounts_funnelevent;
DROP FUNCTION IF EXISTS accounts_funnel_event_guard();
"""


class Migration(migrations.Migration):
    dependencies = [("accounts", "0005_funnel_event")]
    operations = [migrations.RunSQL(FORWARD, REVERSE)]
