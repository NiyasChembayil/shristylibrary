import os
import django
import sys

# Set up Django environment
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'bookify_backend.settings')
django.setup()

from core.models import Achievement

achievements_data = [
    # Consistency
    {'title': 'Daily Diver', 'description': 'Written for 7 days in a row.', 'icon': '🌊', 'category': 'consistency', 'criteria_type': 'streak', 'threshold': 7},
    {'title': 'Month Marathoner', 'description': 'Hit your daily word goal every day for a full month.', 'icon': '🏃', 'category': 'consistency', 'criteria_type': 'streak', 'threshold': 30},
    {'title': 'The Unstoppable', 'description': 'Reached a 100-day writing streak.', 'icon': '🔥', 'category': 'consistency', 'criteria_type': 'streak', 'threshold': 100},
    {'title': 'Early Bird', 'description': 'Finished your daily goal before 8:00 AM.', 'icon': '🌅', 'category': 'consistency', 'criteria_type': 'time_early', 'threshold': 1},
    {'title': 'Night Owl', 'description': 'Wrote more than 1,000 words between 12:00 AM and 4:00 AM.', 'icon': '🦉', 'category': 'consistency', 'criteria_type': 'time_late', 'threshold': 1000},
    
    # Word Count
    {'title': 'Flash Fictionist', 'description': 'Published 5,000 words total.', 'icon': '⚡', 'category': 'words', 'criteria_type': 'total_words', 'threshold': 5000},
    {'title': 'Novelist', 'description': 'Reached 50,000 words total across all books.', 'icon': '📚', 'category': 'words', 'criteria_type': 'total_words', 'threshold': 50000},
    {'title': 'Epic Architect', 'description': 'Reached 200,000 words total.', 'icon': '🏰', 'category': 'words', 'criteria_type': 'total_words', 'threshold': 200000},
    {'title': 'Word Smith', 'description': 'Wrote 5,000+ words in a single 24-hour period.', 'icon': '🔨', 'category': 'words', 'criteria_type': 'daily_words', 'threshold': 5000},
    
    # Community & Sprints
    {'title': 'Sprint Cadet', 'description': 'Joined your first 5 community writing sprints.', 'icon': '🚀', 'category': 'community', 'criteria_type': 'sprints_joined', 'threshold': 5},
    {'title': 'Sprint Master', 'description': 'Won 1st place on the Sprint Leaderboard 10 times.', 'icon': '👑', 'category': 'community', 'criteria_type': 'sprints_won', 'threshold': 10},
    {'title': 'Social Scribe', 'description': 'Replied to 50 reader comments.', 'icon': '💬', 'category': 'community', 'criteria_type': 'comments_replied', 'threshold': 50},
    
    # World-Building
    {'title': 'Character Creator', 'description': 'Created 10+ detailed character profiles in the Story Bible.', 'icon': '🎭', 'category': 'world', 'criteria_type': 'characters_created', 'threshold': 10},
    {'title': 'Relationship Guru', 'description': 'Connected 20+ characters in the Relationship Graph.', 'icon': '🕸️', 'category': 'world', 'criteria_type': 'relationships_created', 'threshold': 20},
    {'title': 'Pathfinder', 'description': 'Created a story with at least 5 different branching choices.', 'icon': '🗺️', 'category': 'world', 'criteria_type': 'choices_created', 'threshold': 5},
    
    # Reader Engagement
    {'title': 'Rising Star', 'description': 'Gained 1,000 total reads across your library.', 'icon': '⭐', 'category': 'reader', 'criteria_type': 'total_reads', 'threshold': 1000},
    {'title': 'Fan Favorite', 'description': 'Received 500 "Likes" on your chapters.', 'icon': '❤️', 'category': 'reader', 'criteria_type': 'total_likes', 'threshold': 500},
    {'title': 'Page Turner', 'description': 'Readers spend an average of 10+ minutes reading your story per session.', 'icon': '📖', 'category': 'reader', 'criteria_type': 'avg_read_time', 'threshold': 10},
]

for data in achievements_data:
    obj, created = Achievement.objects.get_or_create(
        title=data['title'],
        defaults={
            'description': data['description'],
            'icon': data['icon'],
            'category': data['category'],
            'criteria_type': data['criteria_type'],
            'threshold': data['threshold']
        }
    )
    if not created:
        for k, v in data.items():
            setattr(obj, k, v)
        obj.save()
    print(f"{'Created' if created else 'Updated'} {data['title']}")

print("Done.")
