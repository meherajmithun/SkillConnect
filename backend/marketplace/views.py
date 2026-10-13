import math
from datetime import timedelta
from django.conf import settings
from django.db import transaction
from django.db.models import Avg, Count, Q, Sum
from django.utils import timezone
from rest_framework import generics, permissions, serializers, status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .models import (User, Category, Area, Professional, Booking, Quote, Review,
                     Portfolio, PromotionPackage, Promotion, Notification, Report, Device)
from .serializers import (RegisterSerializer, UserSerializer, CategorySerializer, AreaSerializer,
    ProfessionalSerializer, BookingSerializer, QuoteSerializer, QuoteReplySerializer,
    ReviewSerializer, PortfolioSerializer, PromotionPackageSerializer, PromotionSerializer,
    NotificationSerializer, ReportSerializer)
from .accounts import SessionTokenSerializer, SessionRefreshSerializer


class AuthThrottle(AnonRateThrottle):
    scope = 'auth'


class LoginView(TokenObtainPairView):
    throttle_classes = [AuthThrottle]
    serializer_class = SessionTokenSerializer


class RefreshView(TokenRefreshView):
    throttle_classes = [AuthThrottle]
    serializer_class = SessionRefreshSerializer


class RegisterView(generics.CreateAPIView):
    permission_classes = [permissions.AllowAny]
    throttle_classes = [AuthThrottle]
    serializer_class = RegisterSerializer


class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer

    def get_object(self):
        return User.objects.get(pk=self.request.user.pk)


class CategoryView(generics.ListAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = CategorySerializer
    queryset = Category.objects.filter(active=True).order_by('name')
    pagination_class = None


class AreaView(generics.ListAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = AreaSerializer
    queryset = Area.objects.all().order_by('name')
    pagination_class = None


def profiles():
    return Professional.objects.filter(user__is_active=True).select_related('user').prefetch_related(
        'categories', 'areas', 'portfolio').annotate(
        rating=Avg('bookings__review__rating', filter=Q(bookings__review__visible=True)),
        review_count=Count('bookings__review', filter=Q(bookings__review__visible=True), distinct=True))


class ProfessionalViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [permissions.AllowAny]
    serializer_class = ProfessionalSerializer
    queryset = profiles()

    def list(self, request, *args, **kwargs):
        qs = profiles()
        params = request.query_params
        try:
            category = int(params['category']) if params.get('category') else None
            area = int(params['area']) if params.get('area') else None
            minimum = float(params.get('min_rating', 0))
            max_distance = float(params['max_distance']) if params.get('max_distance') else None
            lat = float(params['lat']) if params.get('lat') else None
            lng = float(params['lng']) if params.get('lng') else None
            if not math.isfinite(minimum) or not 0 <= minimum <= 5:
                raise ValueError()
            if (lat is None) != (lng is None):
                raise ValueError()
            if lat is not None and (not -90 <= lat <= 90 or not -180 <= lng <= 180):
                raise ValueError()
            if max_distance is not None and (not math.isfinite(max_distance) or max_distance <= 0 or lat is None):
                raise ValueError()
        except (ValueError, TypeError):
            raise serializers.ValidationError('Use valid category/area IDs, rating 0–5 and coordinates; distance requires lat and lng.')
        if category:
            qs = qs.filter(categories__id=category, categories__active=True)
        if area:
            qs = qs.filter(areas__id=area)
        if minimum:
            qs = qs.filter(rating__gte=minimum)
        if params.get('available') == 'true':
            qs = qs.filter(available=True)
        if params.get('q'):
            qs = qs.filter(Q(business_name__icontains=params['q']) | Q(skills__icontains=params['q']) |
                           Q(bio__icontains=params['q']))
        now = timezone.now()
        # Ads only apply to the exact requested service + area, and automatically expire.
        promoted_ids = set(Promotion.objects.filter(status='paid', starts_at__lte=now,
            expires_at__gt=now, category_id=category, area_id=area).values_list('professional_id', flat=True)) if category and area else set()
        results = []
        for pro in qs.distinct():
            pro.distance_km = None
            if lat is not None and pro.latitude is not None and pro.longitude is not None:
                dlat, dlng = math.radians(pro.latitude - lat), math.radians(pro.longitude - lng)
                a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat)) * math.cos(math.radians(pro.latitude)) * math.sin(dlng / 2) ** 2
                pro.distance_km = round(6371 * 2 * math.asin(math.sqrt(min(1, a))), 2)
            if max_distance is not None and (pro.distance_km is None or pro.distance_km > max_distance):
                continue
            pro.promoted = pro.id in promoted_ids
            # Bounded advertising boost retains rating, proximity and profile-quality signals.
            quality = (bool(pro.bio) + bool(pro.skills) + bool(pro.portfolio.all()) + pro.verified) * .25
            pro.rank = (pro.rating or 0) + quality + (1 if pro.promoted else 0) - min(pro.distance_km or 0, 20) * .1
            results.append(pro)
        ordering = params.get('sort', 'recommended')
        if ordering not in ['recommended', 'rating', 'distance']:
            raise serializers.ValidationError('Choose recommended, rating or distance sorting.')
        results.sort(key=lambda p: (-(p.rating or 0), p.id) if ordering == 'rating' else
            (p.distance_km if p.distance_km is not None else float('inf'), p.id) if ordering == 'distance' else (-p.rank, p.id))
        page = self.paginate_queryset(results)
        return self.get_paginated_response(self.get_serializer(page, many=True).data)

    @action(detail=True, methods=['get'])
    def reviews(self, request, pk=None):
        reviews = Review.objects.filter(booking__professional=self.get_object(), visible=True).select_related('booking__customer').order_by('-created_at')
        page = self.paginate_queryset(reviews)
        return self.get_paginated_response(ReviewSerializer(page, many=True).data)


class OwnProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = ProfessionalSerializer

    def get_object(self):
        if self.request.user.role != 'professional':
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied('A professional account is required.')
        return profiles().get(user=self.request.user)


class PortfolioViewSet(viewsets.ModelViewSet):
    serializer_class = PortfolioSerializer

    def get_queryset(self):
        return Portfolio.objects.filter(professional__user=self.request.user)

    def perform_create(self, serializer):
        if self.request.user.role != 'professional':
            raise serializers.ValidationError('A professional account is required.')
        serializer.save(professional=self.request.user.profile)


class BookingViewSet(viewsets.GenericViewSet, generics.ListAPIView, generics.CreateAPIView, generics.RetrieveAPIView):
    serializer_class = BookingSerializer

    def get_queryset(self):
        return Booking.objects.filter(Q(customer=self.request.user) | Q(professional__user=self.request.user)).select_related(
            'professional', 'customer', 'area', 'category').order_by('-created_at')

    @transaction.atomic
    def perform_create(self, serializer):
        from .scheduling import reserve_booking
        booking = reserve_booking(serializer, self.request.user)
        Notification.objects.create(user=booking.professional.user, message=f'New booking #{booking.id}: {booking.category.name}')

    @action(detail=True, methods=['post'], url_path='status')
    @transaction.atomic
    def change_status(self, request, pk=None):
        from .scheduling import validate_booking_schedule
        initial = self.get_object()
        pro = Professional.objects.select_for_update().get(pk=initial.professional_id)
        booking = self.get_queryset().select_for_update().get(pk=initial.pk)
        target = request.data.get('status')
        is_pro = booking.professional.user_id == request.user.id
        allowed = {'pending': ['accepted', 'rejected'], 'accepted': ['completed']} if is_pro else {'pending': ['cancelled'], 'accepted': ['cancelled']}
        if target not in allowed.get(booking.status, []):
            raise serializers.ValidationError('This booking status change is not allowed.')
        if target == 'accepted':
            validate_booking_schedule({'professional': pro, 'scheduled_at': booking.scheduled_at,
                'duration_minutes': booking.duration_minutes, 'slot': booking.slot}, exclude=booking.pk, require_slot=False)
        booking.status = target
        booking.save(update_fields=['status', 'updated_at'])
        recipient = booking.customer if is_pro else booking.professional.user
        Notification.objects.create(user=recipient, message=f'Booking #{booking.id} is {target}.')
        return Response(self.get_serializer(booking).data)

    @action(detail=True, methods=['get', 'post'])
    def messages(self, request, pk=None):
        from .conversations import messages_for
        return messages_for(self, request, 'booking')

    @action(detail=True, methods=['post'], url_path='messages/read')
    def read_messages(self, request, pk=None):
        from .conversations import read_messages
        return read_messages(self, request, 'booking')


