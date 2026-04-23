from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Category, Book, Chapter, ReadStats

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = '__all__'

class ChapterSerializer(serializers.ModelSerializer):
    book = serializers.PrimaryKeyRelatedField(read_only=True)
    class Meta:
        model = Chapter
        fields = ['id', 'title', 'content', 'order']

class BookSerializer(serializers.ModelSerializer):
    author = serializers.PrimaryKeyRelatedField(read_only=True)
    author_name = serializers.ReadOnlyField(source='author.username')
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

    class Meta:
        model = Book
        fields = [
            'id', 'title', 'slug', 'author', 'author_name', 'author_profile_id', 'is_author_following', 'cover', 'audio_file',
            'description', 'category', 'category_name', 'language', 'tags', 'price', 'region',
            'is_published', 'created_at', 'updated_at', 'chapters',
            'likes_count', 'comments_count', 'total_reads', 'is_in_library', 'is_liked',
            'downloads_count'
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

class ReadStatsSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReadStats
        fields = '__all__'
