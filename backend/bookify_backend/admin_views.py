from rest_framework import viewsets, permissions, response
from rest_framework.decorators import action
from django.contrib.auth.models import User
from django.db.models import Sum, Count, Q
from django.utils import timezone
from datetime import timedelta
from accounts.models import Profile
from core.models import Book, ReadStats, Category
from social.models import Notification
from accounts.audit import log_admin_action
from accounts.models import AuditLog
from .permissions import IsAdminUser

class AdminDashboardViewSet(viewsets.ViewSet):
    """
    ViewSet for administrative dashboard statistics and management.
    """
    permission_classes = [IsAdminUser]

    @action(detail=False, methods=['get'])
    def stats(self, request):
        # User Stats
        total_users = User.objects.count()
        total_authors = Profile.objects.filter(role='author').count()
        total_readers = Profile.objects.filter(role='reader').count()
        
        # Book Stats
        total_books = Book.objects.count()
        published_books = Book.objects.filter(is_published=True).count()
        pending_books = total_books - published_books

        # Live Users (active in last 15 mins)
        fifteen_mins_ago = timezone.now() - timedelta(minutes=15)
        live_users = Profile.objects.filter(updated_at__gt=fifteen_mins_ago).count()
        
        # Category Breakdown
        category_stats = Category.objects.annotate(
            book_count=Count('books'),
            total_reads=Count('books__read_stats')
        ).values('name', 'book_count', 'total_reads')

        # Region Breakdown
        region_stats = Book.objects.values('region').annotate(
            total_reads=Count('read_stats')
        ).order_by('-total_reads')

        # Heatmap (Reads per hour of day)
        heatmap_raw = ReadStats.objects.filter(
            timestamp__gt=timezone.now() - timedelta(days=7)
        ).values('timestamp__hour').annotate(count=Count('id')).order_by('timestamp__hour')
        
        heatmap = {i: 0 for i in range(24)}
        for entry in heatmap_raw:
            heatmap[entry['timestamp__hour']] = entry['count']

        return response.Response({
            'users': {
                'total': total_users,
                'authors': total_authors,
                'readers': total_readers,
                'live': live_users
            },
            'books': {
                'total': total_books,
                'published': published_books,
                'pending': pending_books,
            },
            'revenue': {
                'total': total_books * 1.5, # Simulated revenue for demo
                'purchases': total_books * 10,
            },
            'breakdowns': {
                'categories': list(category_stats),
                'regions': list(region_stats),
            },
            'heatmap': heatmap
        })

    @action(detail=False, methods=['get'])
    def recent_activity(self, request):
        # Last 5 books published
        recent_books = Book.objects.filter(is_published=True).order_by('-created_at')[:5]
        
        return response.Response({
            'books': [{'title': b.title, 'author': b.author.username, 'date': b.created_at} for b in recent_books],
            'purchases': []
        })

    @action(detail=False, methods=['post'])
    def broadcast(self, request):
        message = request.data.get('message')
        if not message:
            return response.Response({'error': 'Message is required'}, status=400)
            
        users = User.objects.all()
        notifications = [
            Notification(
                recipient=user,
                actor=request.user,
                action_type='SYSTEM',
                message=message
            ) for user in users
        ]
        Notification.objects.bulk_create(notifications)
        
        log_admin_action(
            admin=request.user,
            action="SYSTEM_BROADCAST",
            details=f"Broadcast sent to {len(notifications)} users: {message[:100]}...",
            request=request
        )
        
        return response.Response({'status': 'broadcast sent', 'count': len(notifications)})

    @action(detail=False, methods=['post'])
    def message_user(self, request):
        user_id = request.data.get('user_id')
        message = request.data.get('message')
        
        if not user_id or not message:
            return response.Response({'error': 'user_id and message are required'}, status=400)
            
        try:
            target_user = User.objects.get(id=user_id)
            Notification.objects.create(
                recipient=target_user,
                actor=request.user,
                action_type='DIRECT_MESSAGE',
                message=message
            )
            
            log_admin_action(
                admin=request.user,
                action="DIRECT_MESSAGE",
                target=target_user.username,
                details=f"Message to {target_user.username}: {message[:100]}...",
                request=request
            )
            
            return response.Response({'status': 'message sent'})
        except User.DoesNotExist:
            return response.Response({'error': 'User not found'}, status=404)

    @action(detail=False, methods=['get'])
    def audit_logs(self, request):
        logs = AuditLog.objects.all().select_related('admin')[:100]
        return response.Response([
            {
                'id': l.id,
                'admin': l.admin.username,
                'action': l.action,
                'target': l.target,
                'details': l.details,
                'ip': l.ip_address,
                'timestamp': l.timestamp
            } for l in logs
        ])
