from django.urls import path

from . import views

urlpatterns = [path("config/flags", views.FlagsView.as_view())]
