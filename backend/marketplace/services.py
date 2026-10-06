from datetime import timedelta
from django.db import transaction
from django.utils import timezone
from .models import Promotion, Notification


@transaction.atomic
def activate_promotion(promotion_id):
    """Activate once, after an administrator verifies payment; retries cannot extend it."""
    promotion = Promotion.objects.select_for_update().get(pk=promotion_id)
    if promotion.status != 'pending':
        return promotion
    promotion.status = 'paid'
    promotion.starts_at = timezone.now()
    promotion.expires_at = promotion.starts_at + timedelta(days=promotion.duration_days)
    promotion.save(update_fields=['status', 'starts_at', 'expires_at'])
    Notification.objects.create(user=promotion.professional.user, message=f'Promotion #{promotion.id} is active in {promotion.area.name}.')
    return promotion
