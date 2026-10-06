from django.contrib.auth.models import AbstractUser
from django.core.validators import MinValueValidator, MaxValueValidator
from django.db import models
from django.conf import settings
from django.utils import timezone


class User(AbstractUser):
    ROLE_CHOICES = [('customer', 'Customer'), ('professional', 'Professional')]
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='customer')
    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField(unique=True)

    def __str__(self):
        return self.get_full_name() or self.username


class Category(models.Model):
    name = models.CharField(max_length=80, unique=True)
    icon = models.CharField(max_length=40, default='handyman')
    active = models.BooleanField(default=True)

    def __str__(self):
        return self.name


class Area(models.Model):
    name = models.CharField(max_length=80, unique=True)
    city = models.CharField(max_length=80, default='Dhaka')
    latitude = models.FloatField(validators=[MinValueValidator(-90), MaxValueValidator(90)])
    longitude = models.FloatField(validators=[MinValueValidator(-180), MaxValueValidator(180)])

    def __str__(self):
        return self.name


class Professional(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='profile')
    business_name = models.CharField(max_length=120)
    bio = models.TextField(max_length=2000, blank=True)
    skills = models.CharField(max_length=500, blank=True)
    experience_years = models.PositiveSmallIntegerField(default=0, validators=[MaxValueValidator(80)])
    categories = models.ManyToManyField(Category)
    areas = models.ManyToManyField(Area)
    available = models.BooleanField(default=True)
    verified = models.BooleanField(default=False)
    starting_price = models.DecimalField(max_digits=10, decimal_places=2, default=0, validators=[MinValueValidator(0)])
    latitude = models.FloatField(null=True, blank=True, validators=[MinValueValidator(-90), MaxValueValidator(90)])
    longitude = models.FloatField(null=True, blank=True, validators=[MinValueValidator(-180), MaxValueValidator(180)])
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.business_name


class Portfolio(models.Model):
    professional = models.ForeignKey(Professional, on_delete=models.CASCADE, related_name='portfolio')
    title = models.CharField(max_length=120)
    description = models.TextField(max_length=1000, blank=True)
    image = models.ImageField(upload_to='portfolio/%Y/%m/', blank=True)


class Booking(models.Model):
    STATUS_CHOICES = [(s, s.replace('_', ' ').title()) for s in ['pending', 'accepted', 'rejected', 'completed', 'cancelled']]
    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='bookings')
    professional = models.ForeignKey(Professional, on_delete=models.PROTECT, related_name='bookings')
    category = models.ForeignKey(Category, on_delete=models.PROTECT)
    area = models.ForeignKey(Area, on_delete=models.PROTECT)
    scheduled_at = models.DateTimeField()
    address = models.CharField(max_length=300)
    details = models.TextField(max_length=2000)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']


class Quote(models.Model):
    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    professional = models.ForeignKey(Professional, on_delete=models.PROTECT, related_name='quotes')
    category = models.ForeignKey(Category, on_delete=models.PROTECT)
    area = models.ForeignKey(Area, on_delete=models.PROTECT)
    details = models.TextField(max_length=2000)
    amount = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True, validators=[MinValueValidator(1)])
    response = models.TextField(max_length=2000, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class Review(models.Model):
    booking = models.OneToOneField(Booking, on_delete=models.CASCADE, related_name='review')
    rating = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.TextField(max_length=1000)
    visible = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)


class PromotionPackage(models.Model):
    name = models.CharField(max_length=80)
    days = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(365)])
    price = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(1)])
    active = models.BooleanField(default=True)

    def __str__(self):
        return f'{self.name} · {self.days} days · BDT {self.price}'


class Promotion(models.Model):
    professional = models.ForeignKey(Professional, on_delete=models.CASCADE, related_name='promotions')
    package = models.ForeignKey(PromotionPackage, on_delete=models.PROTECT)
    category = models.ForeignKey(Category, on_delete=models.PROTECT)
    area = models.ForeignKey(Area, on_delete=models.PROTECT)
    price_paid = models.DecimalField(max_digits=10, decimal_places=2)
    duration_days = models.PositiveSmallIntegerField()
    status = models.CharField(max_length=20, choices=[('pending', 'Pending payment'), ('paid', 'Paid'), ('cancelled', 'Cancelled')], default='pending')
    starts_at = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def active(self):
        now = timezone.now()
        return bool(self.status == 'paid' and self.starts_at and self.expires_at and self.starts_at <= now < self.expires_at)


class Notification(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    message = models.CharField(max_length=300)
    read = models.BooleanField(default=False)
    push_sent = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class Report(models.Model):
    reporter = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    professional = models.ForeignKey(Professional, on_delete=models.CASCADE)
    reason = models.TextField(max_length=2000)
    resolved = models.BooleanField(default=False)
    resolution = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)


class Device(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    token = models.CharField(max_length=4096, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
