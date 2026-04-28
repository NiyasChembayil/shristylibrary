from rest_framework import viewsets, permissions, status, filters
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.response import Response
from rest_framework.decorators import action
from django.contrib.auth.models import User
from django.utils import timezone
from .models import Profile
from .serializers import UserSerializer, ProfileSerializer, RegisterSerializer, UserListSerializer, AdminUserHistorySerializer
from core.models import ReadStats
from social.models import Follow, Notification
from .permissions import IsOwnerOrReadOnly
from .audit import log_admin_action

class AuthViewSet(viewsets.GenericViewSet):
    permission_classes = [permissions.AllowAny]
    serializer_class = RegisterSerializer

    @action(detail=False, methods=['post'])
    def register(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'])
    def password_reset(self, request):
        email = request.data.get('email')
        if not email:
            return Response({"error": "Email is required."}, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if user exists
        user_exists = User.objects.filter(email=email).exists()
        
        # We return success regardless to avoid account enumeration (security best practice)
        # In a real app, we would only queue the email if the user exists.
        return Response({
            "message": "If an account with that email exists, a password reset link has been sent.",
            "status": "success"
        }, status=status.HTTP_200_OK)

class ProfileViewSet(viewsets.ModelViewSet):
    queryset = Profile.objects.all()
    serializer_class = ProfileSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly, IsOwnerOrReadOnly]
    filter_backends = [filters.SearchFilter, DjangoFilterBackend]
    filterset_fields = ['is_verified', 'role']
    search_fields = ['user__username', 'bio']

    def get_queryset(self):
        if self.action == 'me':
            return Profile.objects.filter(user=self.request.user)
        return super().get_queryset()

    @action(detail=False, methods=['get', 'put', 'patch'])
    def me(self, request):
        if not request.user.is_authenticated:
            return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)
            
        profile, created = Profile.objects.get_or_create(user=request.user)
        if request.method == 'GET':
            serializer = self.get_serializer(profile)
            return Response(serializer.data)
            
        # Handle User model updates if present in data
        user_updated = False
        user = request.user
        if 'username' in request.data and request.data['username']:
            user.username = request.data['username']
            user_updated = True
        if 'email' in request.data and request.data['email']:
            user.email = request.data['email']
            user_updated = True
            
        if user_updated:
            user.save()

        # Handle Profile model updates
        serializer = self.get_serializer(profile, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def follow(self, request, pk=None):
        profile = self.get_object()
        if profile.user == request.user:
            return Response({"error": "You cannot follow yourself."}, status=status.HTTP_400_BAD_REQUEST)
        
        follow_rel = Follow.objects.filter(follower=request.user, followed=profile.user)
        if follow_rel.exists():
            follow_rel.delete()
            return Response({"status": "unfollowed"})
        else:
            Follow.objects.create(follower=request.user, followed=profile.user)
            Notification.objects.create(
                recipient=profile.user,
                actor=request.user,
                action_type='FOLLOW',
                message=f"{request.user.username} started following you."
            )
            return Response({"status": "followed"})

    @action(detail=True, methods=['get'])
    def followers(self, request, pk=None):
        profile = self.get_object()
        # Users who are following this profile's owner
        follows = Follow.objects.filter(followed=profile.user).select_related('follower')
        followers_users = [f.follower for f in follows]
        serializer = UserListSerializer(followers_users, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['get'])
    def following(self, request, pk=None):
        profile = self.get_object()
        # Users who this profile's owner is following
        follows = Follow.objects.filter(follower=profile.user).select_related('followed')
        following_users = [f.followed for f in follows]
        serializer = UserListSerializer(following_users, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['get'])
    def activity(self, request, pk=None):
        profile = self.get_object()
        
        # Calculate daily activity for the ACTUAL last 7 days (trailing)
        today = timezone.localdate()
        results = []
        
        # We iterate backwards from today for 7 days
        for i in range(6, -1, -1):
            date = today - timezone.timedelta(days=i)
            count = ReadStats.objects.filter(
                user=profile.user,
                timestamp__date=date
            ).count()
            results.append({
                "date": date.isoformat(),
                "count": count
            })
            
        return Response({"activity": results})
    
    @action(detail=False, methods=['get'], url_path='by_user/(?P<user_id>[0-9]+)')
    def by_user(self, request, user_id=None):
        try:
            profile = Profile.objects.get(user_id=user_id)
            serializer = self.get_serializer(profile)
            return Response(serializer.data)
        except Profile.DoesNotExist:
            return Response({"error": "Profile not found"}, status=status.HTTP_404_NOT_FOUND)

        return Response({"status": "already_author", "role": profile.role})

    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def submit_verification(self, request):
        profile = request.user.profile
        if profile.role != 'author':
            return Response({"error": "Only authors can apply for verification."}, status=status.HTTP_400_BAD_REQUEST)
        
        serializer = self.get_serializer(profile, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        # Manually set status to pending
        serializer.save(verification_status='pending')
        
        return Response({"status": "success", "message": "Verification request submitted for admin review."})

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def toggle_verify(self, request, pk=None):
        if not hasattr(request.user, 'profile') or request.user.profile.role != 'admin':
            return Response({"error": "Permission denied"}, status=status.HTTP_403_FORBIDDEN)
        profile = self.get_object()
        profile.is_verified = not profile.is_verified
        profile.save()

        # Send notification if verified
        if profile.is_verified:
            from social.models import Notification
            Notification.objects.create(
                recipient=profile.user,
                actor=request.user,
                action_type='SYSTEM',
                message="Congratulations! 🎉 Your account has been officially verified with the Blue Tick. Welcome to the verified elite of Srishty!"
            )

        return Response({"status": "success", "is_verified": profile.is_verified})

    @action(detail=False, methods=['post'])
    def update_fcm_token(self, request):
        token = request.data.get('token')
        if not token:
            return Response({"error": "Token is required"}, status=status.HTTP_400_BAD_REQUEST)
        
        profile.fcm_token = token
        profile.save()
        return Response({"status": "success"})


class AdminProfileViewSet(viewsets.ModelViewSet):
    queryset = Profile.objects.all().select_related('user')
    serializer_class = AdminUserHistorySerializer
    permission_classes = [permissions.IsAdminUser]

    @action(detail=True, methods=['get'])
    def history(self, request, pk=None):
        profile = self.get_object()
        serializer = self.get_serializer(profile)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def verify_approve(self, request, pk=None):
        profile = self.get_object()
        profile.is_verified = True
        profile.verification_status = 'verified'
        profile.save()
        
        log_admin_action(
            admin=request.user,
            action="VERIFIED_AUTHOR",
            target=profile.user.username,
            details=f"Verified author {profile.user.username}",
            request=request
        )

        Notification.objects.create(
            recipient=profile.user,
            actor=request.user,
            action_type='SYSTEM',
            message="Congratulations! 🎉 Your account has been officially verified with the Blue Tick."
        )
        return Response({"status": "verified"})

    @action(detail=True, methods=['post'])
    def verify_reject(self, request, pk=None):
        profile = self.get_object()
        profile.is_verified = False
        profile.verification_status = 'rejected'
        profile.save()
        
        log_admin_action(
            admin=request.user,
            action="REJECTED_VERIFICATION",
            target=profile.user.username,
            details=f"Rejected verification for {profile.user.username}",
            request=request
        )

        Notification.objects.create(
            recipient=profile.user,
            actor=request.user,
            action_type='SYSTEM',
            message="Your verification request was declined. Please ensure your links and ID are clear."
        )
        return Response({"status": "rejected"})

    @action(detail=False, methods=['post'])
    def bulk_verify(self, request):
        user_ids = request.data.get('user_ids', [])
        if not user_ids:
            return Response({"error": "No user IDs provided"}, status=400)
            
        profiles = Profile.objects.filter(id__in=user_ids)
        count = profiles.count()
        profiles.update(is_verified=True, verification_status='verified')
        
        log_admin_action(
            admin=request.user,
            action="BULK_VERIFY",
            details=f"Bulk verified {count} users: {list(profiles.values_list('user__username', flat=True))}",
            request=request
        )
        
        return Response({"status": "success", "count": count})
