from django.urls import path

from . import views

urlpatterns = [
    path("blocks", views.BlocksView.as_view()),
    path("blocks/<uuid:profile_id>", views.UnblockView.as_view()),
]
