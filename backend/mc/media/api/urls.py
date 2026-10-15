from django.urls import path

from . import views

urlpatterns = [
    path("media/uploads", views.UploadsView.as_view()),
    path("media/<uuid:media_id>/complete", views.CompleteView.as_view()),
    path("media/<uuid:media_id>", views.MediaDetailView.as_view()),
]
