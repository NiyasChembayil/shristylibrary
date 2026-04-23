import os
import django
from django.utils.text import slugify
import random

# Set up Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'bookify_backend.settings')
django.setup()

from django.contrib.auth.models import User
from core.models import Category, Book, Chapter
from accounts.models import Profile

def populate():
    print("Starting DB population...")

    # Create common categories
    category_names = ["Romance", "Sci-Fi", "Mystery", "Fantasy", "Non-Fiction", "Thriller"]
    categories = []
    for name in category_names:
        cat, created = Category.objects.get_or_create(name=name, slug=slugify(name))
        categories.append(cat)
        if created:
            print(f"Created category: {name}")

    # Create some users (Authors)
    author_data = [
        {"username": "demo_author_1", "email": "author1@example.com", "password": "Password123!"},
        {"username": "demo_author_2", "email": "author2@example.com", "password": "Password123!"},
        {"username": "demo_author_3", "email": "author3@example.com", "password": "Password123!"},
    ]

    authors = []
    for data in author_data:
        user, created = User.objects.get_or_create(username=data["username"], email=data["email"])
        if created:
            user.set_password(data["password"])
            user.save()
            print(f"Created user: {user.username}")
        authors.append(user)

        # Make sure they have a profile explicitly set to 'author'
        profile, p_created = Profile.objects.get_or_create(user=user)
        if profile.role != 'author':
            profile.role = 'author'
            profile.save()

    # Create books
    books_data = [
        {"title": "The Quantum Paradox", "author": authors[1], "category": Category.objects.get(name="Sci-Fi"), "desc": "A thrilling space adventure exploring the limits of time and quantum physics."},
        {"title": "Whispers in the Wind", "author": authors[0], "category": Category.objects.get(name="Romance"), "desc": "A beautiful story of forbidden love in the 18th century."},
        {"title": "Shadow of the Murders", "author": authors[2], "category": Category.objects.get(name="Mystery"), "desc": "A detective with a dark past investigates a series of gruesome murders."},
        {"title": "The Midnight Library", "author": authors[0], "category": Category.objects.get(name="Fantasy"), "desc": "Between life and death there is a library, and within that library, the shelves go on forever."},
        {"title": "Startup Fundamentals", "author": authors[1], "category": Category.objects.get(name="Non-Fiction"), "desc": "The definitive guide to launching a tech startup in 2026."},
    ]

    for bdata in books_data:
        book, created = Book.objects.get_or_create(
            slug=slugify(bdata["title"]),
            defaults={
                "title": bdata["title"],
                "author": bdata["author"],
                "category": bdata["category"],
                "description": bdata["desc"],
                "is_published": True,
                "price": 0.00,
            }
        )
        if created:
            print(f"Created book: {book.title}")
            # Add chapters
            Chapter.objects.create(
                book=book,
                title="Chapter 1: The Beginning",
                content=f"This is the first chapter of {book.title}. " * 30,
                order=1
            )
            Chapter.objects.create(
                book=book,
                title="Chapter 2: The Rising Action",
                content=f"The story thickens in {book.title}. " * 30,
                order=2
            )
            Chapter.objects.create(
                book=book,
                title="Chapter 3: The Climax",
                content=f"The climax is finally here for {book.title}. " * 30,
                order=3
            )

    print("DB population complete!")

if __name__ == '__main__':
    populate()
