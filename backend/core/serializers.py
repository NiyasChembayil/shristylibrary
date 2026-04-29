from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Category, Book, Chapter, ReadStats, Report, StoryBible, ChapterChoice, StoryCharacter, CharacterRelationship, WritingSprint, SprintParticipant, Achievement, UserAchievement, PayoutRequest

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = '__all__'

class ChapterChoiceSerializer(serializers.ModelSerializer):
    class Meta:
        model = ChapterChoice
        fields = ['id', 'text', 'target_chapter']

class ChapterSerializer(serializers.ModelSerializer):
    book = serializers.PrimaryKeyRelatedField(read_only=True)
    is_unlocked = serializers.SerializerMethodField()
    choices = ChapterChoiceSerializer(many=True, read_only=True)

    class Meta:
        model = Chapter
        fields = ['id', 'book', 'title', 'content', 'order', 'audio_file', 'is_premium', 'coins_required', 'is_unlocked', 'choices']

    def get_is_unlocked(self, obj):
        request = self.context.get('request')
        if not obj.is_premium:
            return True
        if request and request.user.is_authenticated:
            # Author always has access
            if obj.book.author == request.user or request.user.is_staff:
                return True
            # Check if user has unlocked it
            from .models import ChapterUnlock
            return ChapterUnlock.objects.filter(user=request.user, chapter=obj).exists()
        return False

class StoryCharacterSerializer(serializers.ModelSerializer):
    class Meta:
        model = StoryCharacter
        fields = '__all__'

class CharacterRelationshipSerializer(serializers.ModelSerializer):
    class Meta:
        model = CharacterRelationship
        fields = '__all__'

class BookSerializer(serializers.ModelSerializer):
    author = serializers.PrimaryKeyRelatedField(read_only=True)
    author_name = serializers.ReadOnlyField(source='author.username')
    author_is_verified = serializers.ReadOnlyField(source='author.profile.is_verified')
    category_name = serializers.ReadOnlyField(source='category.name')
    author_profile_id = serializers.SerializerMethodField()
    category = serializers.PrimaryKeyRelatedField(queryset=Category.objects.all(), required=False, allow_null=True)
    is_author_following = serializers.SerializerMethodField()
    chapters = ChapterSerializer(many=True, read_only=True)
    likes_count = serializers.SerializerMethodField()
    comments_count = serializers.SerializerMethodField()
    is_in_library = serializers.SerializerMethodField()
    is_liked = serializers.SerializerMethodField()
    downloads_count = serializers.SerializerMethodField()
    chapters_count = serializers.SerializerMethodField()
    characters = StoryCharacterSerializer(many=True, read_only=True)

    class Meta:
        model = Book
        fields = [
            'id', 'title', 'slug', 'author', 'author_name', 'author_is_verified', 'author_profile_id', 'is_author_following', 'cover', 'audio_file',
            'description', 'category', 'category_name', 'language', 'tags', 'price', 'region',
            'is_published', 'moderation_status', 'moderation_notes', 'created_at', 'updated_at', 'chapters', 'chapters_count',
            'likes_count', 'comments_count', 'total_reads', 'is_in_library', 'is_liked',
            'downloads_count', 'characters',
            'ai_moderation_score', 'ai_flagged', 'ai_flag_reason', 'plagiarism_score', 'ai_evaluation_status'
        ]

    def get_author_profile_id(self, obj):
        try:
            return obj.author.profile.id
        except:
            return None

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            try:
                return obj.likes.filter(user=request.user).exists()
            except:
                return False
        return False

    def get_is_author_following(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            # Check if the current user follows the author
            return obj.author.followers.filter(follower=request.user).exists()
        return False

    def get_likes_count(self, obj):
        return obj.likes.count()

    def get_comments_count(self, obj):
        return obj.comments.count()

    def get_is_in_library(self, obj):
        from .models import UserLibrary
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return UserLibrary.objects.filter(user=request.user, book=obj).exists()
        return False

    def get_downloads_count(self, obj):
        return obj.total_downloads

    def get_chapters_count(self, obj):
        return obj.chapters.count()

class ReadStatsSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReadStats
        fields = '__all__'

class WritingSprintSerializer(serializers.ModelSerializer):
    participants = serializers.SerializerMethodField()
    participant_count = serializers.IntegerField(source='participants.count', read_only=True)
    
    class Meta:
        model = WritingSprint
        fields = ['id', 'title', 'start_time', 'end_time', 'is_active', 'participants', 'participant_count']

    def get_participants(self, obj):
        # Sort by words written
        participants = obj.participants.all().order_by('-words_written')
        return SprintParticipantSerializer(participants, many=True).data

class SprintParticipantSerializer(serializers.ModelSerializer):
    username = serializers.ReadOnlyField(source='user.username')
    class Meta:
        model = SprintParticipant
        fields = ['id', 'username', 'words_written', 'last_updated']

class ReportSerializer(serializers.ModelSerializer):
    reporter_name = serializers.ReadOnlyField(source='reporter.username')
    target_book_title = serializers.ReadOnlyField(source='target_book.title')
    target_user_name = serializers.ReadOnlyField(source='target_user.username')

    class Meta:
        model = Report
        fields = [
            'id', 'reporter', 'reporter_name', 'target_book', 'target_book_title', 
            'target_user', 'target_user_name', 'reason', 'description', 
            'status', 'admin_notes', 'created_at', 'updated_at'
        ]
        read_only_fields = ['reporter', 'created_at', 'updated_at']

class StoryBibleSerializer(serializers.ModelSerializer):
    class Meta:
        model = StoryBible
        fields = ['id', 'book', 'content', 'updated_at']
        read_only_fields = ['book']

class PayoutRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = PayoutRequest
        fields = ['id', 'author', 'amount', 'status', 'timestamp']

class AchievementSerializer(serializers.ModelSerializer):
    class Meta:
        model = Achievement
        fields = ['id', 'title', 'description', 'icon', 'category', 'criteria_type', 'threshold']

class UserAchievementSerializer(serializers.ModelSerializer):
    achievement = AchievementSerializer(read_only=True)
    
    class Meta:
        model = UserAchievement
        fields = ['id', 'achievement', 'unlocked_at']
