from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.decorators import action
from rest_framework.views import APIView
from django.db.models import Count
from django.contrib.auth.models import User
from .models import Like, Comment, Notification, Follow, Post, PostLike, PostComment, PostCommentLike
from .serializers import LikeSerializer, CommentSerializer, NotificationSerializer, FollowSerializer, PostSerializer, PostCommentSerializer
from core.models import Book
from core.serializers import BookSerializer
from accounts.models import Profile
from accounts.serializers import ProfileSerializer

from core.permissions import IsOwnerOrReadOnly

class PostViewSet(viewsets.ModelViewSet):
    queryset = Post.objects.all()
    serializer_class = PostSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly, IsOwnerOrReadOnly]

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=False, methods=['get'])
    def feed(self, request):
        if not request.user.is_authenticated:
            # If not authenticated, just return trending posts as feed
            posts = Post.objects.annotate(like_count=Count('likes')).order_by('-like_count')[:50]
        else:
            # Home feed: Posts from people I follow + My posts
            following_ids = Follow.objects.filter(follower=request.user).values_list('followed_id', flat=True)
            followed_posts = Post.objects.filter(user_id__in=list(following_ids) + [request.user.id])
            
            # If followed posts are few, mix with trending
            if followed_posts.count() < 10:
                trending_post_ids = list(
                    Post.objects.annotate(like_count=Count('likes'))
                    .order_by('-like_count')
                    .values_list('id', flat=True)[:20]
                )
                followed_post_ids = list(followed_posts.values_list('id', flat=True))
                all_ids = list(set(followed_post_ids + trending_post_ids))
                posts = Post.objects.filter(id__in=all_ids).order_by('?')[:50]
            else:
                posts = followed_posts.order_by('?')[:50]
                
        serializer = self.get_serializer(posts, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def user_posts(self, request):
        user_id = request.query_params.get('user_id')
        if not user_id:
            return Response({'error': 'user_id is required'}, status=status.HTTP_400_BAD_REQUEST)
        posts = Post.objects.filter(user_id=user_id).order_by('-created_at')
        serializer = self.get_serializer(posts, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def trending(self, request):
        try:
            # Trending posts (most likes)
            trending_posts = Post.objects.annotate(like_count=Count('likes')).order_by('-like_count')[:10]
            # Popular books
            popular_books = Book.objects.annotate(like_count=Count('likes')).order_by('-like_count')[:5]
            # Top creators (most followers from the User model's 'followers' relation)
            top_creators = Profile.objects.annotate(
                followers_count=Count('user__followers')
            ).order_by('-followers_count')[:10]
            
            return Response({
                'trending_posts': PostSerializer(trending_posts, many=True, context={'request': request}).data,
                'popular_books': BookSerializer(popular_books, many=True, context={'request': request}).data,
                'top_creators': ProfileSerializer(top_creators, many=True, context={'request': request}).data
            })
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=True, methods=['post'])
    def like(self, request, pk=None):
        post = self.get_object()
        like, created = PostLike.objects.get_or_create(user=request.user, post=post)
        if created and post.user != request.user:
            Notification.objects.create(
                recipient=post.user,
                actor=request.user,
                action_type='POST_LIKE',
                post=post,
                message=f"{request.user.username} liked your post."
            )
        return Response({'status': 'liked', 'likes_count': post.likes.count()})

    @action(detail=True, methods=['post'])
    def unlike(self, request, pk=None):
        post = self.get_object()
        PostLike.objects.filter(user=request.user, post=post).delete()
        return Response({'status': 'unliked', 'likes_count': post.likes.count()})

    @action(detail=True, methods=['post'])
    def repost(self, request, pk=None):
        parent_post = self.get_object()
        repost = Post.objects.create(
            user=request.user,
            text="", # Optionally take extra text from request.data
            post_type='UPDATE',
            parent_post=parent_post
        )
        if parent_post.user != request.user:
            Notification.objects.create(
                recipient=parent_post.user,
                actor=request.user,
                action_type='REPOST',
                post=parent_post,
                message=f"{request.user.username} reposted your post."
            )
        return Response(PostSerializer(repost, context={'request': request}).data, status=status.HTTP_201_CREATED)

class PostCommentViewSet(viewsets.ModelViewSet):
    queryset = PostComment.objects.all()
    serializer_class = PostCommentSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        post_id = self.request.query_params.get('post')
        if post_id:
            return PostComment.objects.filter(post_id=post_id)
        return PostComment.objects.all()

    def perform_create(self, serializer):
        comment = serializer.save(user=self.request.user)
        if comment.post.user != self.request.user:
            Notification.objects.create(
                recipient=comment.post.user,
                actor=self.request.user,
                action_type='POST_COMMENT',
                post=comment.post,
                message=f"{self.request.user.username} commented on your post: {comment.text[:50]}"
            )

    @action(detail=True, methods=['post'])
    def like(self, request, pk=None):
        comment = self.get_object()
        like, created = PostCommentLike.objects.get_or_create(user=request.user, comment=comment)
        if created and comment.user != request.user:
            Notification.objects.create(
                recipient=comment.user,
                actor=request.user,
                action_type='POST_COMMENT_LIKE',
                post=comment.post,
                message=f"{request.user.username} liked your comment: {comment.text[:30]}..."
            )
        return Response({'status': 'liked', 'likes_count': comment.likes.count()})

    @action(detail=True, methods=['post'])
    def unlike(self, request, pk=None):
        comment = self.get_object()
        PostCommentLike.objects.filter(user=request.user, comment=comment).delete()
        return Response({'status': 'unliked', 'likes_count': comment.likes.count()})

class LikeViewSet(viewsets.ModelViewSet):
    queryset = Like.objects.all()
    serializer_class = LikeSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        like = serializer.save(user=self.request.user)
        # Create notification for author
        if like.book.author != self.request.user:
            Notification.objects.create(
                recipient=like.book.author,
                actor=self.request.user,
                action_type='LIKE',
                book=like.book
            )

class CommentViewSet(viewsets.ModelViewSet):
    queryset = Comment.objects.all()
    serializer_class = CommentSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        queryset = Comment.objects.all()
        book_id = self.request.query_params.get('book')
        chapter_id = self.request.query_params.get('chapter')
        
        if chapter_id:
            return queryset.filter(chapter_id=chapter_id)
        if book_id:
            return queryset.filter(book_id=book_id, chapter__isnull=True)
        return queryset

    def perform_create(self, serializer):
        comment = serializer.save(user=self.request.user)
        # Create notification for author
        if comment.book.author != self.request.user:
            Notification.objects.create(
                recipient=comment.book.author,
                actor=self.request.user,
                action_type='COMMENT',
                book=comment.book,
                message=comment.text[:50]
            )

class FollowViewSet(viewsets.ModelViewSet):
    queryset = Follow.objects.all()
    serializer_class = FollowSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Follow.objects.filter(follower=self.request.user)

    def perform_create(self, serializer):
        follow = serializer.save(follower=self.request.user)
        # Create notification for followed user
        Notification.objects.create(
            recipient=follow.followed,
            actor=self.request.user,
            action_type='FOLLOW',
            message=f"{self.request.user.username} started following you."
        )

class NotificationViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(recipient=self.request.user)

    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        notification = self.get_object()
        notification.is_read = True
        notification.save()
        return Response({'status': 'marked as read'})

    @action(detail=False, methods=['post'])
    def mark_all_read(self, request):
        self.get_queryset().update(is_read=True)
        return Response({'status': 'all marked as read'})

    @action(detail=False, methods=['get'])
    def unread_count(self, request):
        count = self.get_queryset().filter(is_read=False).count()
        return Response({'count': count})


class MentionSearchView(APIView):
    """Returns matching users and books for @mention autocomplete."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        q = request.query_params.get('q', '').strip()
        if not q:
            return Response({'users': [], 'books': []})

        users = User.objects.filter(username__icontains=q).select_related('profile')[:7]
        books = Book.objects.filter(title__icontains=q, is_published=True)[:7]

        def build_avatar(user):
            try:
                if user.profile.avatar:
                    return request.build_absolute_uri(user.profile.avatar.url)
            except Exception:
                pass
            return None

        def build_cover(book):
            try:
                if book.cover:
                    return request.build_absolute_uri(book.cover.url)
            except Exception:
                pass
            return None

        return Response({
            'users': [
                {'id': u.id, 'username': u.username, 'avatar': build_avatar(u)}
                for u in users
            ],
            'books': [
                {'id': b.id, 'title': b.title, 'slug': b.slug, 'cover': build_cover(b)}
                for b in books
            ],
        })
