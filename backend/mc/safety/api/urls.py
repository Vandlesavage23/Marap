from django.urls import path

from . import views

urlpatterns = [
    path("blocks", views.BlocksView.as_view()),
    path("reports", views.ReportsView.as_view()),
    path("safety/appeals", views.AppealsView.as_view()),
    path("blocks/<uuid:profile_id>", views.UnblockView.as_view()),
]
