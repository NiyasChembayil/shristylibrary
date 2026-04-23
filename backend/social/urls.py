from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import LikeViewSet, CommentViewSet, NotificationViewSet, FollowViewSet, PostViewSet, PostCommentViewSet, MentionSearchView

router = DefaultRouter()
router.register(r'likes', LikeViewSet)
router.register(r'comments', CommentViewSet)
router.register(r'follows', FollowViewSet)
router.register(r'notifications', NotificationViewSet, basename='notification')
router.register(r'posts', PostViewSet, basename='post')
router.register(r'post-comments', PostCommentViewSet, basename='post-comment')

urlpatterns = [
    path('', include(router.urls)),
    path('mention-search/', MentionSearchView.as_view(), name='mention-search'),
]
