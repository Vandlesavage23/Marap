from django.urls import path

from . import views

urlpatterns = [
    path("questions", views.QuestionsView.as_view()),
    path("me/answers", views.MyAnswersView.as_view()),
]
