from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import (User, Category, Area, Professional, Portfolio, Booking, Quote,
                     Review, PromotionPackage, Promotion, Notification, Report, AvailabilitySlot, Payment)
from .services import activate_promotion

admin.site.site_header = 'SkillConnect · Marketplace administration'
admin.site.site_title = 'SkillConnect'
admin.site.index_title = 'Trust, services and growth'


@admin.register(User)
class MarketplaceUserAdmin(UserAdmin):
    fieldsets = UserAdmin.fieldsets + (('Marketplace', {'fields': ('role', 'phone', 'email_verified')}),)
    add_fieldsets = UserAdmin.add_fieldsets + (('Marketplace', {'fields': ('email', 'role', 'phone')}),)
    list_display = ['username', 'email', 'email_verified', 'role', 'is_active', 'is_staff']
    list_filter = UserAdmin.list_filter + ('role',)


class PortfolioInline(admin.TabularInline):
    model = Portfolio
    extra = 0


@admin.register(Professional)
class ProfessionalAdmin(admin.ModelAdmin):
    list_display = ['business_name', 'user', 'verified', 'available', 'experience_years']
    list_filter = ['verified', 'available', 'categories', 'areas']
    search_fields = ['business_name', 'user__username', 'skills']
    filter_horizontal = ['categories', 'areas']
    inlines = [PortfolioInline]
    actions = ['verify', 'unverify']

    @admin.action(description='Verify selected professionals')
    def verify(self, request, queryset):
        queryset.update(verified=True)

    @admin.action(description='Remove professional verification')
    def unverify(self, request, queryset):
        queryset.update(verified=False)


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'icon', 'active']
    list_editable = ['active']


@admin.register(Area)
class AreaAdmin(admin.ModelAdmin):
    list_display = ['name', 'city', 'latitude', 'longitude']


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display = ['id', 'customer', 'professional', 'category', 'area', 'status', 'scheduled_at']
    list_filter = ['status', 'category', 'area']
    readonly_fields = ['customer', 'professional', 'category', 'area', 'status', 'scheduled_at', 'duration_minutes', 'slot', 'quote', 'agreed_price', 'agreed_terms', 'address', 'details', 'created_at', 'updated_at']

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(Quote)
class QuoteAdmin(admin.ModelAdmin):
    list_display = ['id', 'customer', 'professional', 'category', 'amount', 'created_at']
    readonly_fields = ['customer', 'professional', 'category', 'area', 'details', 'amount', 'response', 'created_at']

    def has_add_permission(self, request):
        return False


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ['id', 'booking', 'rating', 'visible', 'created_at']
    list_filter = ['visible', 'rating']
    readonly_fields = ['booking', 'rating', 'comment', 'created_at']
    actions = ['hide', 'show']

    @admin.action(description='Hide selected reviews')
    def hide(self, request, queryset):
        queryset.update(visible=False)

    @admin.action(description='Restore selected reviews')
    def show(self, request, queryset):
        queryset.update(visible=True)

    def has_add_permission(self, request):
        return False


@admin.register(PromotionPackage)
class PromotionPackageAdmin(admin.ModelAdmin):
    list_display = ['name', 'days', 'price', 'active']
    list_editable = ['days', 'price', 'active']


@admin.register(Promotion)
class PromotionAdmin(admin.ModelAdmin):
    list_display = ['id', 'professional', 'category', 'area', 'price_paid', 'status', 'expires_at']
    list_filter = ['status', 'category', 'area']
    readonly_fields = ['professional', 'package', 'category', 'area', 'price_paid', 'duration_days', 'status', 'starts_at', 'expires_at', 'created_at']
    actions = ['confirm_payment', 'cancel']

    @admin.action(description='Confirm received payment and activate promotions')
    def confirm_payment(self, request, queryset):
        for promotion in queryset.filter(status='pending'):
            activate_promotion(promotion.pk)

    @admin.action(description='Cancel selected promotions')
    def cancel(self, request, queryset):
        queryset.update(status='cancelled')

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(Report)
class ReportAdmin(admin.ModelAdmin):
    list_display = ['id', 'reporter', 'professional', 'resolved', 'created_at']
    list_filter = ['resolved']
    readonly_fields = ['reporter', 'professional', 'reason', 'created_at']


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['user', 'message', 'read', 'created_at']
    readonly_fields = ['user', 'message', 'read', 'created_at']


@admin.register(AvailabilitySlot)
class AvailabilitySlotAdmin(admin.ModelAdmin):
    list_display = ['professional', 'starts_at', 'ends_at']
    readonly_fields = ['professional', 'starts_at', 'ends_at']

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ['transaction_id', 'promotion', 'amount', 'status', 'sandbox', 'created_at']
    list_filter = ['status', 'sandbox']
    readonly_fields = ['promotion', 'transaction_id', 'amount', 'status', 'gateway_url', 'session_key', 'validation_id', 'sandbox', 'created_at']

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
