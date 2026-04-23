import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'bookify_backend.settings')
django.setup()

from core.models import Book, Chapter

def add_chapters():
    books = Book.objects.filter(is_published=True)
    for b in books:
        count = b.chapters.count()
        if count == 0:
            Chapter.objects.create(
                book=b, 
                title='Chapter 1: The Beginning', 
                content=f'Welcome to the first chapter of {b.title}. This is automated sample content to ensure you have something to read!',
                order=1
            )
            Chapter.objects.create(
                book=b, 
                title='Chapter 2: The Journey', 
                content=f'The journey continues in {b.title}. We are glad to have you reading with us!',
                order=2
            )
            print(f'Added 2 chapters to {b.title}')
        else:
            print(f'{b.title} already has {count} chapters.')

if __name__ == '__main__':
    add_chapters()
