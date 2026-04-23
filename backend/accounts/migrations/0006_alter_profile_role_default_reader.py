from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0005_profile_font_size_profile_is_private_and_more'),
    ]

    operations = [
        migrations.AlterField(
            model_name='profile',
            name='role',
            field=models.CharField(
                choices=[('reader', 'Reader'), ('author', 'Author'), ('admin', 'Admin')],
                default='reader',
                max_length=20,
            ),
        ),
    ]
