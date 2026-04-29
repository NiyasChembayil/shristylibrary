from django.urls import path, include
from rest_framework_nested import routers
from .views import (
    CategoryViewSet, BookViewSet, ChapterViewSet, ReportViewSet, 
    StoryBibleViewSet, StoryCharacterViewSet, CharacterRelationshipViewSet,
    WritingSprintViewSet, AchievementViewSet, SavedResponseViewSet,
    PlatformSettingsViewSet
)

router = routers.DefaultRouter()
router.register(r'categories', CategoryViewSet)
router.register(r'books', BookViewSet, basename='book')
router.register(r'reports', ReportViewSet, basename='report')
router.register(r'story-bible', StoryBibleViewSet, basename='story-bible')
router.register(r'characters', StoryCharacterViewSet, basename='character')
router.register(r'relationships', CharacterRelationshipViewSet, basename='relationship')
router.register(r'sprints', WritingSprintViewSet, basename='sprint')
router.register(r'achievements', AchievementViewSet, basename='achievement')
router.register(r'saved-responses', SavedResponseViewSet, basename='saved-response')
router.register(r'settings', PlatformSettingsViewSet, basename='platform-settings')

books_router = routers.NestedDefaultRouter(router, r'books', lookup='book')
books_router.register(r'chapters', ChapterViewSet, basename='book-chapters')

urlpatterns = [
    path('', include(router.urls)),
    path('', include(books_router.urls)),
]