class QuoteViewSet(viewsets.GenericViewSet, generics.ListAPIView, generics.CreateAPIView, generics.RetrieveAPIView):
    serializer_class = QuoteSerializer

    def get_queryset(self):
        return Quote.objects.filter(Q(customer=self.request.user) | Q(professional__user=self.request.user)).select_related('professional', 'customer', 'category')

    @transaction.atomic
    def perform_create(self, serializer):
        quote = serializer.save(customer=self.request.user)
        Notification.objects.create(user=quote.professional.user, message=f'New quotation request #{quote.id}.')

    @action(detail=True, methods=['post'])
    @transaction.atomic
    def reply(self, request, pk=None):
        initial = self.get_object()
        Professional.objects.select_for_update().get(pk=initial.professional_id)
        quote = self.get_queryset().select_for_update().get(pk=initial.pk)
        if quote.professional.user_id != request.user.id:
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied('Only the requested professional can reply.')
        if Booking.objects.filter(quote=quote).exists():
            raise serializers.ValidationError('This estimate has already been accepted and cannot be changed.')
        data = QuoteReplySerializer(data=request.data)
        data.is_valid(raise_exception=True)
        quote.amount = data.validated_data['amount']
        quote.response = data.validated_data['response']
        quote.revision += 1
        quote.save(update_fields=['amount', 'response', 'revision'])
        Notification.objects.create(user=quote.customer, message=f'Quotation #{quote.id}: BDT {quote.amount}.')
        return Response(self.get_serializer(quote).data)

    @action(detail=True, methods=['post'])
    @transaction.atomic
    def accept(self, request, pk=None):
        from .scheduling import reserve_booking
        initial = self.get_object()
        Professional.objects.select_for_update().get(pk=initial.professional_id)
        quote = self.get_queryset().select_for_update().get(pk=initial.pk)
        if quote.customer_id != request.user.pk:
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied('Only the requesting customer can accept this estimate.')
        existing = Booking.objects.filter(quote=quote).first()
        if existing:
            return Response(BookingSerializer(existing, context={'request': request}).data)
        if quote.amount is None:
            raise serializers.ValidationError('Wait for the professional’s estimate first.')
        class RevisionInput(serializers.Serializer):
            quote_revision = serializers.IntegerField(min_value=0)
        revision = RevisionInput(data=request.data)
        revision.is_valid(raise_exception=True)
        if revision.validated_data['quote_revision'] != quote.revision:
            raise serializers.ValidationError('This estimate changed. Refresh it before accepting.')
        payload = {k: request.data.get(k) for k in ['scheduled_at', 'address']}
        payload.update(professional=quote.professional_id, category=quote.category_id,
            area=quote.area_id, details=quote.details,
            duration_minutes=request.data.get('duration_minutes', 60), slot=request.data.get('slot'))
        data = BookingSerializer(data=payload, context={'request': request})
        data.is_valid(raise_exception=True)
        booking = reserve_booking(data, request.user, quote=quote, agreed_price=quote.amount, agreed_terms=quote.response)
        Notification.objects.create(user=quote.professional.user,
            message=f'Quotation #{quote.pk} accepted: booking #{booking.pk}, BDT {quote.amount}.')
        return Response(BookingSerializer(booking, context={'request': request}).data, status=201)

    @action(detail=True, methods=['get', 'post'])
    def messages(self, request, pk=None):
        from .conversations import messages_for
        return messages_for(self, request, 'quote')

    @action(detail=True, methods=['post'], url_path='messages/read')
    def read_messages(self, request, pk=None):
        from .conversations import read_messages
        return read_messages(self, request, 'quote')


