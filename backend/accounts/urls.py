from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ProfileViewSet, AuthViewSet, AdminProfileViewSet

router = DefaultRouter()
router.register(r'profile', ProfileViewSet)
router.register(r'auth', AuthViewSet, basename='auth')
router.register(r'admin-profiles', AdminProfileViewSet, basename='admin-profiles')

urlpatterns = [
    path('', include(router.urls)),
]
