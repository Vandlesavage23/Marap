from django.urls import path

from . import views

urlpatterns = [
    path("interests", views.SendInterestView.as_view()),
    path("interests/received", views.ReceivedView.as_view()),
    path("interests/sent", views.SentView.as_view()),
    path("interests/<uuid:interest_id>/accept", views.AcceptView.as_view()),
    path("interests/<uuid:interest_id>/pass", views.PassView.as_view()),
]
