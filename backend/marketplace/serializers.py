import math
from django.contrib.auth import password_validation
from django.db import transaction
from django.utils import timezone
from rest_framework import serializers
from .models import (User, Category, Area, Professional, Portfolio, Booking, Quote,
                     Review, PromotionPackage, Promotion, Notification, Report)


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'phone', 'role', 'is_staff']
        read_only_fields = ['id', 'role', 'is_staff', 'username']


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8, max_length=128)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'password', 'first_name', 'last_name', 'phone', 'role']
        read_only_fields = ['id']

    def validate(self, attrs):
        password_validation.validate_password(attrs['password'], User(**{k: v for k, v in attrs.items() if k != 'password'}))
        return attrs

    @transaction.atomic
    def create(self, validated_data):
        user = User.objects.create_user(**validated_data)
        if user.role == 'professional':
            Professional.objects.create(user=user, business_name=str(user))
        return user


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name', 'icon']


class AreaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Area
        fields = ['id', 'name', 'city', 'latitude', 'longitude']


class PortfolioSerializer(serializers.ModelSerializer):
    def validate_image(self, image):
        if image and image.size > 5 * 1024 * 1024:
            raise serializers.ValidationError('Use an image smaller than 5 MB.')
        return image

    class Meta:
        model = Portfolio
        fields = ['id', 'title', 'description', 'image']


class ReviewSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='booking.customer.get_full_name', read_only=True)

    class Meta:
        model = Review
        fields = ['id', 'booking', 'rating', 'comment', 'customer_name', 'created_at']
        read_only_fields = ['id', 'customer_name', 'created_at']

    def validate_booking(self, booking):
        if booking.customer != self.context['request'].user or booking.status != 'completed':
            raise serializers.ValidationError('Review only your own completed booking.')
        return booking


class ProfessionalSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source='user.get_full_name', read_only=True)
    phone = serializers.CharField(source='user.phone', read_only=True)
    categories = CategorySerializer(many=True, read_only=True)
    areas = AreaSerializer(many=True, read_only=True)
    category_ids = serializers.PrimaryKeyRelatedField(source='categories', many=True,
        queryset=Category.objects.filter(active=True), write_only=True, required=False)
    area_ids = serializers.PrimaryKeyRelatedField(source='areas', many=True,
        queryset=Area.objects.all(), write_only=True, required=False)
    portfolio = PortfolioSerializer(many=True, read_only=True)
    rating = serializers.FloatField(read_only=True, default=0)
    review_count = serializers.IntegerField(read_only=True, default=0)
    distance_km = serializers.FloatField(read_only=True, default=None)
    promoted = serializers.BooleanField(read_only=True, default=False)

    def validate(self, attrs):
        lat = attrs.get('latitude', getattr(self.instance, 'latitude', None))
        lng = attrs.get('longitude', getattr(self.instance, 'longitude', None))
        if (lat is None) != (lng is None):
            raise serializers.ValidationError('Supply both coordinates or leave both empty.')
        if lat is not None and (not math.isfinite(lat) or not math.isfinite(lng)):
            raise serializers.ValidationError('Use finite coordinates.')
        return attrs

    class Meta:
        model = Professional
        fields = ['id', 'name', 'phone', 'business_name', 'bio', 'skills', 'experience_years',
                  'categories', 'areas', 'category_ids', 'area_ids', 'available', 'verified',
                  'starting_price', 'latitude', 'longitude', 'portfolio', 'rating', 'review_count',
                  'distance_km', 'promoted']
        read_only_fields = ['id', 'verified']


class ServiceRequestValidation:
    def validate(self, attrs):
        user = self.context['request'].user
        if user.role != 'customer':
            raise serializers.ValidationError('Only customers can request services.')
        pro = attrs['professional']
        if not pro.user.is_active or not pro.available:
            raise serializers.ValidationError('This professional is currently unavailable.')
        if not pro.categories.filter(pk=attrs['category'].pk, active=True).exists():
            raise serializers.ValidationError('Choose a service offered by this professional.')
        if not pro.areas.filter(pk=attrs['area'].pk).exists():
            raise serializers.ValidationError('Choose an area served by this professional.')
        return attrs


class BookingSerializer(ServiceRequestValidation, serializers.ModelSerializer):
    professional_name = serializers.CharField(source='professional.business_name', read_only=True)
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    area_name = serializers.CharField(source='area.name', read_only=True)
    review = ReviewSerializer(read_only=True)

    class Meta:
        model = Booking
        fields = ['id', 'professional', 'professional_name', 'customer_name', 'category',
                  'category_name', 'area', 'area_name', 'scheduled_at', 'address', 'details',
                  'status', 'created_at', 'review']
        read_only_fields = ['id', 'status', 'created_at']

    def validate_scheduled_at(self, value):
        if value <= timezone.now():
            raise serializers.ValidationError('Choose a future date and time.')
        return value


class QuoteSerializer(ServiceRequestValidation, serializers.ModelSerializer):
    professional_name = serializers.CharField(source='professional.business_name', read_only=True)
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)

    class Meta:
        model = Quote
        fields = ['id', 'professional', 'professional_name', 'customer_name', 'category',
                  'category_name', 'area', 'details', 'amount', 'response', 'created_at']
        read_only_fields = ['id', 'amount', 'response', 'created_at']


class QuoteReplySerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=1)
    response = serializers.CharField(max_length=2000)


class PromotionPackageSerializer(serializers.ModelSerializer):
    class Meta:
        model = PromotionPackage
        fields = ['id', 'name', 'days', 'price']


class PromotionSerializer(serializers.ModelSerializer):
    package_name = serializers.CharField(source='package.name', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    area_name = serializers.CharField(source='area.name', read_only=True)
    active = serializers.BooleanField(read_only=True)
    package = serializers.PrimaryKeyRelatedField(queryset=PromotionPackage.objects.filter(active=True))

    class Meta:
        model = Promotion
        fields = ['id', 'package', 'package_name', 'category', 'category_name', 'area', 'area_name',
                  'price_paid', 'status', 'starts_at', 'expires_at', 'active', 'created_at']
        read_only_fields = ['id', 'price_paid', 'status', 'starts_at', 'expires_at', 'created_at']

    def validate(self, attrs):
        user = self.context['request'].user
        if user.role != 'professional':
            raise serializers.ValidationError('Only professionals can promote a profile.')
        if not user.profile.categories.filter(pk=attrs['category'].pk, active=True).exists():
            raise serializers.ValidationError('Choose one of your services.')
        if not user.profile.areas.filter(pk=attrs['area'].pk).exists():
            raise serializers.ValidationError('Choose one of your service areas.')
        return attrs


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'message', 'read', 'created_at']
        read_only_fields = ['id', 'message', 'created_at']


class ReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = Report
        fields = ['id', 'professional', 'reason', 'resolved', 'resolution', 'created_at']
        read_only_fields = ['id', 'resolved', 'resolution', 'created_at']
