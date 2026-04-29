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
    coins = models.PositiveIntegerField(default=100) # Give new users 100 coins to start
    
    # Writing Goals & Streaks
    daily_word_goal = models.PositiveIntegerField(default=500)
    current_streak = models.PositiveIntegerField(default=0)
    last_writing_date = models.DateField(null=True, blank=True)
    
    # Privacy & Safety
    is_private = models.BooleanField(default=False)
    
    # Notification Preferences
    notify_new_follower = models.BooleanField(default=True)
    notify_likes = models.BooleanField(default=True)
    notify_comments = models.BooleanField(default=True)
    notify_new_books = models.BooleanField(default=True)
    
    # Suspension
    is_suspended = models.BooleanField(default=False)
    suspension_reason = models.TextField(blank=True, null=True)
    suspension_until = models.DateTimeField(blank=True, null=True)
    
    # Verification
    is_verified = models.BooleanField(default=False)
    is_partner = models.BooleanField(default=False)
    verification_id_image = models.ImageField(upload_to='verification_ids/', null=True, blank=True)
    verification_links = models.TextField(blank=True, help_text="Social media or portfolio links")
    verification_status = models.CharField(max_length=20, default='none', choices=(
        ('none', 'Not Submitted'),
        ('pending', 'Pending Review'),
        ('verified', 'Verified'),
        ('rejected', 'Rejected'),
    ))
    
    # Reader & Audio Preferences
    font_size = models.FloatField(default=16.0)
    reader_theme = models.CharField(max_length=20, default='Dark')
    playback_speed = models.FloatField(default=1.0)
    
    # Push Notifications
    fcm_token = models.CharField(max_length=255, null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.user.username}'s Profile"

    @property
    def is_author(self):
        return self.role == 'author'


class AuditLog(models.Model):
    admin = models.ForeignKey(User, on_delete=models.CASCADE, related_name='audit_logs')
    action = models.CharField(max_length=255)
    target = models.CharField(max_length=255, blank=True, null=True)
    details = models.TextField(blank=True, null=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp']

    def __str__(self):
        return f"{self.admin.username} - {self.action} at {self.timestamp}"
