from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Notification, PostLike, PostComment
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync

@receiver(post_save, sender=Notification)
def broadcast_notification(sender, instance, created, **kwargs):
    if created:
        channel_layer = get_channel_layer()
        group_name = f"user_{instance.recipient.id}_notifications"
        
        notification_data = {
            "id": instance.id,
            "type": instance.action_type,
            "actor": instance.actor.username if instance.actor else "System",
            "message": instance.message or f"New {instance.action_type} notification",
            "created_at": instance.created_at.isoformat()
        }
        
        async_to_sync(channel_layer.group_send)(
            group_name,
            {
                "type": "send_notification",
                "notification": notification_data
            }
        )

def broadcast_post_update(post):
    channel_layer = get_channel_layer()
    async_to_sync(channel_layer.group_send)(
        "social_feed",
        {
            "type": "send_social_update",
            "data": {
                "post_id": post.id,
                "likes_count": post.likes.count(),
                "comments_count": post.comments.count(),
            }
        }
    )

@receiver(post_save, sender=PostLike)
@receiver(post_delete, sender=PostLike)
def on_like_update(sender, instance, **kwargs):
    broadcast_post_update(instance.post)

@receiver(post_save, sender=PostComment)
def on_comment_update(sender, instance, **kwargs):
    broadcast_post_update(instance.post)
