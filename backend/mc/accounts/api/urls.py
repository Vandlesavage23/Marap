from django.urls import path

from . import views

urlpatterns = [
    path("auth/otp/start", views.OtpStartView.as_view()),
    path("auth/otp/verify", views.OtpVerifyView.as_view()),
    path("auth/refresh", views.RefreshView.as_view()),
    path("auth/logout", views.LogoutView.as_view()),
    path("auth/recover/start", views.RecoverStartView.as_view()),
    path("auth/recover/verify-email", views.RecoverVerifyEmailView.as_view()),
    path("auth/recover/status", views.RecoverStatusView.as_view()),
    path("auth/recover/new-phone", views.RecoverNewPhoneView.as_view()),
    path("auth/recover/complete", views.RecoverCompleteView.as_view()),
    path("me/email/start", views.EmailStartView.as_view()),
    path("me/email/verify", views.EmailVerifyView.as_view()),
    path("events", views.FunnelEventView.as_view()),
    path("me", views.MeView.as_view()),
    path("me/sessions", views.SessionsView.as_view()),
    path("me/sessions/<uuid:session_id>", views.SessionDetailView.as_view()),
    path("me/consents", views.ConsentsView.as_view()),
    path("me/devices", views.DevicesView.as_view()),
]
