from django.urls import path

from . import views

urlpatterns = [
    path("matches", views.MatchesView.as_view()),
    path("matches/<uuid:match_id>/unmatch", views.UnmatchView.as_view()),
]
