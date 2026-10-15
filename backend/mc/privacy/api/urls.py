from django.urls import path

from . import views

urlpatterns = [
    path("me/reauth/start", views.ReauthStartView.as_view()),
    path("me/export", views.ExportView.as_view()),
    path("me/export/<uuid:request_id>", views.ExportDetailView.as_view()),
]
