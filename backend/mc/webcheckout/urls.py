from django.urls import path

from . import views

urlpatterns = [
    path("", views.products, name="pay-products"),
    path("delete-account", views.delete_account_info, name="pay-delete-info"),
    path("login", views.login, name="pay-login"),
    path("code", views.code, name="pay-code"),
    path("logout", views.logout, name="pay-logout"),
    path("pay/<str:code>", views.pay, name="pay-pay"),
    path("status/<uuid:purchase_id>", views.status, name="pay-status"),
]
