from django.urls import path

from . import views

urlpatterns = [
    path("auth/otp/start", views.OtpStartView.as_view()),
    path("auth/otp/verify", views.OtpVerifyView.as_view()),
    path("auth/refresh", views.RefreshView.as_view()),
    path("auth/logout", views.LogoutView.as_view()),
    path("me", views.MeView.as_view()),
    path("me/sessions", views.SessionsView.as_view()),
    path("me/sessions/<uuid:session_id>", views.SessionDetailView.as_view()),
    path("me/consents", views.ConsentsView.as_view()),
    path("me/devices", views.DevicesView.as_view()),
]
