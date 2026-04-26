"""
URL configuration for bookify_backend project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/6.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)
from .admin_views import AdminDashboardViewSet
from rest_framework import routers
from django.views.generic import TemplateView
import os
from django.http import HttpResponse

def list_files(request):
    files = []
    for root, dirs, filenames in os.walk(settings.BASE_DIR):
        for f in filenames:
            files.append(os.path.relpath(os.path.join(root, f), settings.BASE_DIR))
    return HttpResponse("<br>".join(files))

router = routers.DefaultRouter()
router.register(r'admin-stats', AdminDashboardViewSet, basename='admin-stats')

urlpatterns = [
    # Frontend Apps
    path('', TemplateView.as_view(template_name='web_client/index.html'), name='universal-studio'),
    path('index.html', TemplateView.as_view(template_name='web_client/index.html')),
    path('studio/', TemplateView.as_view(template_name='web_client/studio.html'), name='author-studio'),
    path('studio.html', TemplateView.as_view(template_name='web_client/studio.html')),
    path('portal/', TemplateView.as_view(template_name='web_admin/index.html'), name='admin-ui'),
    path('debug-files/', list_files),

    path('admin/', admin.site.urls),
    
    # Auth
    path('api/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    
    # App APIs
    path('api/accounts/', include('accounts.urls')),
    path('api/core/', include('core.urls')),
    path('api/social/', include('social.urls')),
    path('api/admin/', include(router.urls)),
]

from django.urls import re_path
from django.views.static import serve

urlpatterns += [
    re_path(r'^media/(?P<path>.*)$', serve, {
        'document_root': settings.MEDIA_ROOT,
    }),
]
