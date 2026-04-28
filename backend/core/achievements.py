from django.utils import timezone
from .models import Achievement, UserAchievement, Chapter, Book, StoryCharacter, CharacterRelationship, SprintParticipant, DailyWritingStats

class AchievementService:
    @staticmethod
    def award_if_met(user, criteria_type, current_value):
        """
        Check all achievements of a given criteria_type. 
        If current_value >= threshold and user doesn't have it, award it.
        Returns a list of newly unlocked UserAchievement instances.
        """
        new_unlocks = []
        achievements = Achievement.objects.filter(criteria_type=criteria_type, threshold__lte=current_value)
        
        for ach in achievements:
            obj, created = UserAchievement.objects.get_or_create(user=user, achievement=ach)
            if created:
                new_unlocks.append(obj)
                
        return new_unlocks

    @staticmethod
    def check_word_count_badges(user):
        # Calculate total words across all chapters of user's books
        total_words = 0
        chapters = Chapter.objects.filter(book__author=user).exclude(content__isnull=True).exclude(content='')
        for chap in chapters:
            # simple word count estimate
            total_words += len(chap.content.split())
            
        return AchievementService.award_if_met(user, 'total_words', total_words)

    @staticmethod
    def check_streak_badges(user):
        # Find current streak based on DailyWritingStats
        stats = DailyWritingStats.objects.filter(user=user, goal_reached=True).order_by('-date')
        streak = 0
        current_date = timezone.now().date()
        
        for stat in stats:
            if stat.date == current_date or stat.date == current_date - timezone.timedelta(days=1):
                streak += 1
                current_date = stat.date
            else:
                break
                
        return AchievementService.award_if_met(user, 'streak', streak)

    @staticmethod
    def check_sprint_badges(user):
        sprints_joined = SprintParticipant.objects.filter(user=user).count()
        return AchievementService.award_if_met(user, 'sprints_joined', sprints_joined)

    @staticmethod
    def check_world_building_badges(user):
        new_unlocks = []
        chars_count = StoryCharacter.objects.filter(book__author=user).count()
        new_unlocks.extend(AchievementService.award_if_met(user, 'characters_created', chars_count))
        
        rels_count = CharacterRelationship.objects.filter(from_character__book__author=user).count()
        new_unlocks.extend(AchievementService.award_if_met(user, 'relationships_created', rels_count))
        
        return new_unlocks
