from django.db import models
from django.contrib.auth.models import User

class Profile(models.Model):
    ROLE_CHOICES = (
        ('reader', 'Reader'),
        ('author', 'Author'),
        ('admin', 'Admin'),
    )
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='reader')
    bio = models.TextField(blank=True)
    avatar = models.ImageField(upload_to='avatars/', null=True, blank=True)
    
    # Privacy & Safety
    is_private = models.BooleanField(default=False)
    
    # Notification Preferences
    notify_new_follower = models.BooleanField(default=True)
    notify_likes = models.BooleanField(default=True)
    notify_comments = models.BooleanField(default=True)
    notify_new_books = models.BooleanField(default=True)
    
    # Reader & Audio Preferences
    font_size = models.FloatField(default=16.0)
    reader_theme = models.CharField(max_length=20, default='Dark')
    playback_speed = models.FloatField(default=1.0)
    
    def __str__(self):
        return f"{self.user.username}'s Profile"

    @property
    def is_author(self):
        return self.role == 'author'
