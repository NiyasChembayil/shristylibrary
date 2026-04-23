from rest_framework import viewsets, permissions, response
from rest_framework.decorators import action
from django.contrib.auth.models import User
from django.db.models import Sum
from accounts.models import Profile
from core.models import Book
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
        
        return response.Response({
            'users': {
                'total': total_users,
                'authors': total_authors,
                'readers': total_readers,
            },
            'books': {
                'total': total_books,
                'published': published_books,
                'pending': pending_books,
            },
            'revenue': {
                'total': 0.0,
                'purchases': 0,
            }
        })

    @action(detail=False, methods=['get'])
    def recent_activity(self, request):
        # Last 5 books published
        recent_books = Book.objects.filter(is_published=True).order_by('-created_at')[:5]
        
        return response.Response({
            'books': [{'title': b.title, 'author': b.author.username, 'date': b.created_at} for b in recent_books],
            'purchases': []
        })
