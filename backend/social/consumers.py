import json
from channels.generic.websocket import AsyncWebsocketConsumer

class NotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        user = self.scope["user"]
        print(f"Consumer: Connection attempt by user: {user}")
        if user.is_anonymous:
            print("Consumer: Connection REJECTED (Anonymous)")
            await self.close()
        else:
            self.user_id = user.id
            self.group_name = f"user_{self.user_id}_notifications"
            print(f"Consumer: Connection ACCEPTED for user_id: {self.user_id}")
            # Join user-specific group
            await self.channel_layer.group_add(
                self.group_name,
                self.channel_name
            )
            # Join global social feed group for live updates
            await self.channel_layer.group_add(
                "social_feed",
                self.channel_name
            )
            await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(
                self.group_name,
                self.channel_name
            )
            await self.channel_layer.group_discard(
                "social_feed",
                self.channel_name
            )

    # Receive notification from group
    async def send_notification(self, event):
        notification = event["notification"]
        await self.send(text_data=json.dumps({
            "type": "notification",
            "notification": notification
        }))

    # Receive social update from group
    async def send_social_update(self, event):
        data = event["data"]
        await self.send(text_data=json.dumps({
            "type": "social_update",
            "data": data
        }))
