import firebase_admin
from firebase_admin import credentials, messaging
from django.conf import settings
import logging
import os

logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK
firebase_initialized = False

def initialize_firebase():
    global firebase_initialized
    if firebase_initialized:
        return True
        
    try:
        # Check for service account file path in settings or env
        cred_path = getattr(settings, 'FIREBASE_SERVICE_ACCOUNT_KEY', None)
        
        if cred_path and os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            firebase_initialized = True
            logger.info("Firebase Admin initialized successfully.")
            return True
        else:
            logger.warning("Firebase service account key not found. Push notifications will be disabled.")
            return False
    except Exception as e:
        logger.error(f"Error initializing Firebase: {e}")
        return False

def send_push_notification(user, title, body, data=None):
    """
    Sends a push notification to a specific user using their stored FCM token.
    """
    if not user.profile.fcm_token:
        return False

    if not initialize_firebase():
        return False

    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=user.profile.fcm_token,
        )
        response = messaging.send(message)
        logger.info(f"Successfully sent message: {response}")
        return True
    except Exception as e:
        logger.error(f"Error sending push notification: {e}")
        # If token is invalid/expired, we might want to clear it
        if "registration-token-not-registered" in str(e):
            user.profile.fcm_token = None
            user.profile.save()
        return False

def notify_followers_new_chapter(chapter):
    """
    Notifies all followers of an author when a new chapter is published.
    """
    book = chapter.book
    author = book.author
    
    # Get all followers of the author
    from social.models import Follow
    followers = Follow.objects.filter(followed=author).select_related('follower__profile')
    
    title = f"New Chapter: {book.title}"
    body = f"{author.username} just uploaded '{chapter.title}'! Read it now."
    
    data = {
        'type': 'new_chapter',
        'book_id': str(book.id),
        'chapter_id': str(chapter.id),
    }

    for follow in followers:
        recipient = follow.follower
        # Only notify if user has enabled 'new books' notifications
        if recipient.profile.notify_new_books:
            send_push_notification(recipient, title, body, data)
