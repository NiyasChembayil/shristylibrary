import stripe
from django.conf import settings
from .models import Purchase, Book

stripe.api_key = settings.STRIPE_SECRET_KEY

def create_stripe_checkout_session(user, book_id, success_url, cancel_url):
    try:
        book = Book.objects.get(id=book_id)
        
        # Create a Pending Purchase record
        purchase = Purchase.objects.create(
            user=user,
            book=book,
            amount=book.price,
            status='PENDING'
        )

        session = stripe.checkout.Session.create(
            payment_method_types=['card'],
            line_items=[{
                'price_data': {
                    'currency': 'usd',
                    'product_data': {
                        'name': book.title,
                        'images': [book.cover.url if book.cover else ''],
                    },
                    'unit_amount': int(book.price * 100),
                },
                'quantity': 1,
            }],
            mode='payment',
            success_url=success_url + '?session_id={CHECKOUT_SESSION_ID}',
            cancel_url=cancel_url,
            customer_email=user.email,
            client_reference_id=str(purchase.id),
            metadata={
                'purchase_id': purchase.id,
                'book_id': book.id,
                'user_id': user.id
            }
        )

        purchase.stripe_checkout_id = session.id
        purchase.save()

        return session
    except Exception as e:
        print(f"Stripe Session Error: {e}")
        return None

def fulfill_purchase(session):
    purchase_id = session.get('client_reference_id')
    payment_intent_id = session.get('payment_intent')
    
    try:
        purchase = Purchase.objects.get(id=purchase_id)
        purchase.status = 'COMPLETED'
        purchase.stripe_payment_intent_id = payment_intent_id
        # In a real app, generate a unique transaction_id or use Stripe's
        purchase.transaction_id = f"STRIPE_{payment_intent_id}"
        purchase.save()
        return True
    except Purchase.DoesNotExist:
        return False
