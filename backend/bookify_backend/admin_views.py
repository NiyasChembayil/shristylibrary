from rest_framework import viewsets, permissions, response
from rest_framework.decorators import action
from django.contrib.auth.models import User
from django.db.models import Sum, Count, Q
from django.utils import timezone
from datetime import timedelta
from accounts.models import Profile
from core.models import Book, ReadStats, Category, SupportTicket, AppBanner, Transaction, PayoutRequest, ChapterRead
from social.models import Notification
from accounts.audit import log_admin_action
from accounts.models import AuditLog
from django.core.mail import send_mail
from django.conf import settings
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

    @action(detail=False, methods=['post'])
    def suspend_user(self, request):
        user_id = request.data.get('user_id')
        reason = request.data.get('reason', 'Violation of terms')
        days = int(request.data.get('days', 7))
        
        try:
            profile = Profile.objects.get(user_id=user_id)
            profile.is_suspended = True
            profile.suspension_reason = reason
            profile.suspension_until = timezone.now() + timedelta(days=days)
            profile.save()
            
            log_admin_action(
                admin=request.user,
                action="USER_SUSPEND",
                target=profile.user.username,
                details=f"Suspended for {days} days. Reason: {reason}",
                request=request
            )
            return response.Response({'status': 'user suspended'})
        except Profile.DoesNotExist:
            return response.Response({'error': 'User not found'}, status=404)

    @action(detail=False, methods=['post'])
    def reset_password(self, request):
        user_id = request.data.get('user_id')
        new_password = request.data.get('new_password')
        
        if not new_password:
            return response.Response({'error': 'new_password is required'}, status=400)
            
        try:
            user = User.objects.get(id=user_id)
            user.set_password(new_password)
            user.save()
            
            log_admin_action(
                admin=request.user,
                action="PASSWORD_RESET",
                target=user.username,
                details="Manual password reset by admin",
                request=request
            )
            return response.Response({'status': 'password reset successfully'})
        except User.DoesNotExist:
            return response.Response({'error': 'User not found'}, status=404)

    @action(detail=False, methods=['get'])
    def financial_stats(self, request):
        # In a real app, these would come from the Transaction model
        # For now, we mix real aggregations with some mock growth data
        total_revenue = Transaction.objects.filter(type='purchase', status='completed').aggregate(Sum('amount'))['amount__sum'] or 0
        total_payouts = Transaction.objects.filter(type='payout', status='completed').aggregate(Sum('amount'))['amount__sum'] or 0
        
        pending_payouts = PayoutRequest.objects.filter(status='pending').aggregate(Sum('amount'))['amount__sum'] or 0
        
        # Breakdown by category
        cat_revenue = Book.objects.values('category__name').annotate(
            revenue=Count('read_stats') * 0.5 # Mock revenue per read
        ).order_by('-revenue')

        return response.Response({
            'total_revenue': float(total_revenue),
            'total_payouts': float(total_payouts),
            'pending_payouts': float(pending_payouts),
            'category_breakdown': list(cat_revenue),
            'recent_transactions': Transaction.objects.all().values('user__username', 'amount', 'type', 'timestamp')[:20]
        })

    @action(detail=False, methods=['get'])
    def drop_off_stats(self, request):
        book_id = request.query_params.get('book_id')
        if not book_id:
            return response.Response({'error': 'book_id required'}, status=400)
            
        chapters = ChapterRead.objects.filter(chapter__book_id=book_id).values('chapter__title', 'chapter__order').annotate(
            total_reads=Count('id'),
            completions=Count('id', filter=Q(is_completed=True))
        ).order_by('chapter__order')
        
        return response.Response(list(chapters))

    @action(detail=False, methods=['get'])
    def tickets(self, request):
        status = request.query_params.get('status', 'open')
        tickets = SupportTicket.objects.filter(status=status).values(
            'id', 'user__username', 'subject', 'message', 'status', 'created_at'
        )
        return response.Response(list(tickets))

    @action(detail=False, methods=['post'])
    def respond_ticket(self, request):
        ticket_id = request.data.get('ticket_id')
        msg = request.data.get('response')
        
        try:
            ticket = SupportTicket.objects.get(id=ticket_id)
            ticket.admin_response = msg
            ticket.status = 'closed'
            ticket.save()
            
            # Send notification to user
            Notification.objects.create(
                recipient=ticket.user,
                actor=request.user,
                action_type='SYSTEM',
                message=f"Admin responded to your ticket: {msg[:50]}..."
            )
            
            return response.Response({'status': 'responded'})
        except SupportTicket.DoesNotExist:
            return response.Response({'error': 'Ticket not found'}, status=404)

    @action(detail=False, methods=['get'])
    def banners(self, request):
        banners = AppBanner.objects.all().values('id', 'title', 'image', 'target_url', 'is_active', 'order')
        return response.Response(list(banners))

    @action(detail=False, methods=['post'])
    def update_banner(self, request):
        banner_id = request.data.get('id')
        is_active = request.data.get('is_active')
        
        try:
            banner = AppBanner.objects.get(id=banner_id)
            if is_active is not None:
                banner.is_active = is_active
            banner.save()
            return response.Response({'status': 'updated'})
        except AppBanner.DoesNotExist:
            return response.Response({'error': 'Banner not found'}, status=404)

    @action(detail=False, methods=['post'])
    def send_email(self, request):
        user_id = request.data.get('user_id')
        subject = request.data.get('subject')
        message = request.data.get('message')
        
        try:
            user = User.objects.get(id=user_id)
            # In a real prod environment, this would send a real email
            # send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [user.email])
            
            log_admin_action(
                admin=request.user,
                action="ADMIN_EMAIL",
                target=user.username,
                details=f"Subject: {subject}",
                request=request
            )
            return response.Response({'status': 'email queued (simulated)'})
        except User.DoesNotExist:
            return response.Response({'error': 'User not found'}, status=404)
