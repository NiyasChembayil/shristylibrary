import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'bookify_backend.settings')
django.setup()

from core.models import Book

def run():
    print("Updating dummy data regions...")
    
    # Assign Asia Region books
    asia_books = ['Neon Horizons', 'Murder on the Orient']
    Book.objects.filter(title__in=asia_books).update(region='Asia Region')

    # Assign NA books
    na_books = ['Echoes of the Past', 'The Last Kingdom']
    Book.objects.filter(title__in=na_books).update(region='North America')

    # Rest defaults to Global
    
    print("Regions updated successfully!")

if __name__ == "__main__":
    run()
