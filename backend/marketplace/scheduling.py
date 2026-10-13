from datetime import timedelta

from django.db import transaction
from django.utils import timezone
from rest_framework import permissions, serializers, viewsets
from rest_framework.decorators import api_view, permission_classes
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response

from .models import AvailabilitySlot, Booking, Professional


def booking_conflicts(professional, starts_at, ends_at, exclude=None):
    bookings = Booking.objects.filter(professional=professional, status__in=['pending', 'accepted'],
        scheduled_at__lt=ends_at, scheduled_at__gt=starts_at - timedelta(minutes=480))
    if exclude:
        bookings = bookings.exclude(pk=exclude)
    return any(b.scheduled_at + timedelta(minutes=b.duration_minutes) > starts_at for b in bookings)


def validate_booking_schedule(attrs, exclude=None, require_slot=True):
    pro = attrs['professional']
    start = attrs['scheduled_at']
    duration = attrs.get('duration_minutes', 60)
    end = start + timedelta(minutes=duration)
    slot = attrs.get('slot')
    if start <= timezone.now():
        raise serializers.ValidationError('Choose a future appointment.')
    if require_slot and pro.schedule_enabled and not slot:
        raise serializers.ValidationError({'slot': 'Choose an available appointment from the calendar.'})
    if slot and (slot.professional_id != pro.pk or slot.starts_at != start or slot.ends_at != end):
        raise serializers.ValidationError({'slot': 'The appointment must match this professional’s published slot.'})
    if booking_conflicts(pro, start, end, exclude):
        raise serializers.ValidationError('This time is already reserved. Choose another appointment.')


@transaction.atomic
def reserve_booking(serializer, customer, **extra):
    pro = Professional.objects.select_for_update().get(pk=serializer.validated_data['professional'].pk)
    if not pro.available or not pro.user.is_active:
        raise serializers.ValidationError('This professional is currently unavailable.')
    attrs = dict(serializer.validated_data, professional=pro)
    # Slot mutation also holds this professional lock.
    slot = attrs.get('slot')
    if slot:
        try:
            attrs['slot'] = AvailabilitySlot.objects.get(pk=slot.pk, professional=pro)
        except AvailabilitySlot.DoesNotExist:
            raise serializers.ValidationError('This appointment is no longer available.')
    validate_booking_schedule(attrs)
    return serializer.save(customer=customer, **extra)


class SlotSerializer(serializers.ModelSerializer):
    class Meta:
        model = AvailabilitySlot
        fields = ['id', 'starts_at', 'ends_at']
        read_only_fields = ['id']

    def validate(self, attrs):
        start, end = attrs['starts_at'], attrs['ends_at']
        seconds = (end - start).total_seconds()
        if start <= timezone.now() or start > timezone.now() + timedelta(days=90):
            raise serializers.ValidationError('Choose a future appointment within 90 days.')
        if not 1800 <= seconds <= 28800 or seconds % 60:
            raise serializers.ValidationError('Slots must last 30–480 whole minutes.')
        return attrs


class SlotViewSet(viewsets.GenericViewSet, viewsets.mixins.ListModelMixin,
                  viewsets.mixins.CreateModelMixin, viewsets.mixins.DestroyModelMixin):
    serializer_class = SlotSerializer

    def get_queryset(self):
        if self.request.user.role != 'professional':
            raise PermissionDenied('A professional account is required.')
        return AvailabilitySlot.objects.filter(professional__user=self.request.user, ends_at__gt=timezone.now())

    @transaction.atomic
    def perform_create(self, serializer):
        if self.request.user.role != 'professional':
            raise PermissionDenied('A professional account is required.')
        pro = Professional.objects.select_for_update().get(user=self.request.user)
        start, end = serializer.validated_data['starts_at'], serializer.validated_data['ends_at']
        if AvailabilitySlot.objects.filter(professional=pro, starts_at__lt=end, ends_at__gt=start).exists():
            raise serializers.ValidationError('This slot overlaps another appointment.')
        if booking_conflicts(pro, start, end):
            raise serializers.ValidationError('A booking already reserves this time.')
        serializer.save(professional=pro)

    @transaction.atomic
    def perform_destroy(self, instance):
        Professional.objects.select_for_update().get(pk=instance.professional_id)
        # Preserve references even after cancellation/completion.
        if Booking.objects.filter(slot=instance).exists():
            raise serializers.ValidationError('This slot has booking history and cannot be removed.')
        instance.delete()


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def availability(request, professional_id):
    from django.shortcuts import get_object_or_404
    pro = get_object_or_404(Professional, pk=professional_id, user__is_active=True)
    slots = AvailabilitySlot.objects.filter(professional=pro, starts_at__gt=timezone.now(),
        starts_at__lte=timezone.now() + timedelta(days=90))
    rows = [s for s in slots if not booking_conflicts(pro, s.starts_at, s.ends_at)] if pro.available else []
    return Response({'schedule_enabled': pro.schedule_enabled, 'slots': SlotSerializer(rows[:500], many=True).data})
