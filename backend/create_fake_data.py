import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'bookify_backend.settings')
django.setup()

from django.contrib.auth.models import User
from core.models import Book, Category, ReadStats

def run():
    print("Creating fake data...")
    user, _ = User.objects.get_or_create(username='srishty_author', email='author@srishty.com')
    
    # Categories
    categories = ['sci-fi', 'fiction', 'mystery', 'romance']
    for cat in categories:
        Category.objects.get_or_create(name=cat.title(), slug=cat)

    cat_scifi = Category.objects.get(slug='sci-fi')
    cat_fiction = Category.objects.get(slug='fiction')
    cat_mystery = Category.objects.get(slug='mystery')

    # Books
    books_data = [
        {"title": "The Quantum Paradox", "slug": "quantum-paradox", "cat": cat_scifi, "reads": 150},
        {"title": "Neon Horizons", "slug": "neon-horizons", "cat": cat_scifi, "reads": 90},
        {"title": "Echoes of the Past", "slug": "echoes-past", "cat": cat_fiction, "reads": 110},
        {"title": "The Last Kingdom", "slug": "last-kingdom", "cat": cat_fiction, "reads": 60},
        {"title": "Murder on the Orient", "slug": "murder-orient", "cat": cat_mystery, "reads": 45},
    ]

    for data in books_data:
        if not Book.objects.filter(title=data["title"]).exists():
            book = Book.objects.create(
                title=data["title"],
                slug=data["slug"],
                author=user,
                category=data["cat"],
                description="An amazing story created for demonstration.",
                price=9.99,
                is_published=True
            )
            # Add read stats to make it "trending"
            print(f"Adding {data['reads']} read stats for '{book.title}' to boost trending score")
            for _ in range(data["reads"]):
                ReadStats.objects.create(book=book)

    print("\nDatabase seeded with fake data successfully!")

if __name__ == "__main__":
    run()
