from django.urls import path

from . import views

urlpatterns = [
    path("me/entitlements", views.EntitlementsView.as_view()),
    path("billing/trial/start", views.StartTrialView.as_view()),
]
