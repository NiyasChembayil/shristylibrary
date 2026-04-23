from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ProfileViewSet, AuthViewSet

router = DefaultRouter()
router.register(r'profile', ProfileViewSet)
router.register(r'auth', AuthViewSet, basename='auth')

urlpatterns = [
    path('', include(router.urls)),
]
