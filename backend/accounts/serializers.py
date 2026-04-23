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
            'followers_count', 'following_count', 'is_following',
            'is_private', 'notify_new_follower', 'notify_likes', 'notify_comments', 
            'notify_new_books', 'font_size', 'reader_theme', 'playback_speed'
        ]
        read_only_fields = ['id', 'user_id', 'role', 'followers_count', 'following_count', 'is_following']

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

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return value

    def validate_username(self, value):
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError("This username is already taken.")
        return value

    def create(self, validated_data):
        role = validated_data.pop('role', 'reader')
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password']
        )
        # Ensure profile exists and set role
        if hasattr(user, 'profile'):
            user.profile.role = role
            user.profile.save()
        return user
