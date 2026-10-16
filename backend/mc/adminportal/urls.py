from django.urls import path

from . import views

urlpatterns = [
    path("", views.home, name="admin-home"),
    path("login", views.login, name="admin-login"),
    path("sso/callback", views.sso_callback, name="admin-sso-callback"),
    path("mfa", views.mfa, name="admin-mfa"),
    path("stepup", views.stepup, name="admin-stepup"),
    path("logout", views.logout, name="admin-logout"),
    path("users", views.users, name="admin-users"),
    path(
        "users/<uuid:account_id>/revoke-sessions",
        views.revoke_sessions,
        name="admin-revoke-sessions",
    ),
    path("users/<uuid:account_id>/notes", views.add_note, name="admin-add-note"),
    path("verification", views.verification_queue, name="admin-verification"),
    path("safety", views.safety_queue, name="admin-safety"),
    path("safety/<uuid:case_id>", views.safety_case, name="admin-case"),
    path("safety/<uuid:case_id>/act", views.safety_act, name="admin-case-act"),
    path("payments", views.payments, name="admin-payments"),
    path("payments/reconciliation", views.reconciliation, name="admin-reconciliation"),
    path("payments/<uuid:purchase_id>/refund", views.refund, name="admin-refund"),
    path("privacy", views.privacy_requests, name="admin-privacy"),
    path("audit", views.audit_search, name="admin-audit"),
    path("dashboards/funnel", views.funnel_dashboard, name="admin-funnel"),
    path("dashboards/density", views.density_dashboard, name="admin-density"),
    path("flags", views.flags, name="admin-flags"),
]
