from rest_framework import viewsets, permissions, status, filters
from rest_framework.response import Response
from rest_framework.decorators import action
from django.db.models import Count, Q
from django.utils import timezone
from datetime import timedelta
from .models import Category, Book, Chapter, ReadStats
from .serializers import CategorySerializer, BookSerializer, ChapterSerializer
from django.conf import settings
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.cache import cache_page
from django.utils.decorators import method_decorator

class CategoryViewSet(viewsets.ModelViewSet):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [permissions.AllowAny]
    lookup_field = 'slug'

from .permissions import IsOwnerOrReadOnly

class BookViewSet(viewsets.ModelViewSet):
    serializer_class = BookSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly, IsOwnerOrReadOnly]
    filterset_fields = ['category']
    search_fields = ['title', 'description']
    ordering_fields = ['created_at', 'price']
    ordering = ['-created_at']

    def get_queryset(self):
        qs = Book.objects.all().select_related('author', 'category').prefetch_related('chapters')
        
        author_id = self.request.query_params.get('author')
        user = self.request.user
        
        # 1. Start with visibility filtering
        if user.is_authenticated:
            # If the user is logged in, they see all published books + their own drafts
            qs = qs.filter(Q(is_published=True) | Q(author=user))
        else:
            # Guest users only see published books
            qs = qs.filter(is_published=True)

        # 2. Apply author filter manually (since we removed it from filterset_fields)
        if author_id:
            if author_id == 'me':
                if user.is_authenticated:
                    return qs.filter(author=user)
                else:
                    return qs.none()
            else:
                try:
                    return qs.filter(author_id=author_id)
                except (ValueError, TypeError):
                    return qs.none()
            
        return qs

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)

    @action(detail=True, methods=['post'])
    def record_read(self, request, pk=None):
        book = self.get_object()
        user = request.user if request.user.is_authenticated else None
        
        # Spam prevention: only record one read per user/guest-IP per hour
        grace_period = timezone.now() - timedelta(hours=1)
        
        if user:
            already_read = ReadStats.objects.filter(book=book, user=user, timestamp__gt=grace_period).exists()
        else:
            # For guests, we can't easily track without session/IP, 
            # but we can at least prevent immediate spam for anonymous users if needed.
            # Simplified for now: just record it.
            already_read = False

        if not already_read:
            ReadStats.objects.create(book=book, user=user)
            return Response({'status': 'read recorded'})
        
        return Response({'status': 'read skipped (grace period)'})

    @action(detail=False, methods=['get'])
    def my_books(self, request):
        """Returns only the books authored by the current user (used by Author Studio)."""
        if not request.user.is_authenticated:
            return Response({"error": "Authentication required"}, status=status.HTTP_401_UNAUTHORIZED)
        books = Book.objects.filter(author=request.user).select_related('author', 'category').prefetch_related('chapters')
        serializer = self.get_serializer(books, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def trending(self, request):
        region = request.query_params.get('region')
        
        # Weighted Score: (Reads * 1) + (Likes * 3)
        books = Book.objects.filter(is_published=True).annotate(
            read_count=Count('read_stats', distinct=True),
            likes_count=Count('likes', distinct=True)
        ).annotate(
            score=(Count('read_stats') * 1) + (Count('likes') * 3)
        )
        
        if region:
            books = books.filter(region__icontains=region)
            
        books = books.order_by('-score')[:10]
        serializer = self.get_serializer(books, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def discovery(self, request):
        region = request.query_params.get('region', 'Global')
        
        # 1. Mostly Read Category
        # Find category with most read stats
        top_category_stats = Category.objects.annotate(
            total_reads=Count('books__read_stats')
        ).order_by('-total_reads').first()
        
        mostly_read_category = []
        category_name = "Trending"
        if top_category_stats and top_category_stats.total_reads > 0:
            category_name = top_category_stats.name
            mostly_read_category = Book.objects.filter(
                category=top_category_stats, 
                is_published=True
            ).annotate(
                reads=Count('read_stats')
            ).order_by('-reads')[:6]

        if not mostly_read_category:
            mostly_read_category = Book.objects.filter(is_published=True).order_by('?')[:6]

        # 2. New Arrivals (latest published books)
        new_arrivals = Book.objects.filter(is_published=True).order_by('-created_at')[:10]

        # 4. Local Hits (Books from the same region)
        local_hits = Book.objects.filter(is_published=True, region__iexact=region)[:6]
        if not local_hits:
            local_hits = Book.objects.filter(is_published=True).order_by('?')[:6]

        # 5. Mutual Friends' Books (Social Discovery)
        social_hits = []
        if request.user.is_authenticated:
            following_ids = request.user.following.values_list('followed_id', flat=True)
            social_hits = Book.objects.filter(
                likes__user_id__in=following_ids,
                is_published=True
            ).exclude(author=request.user).distinct()[:6]
        
        if not social_hits:
             social_hits = Book.objects.filter(is_published=True).order_by('?')[:6]

        return Response({
            'mostly_read': {
                'category_name': category_name,
                'books': self.get_serializer(mostly_read_category, many=True).data
            },
            'local_hits': self.get_serializer(local_hits, many=True).data,
            'social_hits': self.get_serializer(social_hits, many=True).data,
            'new_arrivals': self.get_serializer(new_arrivals, many=True).data
        })

    @action(detail=True, methods=['post'])
    def toggle_library(self, request, pk=None):
        from .models import UserLibrary
        book = self.get_object()
        user = request.user
        
        if not user.is_authenticated:
            return Response({'error': 'Authentication required'}, status=status.HTTP_401_UNAUTHORIZED)
            
        library_item, created = UserLibrary.objects.get_or_create(user=user, book=book)
        
        if not created:
            library_item.delete()
            return Response({'status': 'removed', 'is_in_library': False})
            
        return Response({'status': 'added', 'is_in_library': True})

    @action(detail=False, methods=['get'])
    def my_library(self, request):
        """Returns all books the user has authored, purchased, or added to their library."""
        user = request.user
        if not user.is_authenticated:
            return Response({'error': 'Authentication required'}, status=status.HTTP_401_UNAUTHORIZED)
        
        from .models import UserLibrary
        library_book_ids = UserLibrary.objects.filter(user=user).values_list('book_id', flat=True)
        
        books = Book.objects.filter(
            Q(author=user) | Q(id__in=library_book_ids)
        ).distinct().select_related('author', 'category').prefetch_related('chapters')
        
        serializer = self.get_serializer(books, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['post'], url_path='convert_docx')
    def convert_docx(self, request):
        import mammoth
        file = request.FILES.get('file')
        if not file:
            return Response({'error': 'No file provided'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            result = mammoth.convert_to_html(file)
            return Response({'html': result.value})
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=False, methods=['post'], url_path='convert_pdf')
    def convert_pdf(self, request):
        import pdfplumber
        file = request.FILES.get('file')
        if not file:
            return Response({'error': 'No file provided'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            with pdfplumber.open(file) as pdf:
                full_text = ""
                for page in pdf.pages:
                    text = page.extract_text()
                    if text:
                        full_text += text + "\n"
            
            # Simple conversion to HTML paragraphs
            # We split by single newlines but preserve blocks
            paragraphs = full_text.split('\n')
            html = "".join([f"<p>{p}</p>" for p in paragraphs if p.strip()])
            
            return Response({'html': html})
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=True, methods=['post'])
    def import_chapters(self, request, pk=None):
        """
        Accepts a list of chapters in JSON format.
        Expected format: {'chapters': [{'title': '...', 'content': '...'}, ...]}
        """
        book = self.get_object()
        chapters_data = request.data.get('chapters')
        
        if not chapters_data or not isinstance(chapters_data, list):
            return Response({'error': 'No valid chapters list provided'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            chapters_created = []
            # Map existing chapters by their current order
            existing_chapters = {c.order: c for c in book.chapters.all()}
            
            for index, item in enumerate(chapters_data):
                title = item.get('title', f'Chapter {index + 1}')
                content = item.get('content', '')
                
                if index in existing_chapters:
                    # Update existing chapter to preserve audio_file and id
                    chapter = existing_chapters[index]
                    chapter.title = title
                    chapter.content = content
                    chapter.save()
                    del existing_chapters[index] # Remove from tracking dictionary
                else:
                    # Create new chapter
                    chapter = Chapter.objects.create(
                        book=book,
                        title=title,
                        content=content,
                        order=index
                    )
                    
                chapters_created.append({
                    'id': chapter.id,
                    'title': chapter.title,
                    'order': chapter.order
                })
                
            # Delete any leftover chapters (i.e., chapters the user deleted in the studio)
            for chapter in existing_chapters.values():
                chapter.delete()
            
            return Response({
                'status': 'chapters imported',
                'count': len(chapters_created),
                'chapters': chapters_created
            })
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=True, methods=['post'])
    def upload_audio(self, request, pk=None):
        book = self.get_object()
        chapter_number = request.data.get('chapter_number')
        audio_file = request.FILES.get('audio_file')

        if not chapter_number or not audio_file:
            return Response({'error': 'chapter_number and audio_file are required'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            # chapter_number from frontend is 1-indexed, match it with 0-indexed 'order'
            chapter = book.chapters.get(order=int(chapter_number) - 1)
            chapter.audio_file = audio_file
            chapter.save()
            return Response({'status': 'audio uploaded', 'url': chapter.audio_file.url})
        except (Chapter.DoesNotExist, ValueError):
            return Response({'error': f'Chapter {chapter_number} not found'}, status=status.HTTP_404_NOT_FOUND)

class ChapterViewSet(viewsets.ModelViewSet):
    queryset = Chapter.objects.all().select_related('book')
    serializer_class = ChapterSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        return Chapter.objects.filter(book_id=self.kwargs['book_pk'])

    def perform_create(self, serializer):
        serializer.save(book_id=self.kwargs['book_pk'])