class ReviewView(generics.CreateAPIView):
    serializer_class = ReviewSerializer


class PackageView(generics.ListAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = PromotionPackageSerializer
    queryset = PromotionPackage.objects.filter(active=True).order_by('days')
    pagination_class = None


class PromotionViewSet(viewsets.GenericViewSet, generics.ListAPIView, generics.CreateAPIView):
    serializer_class = PromotionSerializer

    def get_queryset(self):
        return Promotion.objects.filter(professional__user=self.request.user).select_related('package', 'category', 'area').order_by('-created_at')

    @transaction.atomic
    def perform_create(self, serializer):
        package = serializer.validated_data['package']
        promotion = serializer.save(professional=self.request.user.profile, price_paid=package.price, duration_days=package.days)
        if settings.DEMO_PAYMENTS:
            from .services import activate_promotion
            activate_promotion(promotion.pk)

    @action(detail=True, methods=['get', 'post'])
    def payment(self, request, pk=None):
        from .payments import checkout, refresh_payment, PaymentSerializer
        promotion = self.get_object()
        if request.method == 'POST':
            payment = checkout(promotion.pk, request.user)
        else:
            payment = promotion.payments.order_by('-id').first()
            if not payment:
                return Response({'detail': 'No payment attempt yet.'}, status=404)
            payment = refresh_payment(payment)
        return Response(PaymentSerializer(payment).data)


class NotificationViewSet(viewsets.GenericViewSet, generics.ListAPIView):
    serializer_class = NotificationSerializer

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)

    @action(detail=False, methods=['post'], url_path='read-all')
    def read_all(self, request):
        self.get_queryset().update(read=True)
        return Response({'detail': 'Notifications marked as read.'})


class ReportView(generics.ListCreateAPIView):
    serializer_class = ReportSerializer

    def get_queryset(self):
        return Report.objects.filter(reporter=self.request.user).order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(reporter=self.request.user)


@api_view(['GET'])
def analytics(request):
    if request.user.is_staff:
        bookings = Booking.objects.all()
        data = {'users': User.objects.count(), 'professionals': Professional.objects.count(),
                'pending_verifications': Professional.objects.filter(verified=False).count(),
                'open_reports': Report.objects.filter(resolved=False).count(),
                'promotion_revenue': Promotion.objects.filter(status='paid').aggregate(total=Sum('price_paid'))['total'] or 0}
    elif request.user.role == 'professional':
        bookings = Booking.objects.filter(professional__user=request.user)
        data = {'quotes': Quote.objects.filter(professional__user=request.user).count(),
                'rating': profiles().get(user=request.user).rating or 0,
                'active_promotions': Promotion.objects.filter(professional__user=request.user, status='paid',
                     starts_at__lte=timezone.now(), expires_at__gt=timezone.now()).count()}
    else:
        bookings = Booking.objects.filter(customer=request.user)
        data = {'quotes': Quote.objects.filter(customer=request.user).count()}
    data['bookings'] = bookings.count()
    data['completed'] = bookings.filter(status='completed').count()
    data['pending'] = bookings.filter(status='pending').count()
    return Response(data)


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def health(request):
    from .payments import payment_enabled
    return Response({'status': 'ok', 'service': 'SkillConnect', 'demo_payments': settings.DEMO_PAYMENTS,
        'online_payments': payment_enabled(), 'payment_sandbox': settings.SSLCOMMERZ_SANDBOX})


@api_view(['POST', 'DELETE'])
def device(request):
    token = request.data.get('token', '')
    if not isinstance(token, str) or not 20 <= len(token) <= 4096:
        raise serializers.ValidationError('Supply a valid FCM registration token.')
    if request.method == 'DELETE':
        Device.objects.filter(user=request.user, token=token).delete()
        return Response(status=204)
    Device.objects.update_or_create(token=token, defaults={'user': request.user})
    return Response({'detail': 'Device registered.'})
