from django.db import models
from django.contrib.auth.models import User
from django.utils.text import slugify

class Category(models.Model):
    name = models.CharField(max_length=100)
    slug = models.SlugField(unique=True)

    def __str__(self):
        return self.name

class BookQuerySet(models.QuerySet):
    def approved(self):
        return self.filter(moderation_status='approved')

    def order_for_discovery(self):
        return self.approved().order_by('?') 

class Book(models.Model):
    MODERATION_STATUS = (
        ('pending', 'Pending Approval'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    )
    objects = BookQuerySet.as_manager()
    title = models.CharField(max_length=255)
    slug = models.SlugField(unique=True, null=True, blank=True)
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='books')
    cover = models.ImageField(upload_to='book_covers/', null=True, blank=True)
    description = models.TextField()
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, related_name='books')
    language = models.CharField(max_length=50, default='English', db_index=True)
    tags = models.CharField(max_length=255, blank=True, null=True, help_text="Comma separated tags e.g. #romance, #fantasy")
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0.00) # Legacy field, platform is free
    is_published = models.BooleanField(default=False)
    region = models.CharField(max_length=50, default='Global', db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    audio_file = models.FileField(upload_to='book_audio/', null=True, blank=True)
    moderation_status = models.CharField(max_length=20, choices=MODERATION_STATUS, default='pending', db_index=True)
    moderation_notes = models.TextField(blank=True, null=True)

    class Meta:
        indexes = [
            models.Index(fields=['title']),
            models.Index(fields=['slug']),
        ]

    def save(self, *args, **kwargs):
        if not self.slug:
            base_slug = slugify(self.title)
            slug = base_slug
            counter = 1
            while Book.objects.filter(slug=slug).exists():
                slug = f"{base_slug}-{counter}"
                counter += 1
            self.slug = slug
        super().save(*args, **kwargs)

    def __str__(self):
        return self.title

    @property
    def total_reads(self):
        return self.read_stats.count()

    @property
    def total_downloads(self):
        return UserLibrary.objects.filter(book=self).count()

class Chapter(models.Model):
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='chapters')
    title = models.CharField(max_length=255)
    content = models.TextField(null=True, blank=True) # Rich text content
    order = models.PositiveIntegerField(default=0)
    audio_file = models.FileField(upload_to='chapter_audio/', null=True, blank=True)
    is_premium = models.BooleanField(default=False)
    coins_required = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['order']
        unique_together = ('book', 'order')

    def __str__(self):
        return f"{self.book.title} - {self.title}"


class ChapterUnlock(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='unlocked_chapters')
    chapter = models.ForeignKey(Chapter, on_delete=models.CASCADE, related_name='unlocks')
    unlocked_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'chapter')

    def __str__(self):
        return f"{self.user.username} unlocked {self.chapter.title}"


class StoryBible(models.Model):
    book = models.OneToOneField(Book, on_delete=models.CASCADE, related_name='bible')
    content = models.TextField(blank=True, default='')
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Bible for {self.book.title}"


class StoryCharacter(models.Model):
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='characters')
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    role = models.CharField(max_length=100, blank=True)
    color = models.CharField(max_length=7, default='#4F46E5')

    def __str__(self):
        return f"{self.name} ({self.book.title})"


class CharacterRelationship(models.Model):
    REL_TYPES = (
        ('friend', 'Friend'),
        ('enemy', 'Enemy'),
        ('family', 'Family'),
        ('lover', 'Lover'),
        ('ally', 'Ally'),
        ('other', 'Other'),
    )
    from_character = models.ForeignKey(StoryCharacter, on_delete=models.CASCADE, related_name='relationships_from')
    to_character = models.ForeignKey(StoryCharacter, on_delete=models.CASCADE, related_name='relationships_to')
    type = models.CharField(max_length=20, choices=REL_TYPES, default='friend')
    description = models.CharField(max_length=255, blank=True)

    def __str__(self):
        return f"{self.from_character.name} -> {self.to_character.name} ({self.type})"

class ChapterVersion(models.Model):
    chapter = models.ForeignKey(Chapter, on_delete=models.CASCADE, related_name='versions')
    content = models.TextField()
    word_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Version of {self.chapter.title} at {self.created_at}"


class DailyWritingStats(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='writing_stats')
    date = models.DateField(auto_now_add=True)
    word_count = models.PositiveIntegerField(default=0)
    goal_reached = models.BooleanField(default=False)

    class Meta:
        unique_together = ('user', 'date')

    def __str__(self):
        return f"{self.user.username} - {self.date}: {self.word_count} words"


class ReadStats(models.Model):
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='read_stats')
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

class ChapterRead(models.Model):
    chapter = models.ForeignKey(Chapter, on_delete=models.CASCADE, related_name='reads')
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    is_completed = models.BooleanField(default=False)
    seconds_read = models.IntegerField(default=0)
    timestamp = models.DateTimeField(auto_now_add=True)

class UserLibrary(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='library')
    book = models.ForeignKey(Book, on_delete=models.CASCADE)
    added_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'book')
        verbose_name_plural = "User Libraries"

    def __str__(self):
        return f"{self.user.username}'s library: {self.book.title}"


class ChapterChoice(models.Model):
    source_chapter = models.ForeignKey(Chapter, on_delete=models.CASCADE, related_name='choices')
    text = models.CharField(max_length=255)
    target_chapter = models.ForeignKey(Chapter, on_delete=models.CASCADE, related_name='incoming_choices')

    def __str__(self):
        return f"Choice from {self.source_chapter.title}: {self.text} -> {self.target_chapter.title}"


class Report(models.Model):
    REASON_CHOICES = (
        ('copyright', 'Copyright Infringement'),
        ('inappropriate', 'Inappropriate Content'),
        ('spam', 'Spam / Scams'),
        ('harassment', 'Harassment'),
        ('other', 'Other'),
    )
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('resolved', 'Resolved'),
        ('ignored', 'Ignored'),
    )
    
    reporter = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reports_filed')
    target_book = models.ForeignKey(Book, on_delete=models.CASCADE, null=True, blank=True, related_name='reports')
    target_user = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True, related_name='reports_received')
    reason = models.CharField(max_length=20, choices=REASON_CHOICES)
    description = models.TextField()
    status = models.CharField(max_length=15, choices=STATUS_CHOICES, default='pending')
    admin_notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        target = self.target_book.title if self.target_book else self.target_user.username
        return f"Report on {target} - {self.reason}"


class SupportTicket(models.Model):
    STATUS_CHOICES = (
        ('open', 'Open'),
        ('in_progress', 'In Progress'),
        ('closed', 'Closed'),
    )
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='tickets')
    subject = models.CharField(max_length=255)
    message = models.TextField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='open')
    admin_response = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']


class AppBanner(models.Model):
    title = models.CharField(max_length=100)
    image = models.ImageField(upload_to='banners/')
    target_url = models.CharField(max_length=255, blank=True, null=True, help_text="Link or book slug")
    is_active = models.BooleanField(default=True)
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['order']


class Transaction(models.Model):
    TYPE_CHOICES = (
        ('purchase', 'Book Purchase'),
        ('payout', 'Author Payout'),
        ('gift', 'Gift'),
    )
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='transactions')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    status = models.CharField(max_length=20, default='completed')
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp']


class PayoutRequest(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('processed', 'Processed'),
        ('rejected', 'Rejected'),
    )
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='payout_requests')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp']

