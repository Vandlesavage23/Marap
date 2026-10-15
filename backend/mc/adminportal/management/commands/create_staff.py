from django.core.management.base import BaseCommand, CommandError

from mc.adminportal.models import StaffUser
from mc.adminportal.policies import PERMISSIONS
from mc.audit import services as audit


class Command(BaseCommand):
    help = "Pre-provision a staff member (SSO sign-in + TOTP are completed by them on first login)."

    def add_arguments(self, parser):  # type: ignore[no-untyped-def]
        parser.add_argument("email")
        parser.add_argument("--name", required=True)
        parser.add_argument("--role", action="append", required=True, choices=sorted(PERMISSIONS))

    def handle(self, *args, **opts):  # type: ignore[no-untyped-def]
        email = opts["email"].lower()
        if StaffUser.objects.filter(email=email).exists():
            raise CommandError("That staff member already exists.")
        s = StaffUser.objects.create(email=email, name=opts["name"], roles=opts["role"])
        audit.record(
            actor_type="system",
            action="staff.created",
            target_type="staff",
            target_id=s.id,
            role=",".join(s.roles),
            reason="create_staff command",
        )
        self.stdout.write(f"Created {s.id}")
