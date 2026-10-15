# Safety: severity-1 report (`alert=s1_report`)
1. Open the admin portal → Safety (role `trust_safety`). The case is at the top (SLA `SAFETY_SLA_HOURS[s1]`).
2. Read the captured evidence only (never live chats). The read is audited.
3. If there is imminent danger to a person, escalate per the on-call safety policy (call the trust & safety lead; police
   liaison is a human decision, not an app feature).
4. Act: `warn` / `hide_content` / `suspend_7d` / `ban` / `reinstate` with a written reason. Suspension signs the member out;
   ban also blocks re-registration via the identity hash.
5. Verify: AuditEvent `safety.<action>` exists; the case closed; reporter was not told who the subject is beyond policy copy.
6. Follow-up: if the SLA was breached, note it in the weekly review. Appeals go to a *different* reviewer.
