import os
import time
from datetime import timedelta

import firebase_admin
from firebase_admin import credentials, messaging
from django.core.management.base import BaseCommand, CommandError
from django.db.models import Q, F
from django.utils import timezone
from marketplace.models import Notification, Device, PushDelivery


class Command(BaseCommand):
    help = 'Deliver queued notifications through FCM. Run as a single worker.'

    def add_arguments(self, parser):
        parser.add_argument('--watch', action='store_true', help='Keep polling for new notifications.')
        parser.add_argument('--interval', type=int, default=30)

    def handle(self, *args, **options):
        key = os.getenv('FIREBASE_CREDENTIALS')
        if not key:
            raise CommandError('Set FIREBASE_CREDENTIALS to the service-account JSON path.')
        if options['interval'] < 5:
            raise CommandError('Use an interval of at least five seconds.')
        if not firebase_admin._apps:
            firebase_admin.initialize_app(credentials.Certificate(key))
        try:
            while True:
                self.deliver()
                if not options['watch']:
                    break
                time.sleep(options['interval'])
        except KeyboardInterrupt:
            self.stdout.write('Push worker stopped.')

    def deliver(self):
        now = timezone.now()
        queue = Notification.objects.filter(push_sent=False).filter(
            Q(deliveries__isnull=True) | Q(deliveries__sent_at__isnull=True,
                deliveries__retry_at__lte=now, deliveries__device__user=F('user'))
        ).distinct().select_related('user').order_by('id')[:100]
        delivered = 0
        for notification in queue:
            for device in Device.objects.filter(user=notification.user):
                delivery, created = PushDelivery.objects.get_or_create(notification=notification, device=device)
                if delivery.sent_at or (not created and delivery.retry_at > now):
                    continue
                try:
                    messaging.send(messaging.Message(token=device.token,
                        notification=messaging.Notification(title='SkillConnect', body=notification.message),
                        android=messaging.AndroidConfig(priority='high'),
                        data={'notification_id': str(notification.id), 'user_id': str(notification.user_id)}))
                    delivery.sent_at = timezone.now()
                    delivery.save(update_fields=['sent_at'])
                except messaging.UnregisteredError:
                    device.delete()
                except Exception as exc:
                    delivery.attempts += 1
                    delivery.retry_at = now + timedelta(seconds=min(3600, 30 * 2 ** min(delivery.attempts, 7)))
                    delivery.save(update_fields=['attempts', 'retry_at'])
                    self.stderr.write(f'Notification {notification.pk} failed: {type(exc).__name__}')
            pending = notification.deliveries.filter(sent_at__isnull=True, device__user=notification.user).exists()
            if not pending:
                notification.push_sent = True
                notification.save(update_fields=['push_sent'])
                delivered += 1
        self.stdout.write(f'Processed {delivered} notifications. Delivery is at least once.')
