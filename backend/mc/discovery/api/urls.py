from django.urls import path

from . import views

urlpatterns = [
    path("discovery", views.DiscoveryView.as_view()),
    path("discovery/guest", views.GuestDiscoveryView.as_view()),
    path("discovery/feedback", views.FeedbackView.as_view()),
]
