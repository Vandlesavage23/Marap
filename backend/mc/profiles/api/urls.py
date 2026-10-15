from django.urls import path

from . import views

urlpatterns = [
    path("me/profile", views.MyProfileView.as_view()),
    path("me/descriptions", views.DescriptionsView.as_view()),
    path("profiles/<uuid:profile_id>", views.PublicProfileView.as_view()),
]
