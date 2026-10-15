from django.urls import path

from . import views

urlpatterns = [
    path("notifications", views.InboxView.as_view()),
    path("notifications/read", views.MarkReadView.as_view()),
]
