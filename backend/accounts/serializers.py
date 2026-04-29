import base64
import uuid
from django.core.files.base import ContentFile
from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Profile

class Base64ImageField(serializers.ImageField):
    def to_internal_value(self, data):
        if isinstance(data, str) and data.startswith('data:image'):
            # format: data:image/jpeg;base64,...
            header, data_str = data.split(';base64,')
            try:
                decoded_file = base64.b64decode(data_str)
            except TypeError:
                self.fail('invalid_image')
            
            ext = header.split('/')[-1]
            if ext == 'jpeg':
                ext = 'jpg'
            file_name = f"{uuid.uuid4()}.{ext}"
            data = ContentFile(decoded_file, name=file_name)
            
        return super().to_internal_value(data)

class ProfileSerializer(serializers.ModelSerializer):
    avatar = Base64ImageField(required=False, allow_null=True)
    verification_id_image = Base64ImageField(required=False, allow_null=True)
    username = serializers.CharField(source='user.username', required=False)
    email = serializers.EmailField(source='user.email', required=False)
    # Password is write-only for the 'Change Password' feature
    password = serializers.CharField(write_only=True, required=False, min_length=8)
    user_id = serializers.ReadOnlyField(source='user.id')
    followers_count = serializers.SerializerMethodField()
    following_count = serializers.SerializerMethodField()
    is_following = serializers.SerializerMethodField()

    class Meta:
        model = Profile
        fields = [
            'id', 'user_id', 'username', 'email', 'password', 'role', 'bio', 'avatar', 
            'followers_count', 'following_count', 'is_following', 'is_verified',
            'verification_id_image', 'verification_links', 'verification_status',
            'is_private', 'notify_new_follower', 'notify_likes', 'notify_comments', 
            'notify_new_books', 'font_size', 'reader_theme', 'playback_speed'
        ]
        read_only_fields = ['id', 'user_id', 'role', 'followers_count', 'following_count', 'is_following', 'is_verified', 'verification_status']

    def validate_username(self, value):
        user = self.instance.user if self.instance else None
        if User.objects.exclude(pk=user.pk if user else None).filter(username__iexact=value).exists():
            raise serializers.ValidationError("This username is already taken.")
        return value

    def validate_email(self, value):
        user = self.instance.user if self.instance else None
        if User.objects.exclude(pk=user.pk if user else None).filter(email__iexact=value).exists():
            raise serializers.ValidationError("This email is already registered.")
        return value

    def update(self, instance, validated_data):
        user_data = validated_data.pop('user', {})
        password = validated_data.pop('password', None)
        
        # Update Profile fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        # Update User fields (username, email)
        user = instance.user
        if 'username' in user_data:
            user.username = user_data['username']
        if 'email' in user_data:
            user.email = user_data['email']
        
        # Handle password update
        if password:
            user.set_password(password)
            
        user.save()
        return instance

    def get_followers_count(self, obj):
        return obj.user.followers.count()

    def get_following_count(self, obj):
        return obj.user.following.count()

    def get_is_following(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.user.followers.filter(follower=request.user).exists()
        return False


class UserSerializer(serializers.ModelSerializer):
    profile = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'password', 'profile']
        extra_kwargs = {'password': {'write_only': True}}

    def get_profile(self, obj):
        try:
            profile = obj.profile
            return ProfileSerializer(profile, context=self.context).data
        except (AttributeError, Profile.DoesNotExist):
            # Self-healing: try to create if missing, or return None
            return None

    def create(self, validated_data):
        profile_data = validated_data.pop('profile', {})
        user = User.objects.create_user(**validated_data)
        Profile.objects.filter(user=user).update(**profile_data)
        return user


class UserListSerializer(serializers.ModelSerializer):
    avatar = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'username', 'avatar']

    def get_avatar(self, obj):
        if hasattr(obj, 'profile') and obj.profile.avatar:
            return obj.profile.avatar.url
        return None


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    role = serializers.CharField(write_only=True, required=False, default='reader')

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'role']

    def validate_username(self, value):
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError("This username is already taken.")
        return value

    def validate_email(self, value):
        if value and value.strip():
            if User.objects.filter(email__iexact=value.strip()).exists():
                raise serializers.ValidationError("This email is already registered.")
        return value.strip() if value else ""

    def create(self, validated_data):
        # Allow specifying role during registration, but default to 'reader'
        role = validated_data.pop('role', 'reader')
        if role not in ['reader', 'author']:
            role = 'reader'

        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password']
        )
        # Ensure profile exists and set role safely (avoiding race conditions with signals)
        Profile.objects.update_or_create(user=user, defaults={'role': role})
        return user

class AdminUserHistorySerializer(serializers.ModelSerializer):
    username = serializers.ReadOnlyField(source='user.username')
    email = serializers.ReadOnlyField(source='user.email')
    total_reads = serializers.SerializerMethodField()
    published_books = serializers.SerializerMethodField()
    reports_received = serializers.SerializerMethodField()
    
    class Meta:
        model = Profile
        fields = [
            'id', 'username', 'email', 'role', 'bio', 'avatar', 'is_verified', 'is_partner',
            'verification_id_image', 'verification_status', 'is_suspended', 
            'current_streak', 'xp', 'level', 'total_reads', 'published_books', 
            'reports_received', 'created_at'
        ]

    def get_total_reads(self, obj):
        from core.models import ReadStats
        return ReadStats.objects.filter(user=obj.user).count()

    def get_published_books(self, obj):
        from core.models import Book
        books = Book.objects.filter(author=obj.user)
        return [{'id': b.id, 'title': b.title, 'status': b.moderation_status} for b in books]

    def get_reports_received(self, obj):
        from core.models import Report
        reports = Report.objects.filter(target_user=obj.user)
        return [{'id': r.id, 'reason': r.reason, 'status': r.status} for r in reports]
