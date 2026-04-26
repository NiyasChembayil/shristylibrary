#!/usr/bin/env bash
# Exit on error
set -o errexit

# Install required dependencies
pip install -r requirements.txt

# Convert static asset files
python manage.py collectstatic --no-input

# Apply any outstanding database migrations
python manage.py migrate

# Seed default categories
python manage.py shell -c "from core.models import Category; from django.utils.text import slugify; [Category.objects.get_or_create(name=n, defaults={'slug': slugify(n)}) for n in ['Romance', 'Sci-Fi', 'Mystery', 'Fantasy', 'Non-Fiction', 'Thriller']]"
