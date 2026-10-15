from django.urls import path

from . import views

urlpatterns = [
    path("matches/<uuid:match_id>/messages", views.MessagesView.as_view()),
    path("matches/<uuid:match_id>/read", views.ReadView.as_view()),
]
