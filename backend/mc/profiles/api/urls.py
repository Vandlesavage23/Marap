from django.urls import path

from . import views

urlpatterns = [
    path("me/profile", views.MyProfileView.as_view()),
    path("me/preferences", views.PreferencesView.as_view()),
    path("me/photos", views.PhotosView.as_view()),
    path("me/photos/order", views.PhotoOrderView.as_view()),
    path("me/photos/<uuid:photo_id>", views.PhotoDetailView.as_view()),
    path("me/profile/go-live", views.GoLiveView.as_view()),
    path("me/profile/hide", views.HideView.as_view()),
    path("me/profile/unhide", views.UnhideView.as_view()),
    path("me/descriptions", views.DescriptionsView.as_view()),
    path("profiles/<uuid:profile_id>", views.PublicProfileView.as_view()),
]
