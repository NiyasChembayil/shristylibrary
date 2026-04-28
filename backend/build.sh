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

# Ensure admin exists
python manage.py shell -c "from django.contrib.auth.models import User; from accounts.models import Profile; (lambda: [ (u.set_password('Admin123!'), u.save(), setattr(u.profile, 'role', 'admin'), u.profile.save()) for u in [User.objects.get_or_create(username='admin', defaults={'email': 'admin@srishty.com', 'is_staff': True, 'is_superuser': True})[0]] ])()"
