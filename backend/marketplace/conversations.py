from django.utils import timezone
from rest_framework import serializers
from rest_framework.response import Response

from .models import Message, Notification


class MessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.SerializerMethodField()

    def get_sender_name(self, obj):
        return obj.sender.get_full_name() or obj.sender.username

    class Meta:
        model = Message
        fields = ['id', 'sender', 'sender_name', 'body', 'read_at', 'created_at']
        read_only_fields = ['id', 'sender', 'sender_name', 'read_at', 'created_at']


def messages_for(view, request, kind):
    parent = view.get_object()  # Participant-filtered queryset prevents access by outsiders.
    filters = {kind: parent}
    if request.method == 'POST':
        data = MessageSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        message = data.save(sender=request.user, **filters)
        recipient = parent.customer if parent.professional.user_id == request.user.pk else parent.professional.user
        Notification.objects.create(user=recipient,
            message=f'New message on {kind} #{parent.pk}. Open Activity to reply.')
        return Response(MessageSerializer(message).data, status=201)
    rows = Message.objects.filter(**filters).select_related('sender')
    return view.get_paginated_response(MessageSerializer(view.paginate_queryset(rows), many=True).data)


def read_messages(view, request, kind):
    parent = view.get_object()
    class ReadInput(serializers.Serializer):
        through_id = serializers.IntegerField(min_value=1)
    data = ReadInput(data=request.data)
    data.is_valid(raise_exception=True)
    through_id = data.validated_data['through_id']
    Message.objects.filter(**{kind: parent}, pk__lte=through_id, read_at__isnull=True).exclude(sender=request.user).update(read_at=timezone.now())
    return Response({'detail': 'Messages marked as read.'})
