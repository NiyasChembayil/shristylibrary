from django.urls import path, include
from rest_framework_nested import routers
from .views import CategoryViewSet, BookViewSet, ChapterViewSet

router = routers.DefaultRouter()
router.register(r'categories', CategoryViewSet)
router.register(r'books', BookViewSet, basename='book')

books_router = routers.NestedDefaultRouter(router, r'books', lookup='book')
books_router.register(r'chapters', ChapterViewSet, basename='book-chapters')

urlpatterns = [
    path('', include(router.urls)),
    path('', include(books_router.urls)),
]
