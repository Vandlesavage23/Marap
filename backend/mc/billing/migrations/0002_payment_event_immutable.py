from django.db import migrations

FORWARD = """
CREATE OR REPLACE FUNCTION billing_paymentevent_guard() RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'billing_paymentevent is an append-only ledger: DELETE is forbidden'
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;
    IF NEW.provider IS DISTINCT FROM OLD.provider
       OR NEW.provider_event_id IS DISTINCT FROM OLD.provider_event_id
       OR NEW.event_type IS DISTINCT FROM OLD.event_type
       OR NEW.raw IS DISTINCT FROM OLD.raw
       OR NEW.normalized IS DISTINCT FROM OLD.normalized
       OR NEW.signature_valid IS DISTINCT FROM OLD.signature_valid
       OR NEW.received_at IS DISTINCT FROM OLD.received_at THEN
        RAISE EXCEPTION 'billing_paymentevent provider facts are immutable'
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER paymentevent_guard
BEFORE UPDATE OR DELETE ON billing_paymentevent
FOR EACH ROW EXECUTE FUNCTION billing_paymentevent_guard();
"""
REVERSE = """
DROP TRIGGER IF EXISTS paymentevent_guard ON billing_paymentevent;
DROP FUNCTION IF EXISTS billing_paymentevent_guard();
"""


class Migration(migrations.Migration):
    dependencies = [("billing", "0001_initial")]
    operations = [migrations.RunSQL(FORWARD, REVERSE)]
