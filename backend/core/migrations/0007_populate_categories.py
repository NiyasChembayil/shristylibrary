# Generated manually to populate initial categories

from django.db import migrations
from django.utils.text import slugify

def populate_default_categories(apps, schema_editor):
    Category = apps.get_model('core', 'Category')
    
    default_categories = [
        "Fiction",
        "Non-Fiction",
        "Romance",
        "Sci-Fi & Fantasy",
        "Mystery & Thriller",
        "Horror",
        "Young Adult",
        "Poetry",
        "Biography"
    ]
    
    for category_name in default_categories:
        Category.objects.get_or_create(
            name=category_name,
            defaults={'slug': slugify(category_name)}
        )

def remove_default_categories(apps, schema_editor):
    Category = apps.get_model('core', 'Category')
    default_categories_slugs = [slugify(name) for name in [
        "Fiction", "Non-Fiction", "Romance", "Sci-Fi & Fantasy",
        "Mystery & Thriller", "Horror", "Young Adult", "Poetry", "Biography"
    ]]
    Category.objects.filter(slug__in=default_categories_slugs).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0006_alter_chapter_content'),
    ]

    operations = [
        migrations.RunPython(populate_default_categories, reverse_code=remove_default_categories),
    ]
