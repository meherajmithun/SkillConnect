import os
import firebase_admin
from firebase_admin import credentials, messaging
from django.core.management.base import BaseCommand, CommandError
from marketplace.models import Notification, Device


class Command(BaseCommand):
    help = 'Deliver queued notifications through FCM. Run periodically as a single worker.'

    def handle(self, *args, **options):
        key = os.getenv('FIREBASE_CREDENTIALS')
        if not key:
            raise CommandError('Set FIREBASE_CREDENTIALS to the service-account JSON path.')
        if not firebase_admin._apps:
            firebase_admin.initialize_app(credentials.Certificate(key))
        delivered = 0
        for notification in Notification.objects.filter(push_sent=False).select_related('user').order_by('id')[:100]:
            devices = Device.objects.filter(user=notification.user)
            failed = False
            for device in devices:
                try:
                    messaging.send(messaging.Message(token=device.token,
                        notification=messaging.Notification(title='SkillConnect', body=notification.message),
                        data={'notification_id': str(notification.id)}))
                except messaging.UnregisteredError:
                    device.delete()
                except Exception as exc:
                    failed = True
                    self.stderr.write(f'Notification {notification.pk} failed: {type(exc).__name__}')
            if not failed:
                notification.push_sent = True
                notification.save(update_fields=['push_sent'])
                delivered += 1
        self.stdout.write(f'Delivered {delivered} queued notifications. FCM is at-least-once delivery.')
