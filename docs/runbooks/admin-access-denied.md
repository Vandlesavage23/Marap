# Staff access denied (`alert=admin_access_denied`)
Every denial is also an `AuditEvent` (`admin.denied`).
1. Search the audit log (role `privacy_officer`) for `admin.denied` by actor and time window.
2. One-off, role mismatch → talk to the person; grant the correct role via `manage.py create_staff`/superadmin if justified.
3. Repeated attempts, odd IP, or a deactivated account → treat as a possible compromise: deactivate the StaffUser,
   revoke sessions (set `StaffSession.revoked_at`), rotate SSO if needed, open a data-incident record.
