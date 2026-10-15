from django.urls import path

from . import views

urlpatterns = [
    path("verification/sessions", views.CreateSessionView.as_view()),
    path("verification/sessions/<uuid:attempt_id>/submitted", views.SubmittedView.as_view()),
    path("verification/appeals", views.AppealView.as_view()),
    path("verification/status", views.StatusView.as_view()),
    path("webhooks/smile-id", views.SmileIdWebhookView.as_view()),
]
