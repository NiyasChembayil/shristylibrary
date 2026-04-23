from django.db import models
from django.contrib.auth.models import User
from core.models import Book

class Post(models.Model):
    POST_TYPES = (
        ('REVIEW', 'Review'),
        ('QUOTE', 'Quote'),
        ('OPINION', 'Opinion'),
        ('UPDATE', 'Reading Update'),
    )
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='posts')
    text = models.TextField()
    post_type = models.CharField(max_length=20, choices=POST_TYPES, default='UPDATE')
    book = models.ForeignKey(Book, on_delete=models.SET_NULL, null=True, blank=True, related_name='posts')
    parent_post = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True, related_name='reposts')
    is_trending = models.BooleanField(default=False, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} - {self.post_type} - {self.text[:20]}"

class PostLike(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='post_likes')
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'post')

    def __str__(self):
        return f"{self.user.username} liked post {self.post.id}"

class PostComment(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='post_comments')
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='comments')
    text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.username} on post {self.post.id}: {self.text[:20]}"

class PostCommentLike(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='post_comment_likes')
    comment = models.ForeignKey(PostComment, on_delete=models.CASCADE, related_name='likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'comment')

    def __str__(self):
        return f"{self.user.username} liked comment {self.comment.id}"

class Like(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='book_likes')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'book')

    def __str__(self):
        return f"{self.user.username} liked {self.book.title}"

class Comment(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='book_comments')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='comments')
    text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.username} on {self.book.title}: {self.text[:20]}"

class Follow(models.Model):
    follower = models.ForeignKey(User, on_delete=models.CASCADE, related_name='following')
    followed = models.ForeignKey(User, on_delete=models.CASCADE, related_name='followers')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('follower', 'followed')

    def __str__(self):
        return f"{self.follower.username} follows {self.followed.username}"

class Notification(models.Model):
    TYPES = (
        ('LIKE', 'New Like'),
        ('COMMENT', 'New Comment'),
        ('NEW_BOOK', 'New Book'),
        ('FOLLOW', 'New Follower'),
        ('SYSTEM', 'System Message'),
        ('POST_LIKE', 'New Post Like'),
        ('POST_COMMENT', 'New Post Comment'),
        ('REPOST', 'New Repost'),
        ('POST_COMMENT_LIKE', 'New Post Comment Like'),
    )
    
    recipient = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    actor = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True)
    action_type = models.CharField(max_length=20, choices=TYPES)
    book = models.ForeignKey(Book, on_delete=models.CASCADE, null=True, blank=True)
    post = models.ForeignKey(Post, on_delete=models.CASCADE, null=True, blank=True) # Added post foreign key
    message = models.TextField(blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.action_type} for {self.recipient.username}"
