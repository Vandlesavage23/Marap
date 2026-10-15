from django.urls import path

from . import views

urlpatterns = [
    path("billing/products", views.ProductsView.as_view()),
    path("billing/store/verify", views.StoreVerifyView.as_view()),
    path("webhooks/apple", views.AppleWebhookView.as_view()),
    path("webhooks/google", views.GoogleWebhookView.as_view()),
]
