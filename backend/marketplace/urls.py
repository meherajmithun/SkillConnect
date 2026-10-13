from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenBlacklistView
from . import views
from . import accounts
from .scheduling import SlotViewSet, availability
from .payments import ipn, payment_return

router = DefaultRouter()
router.register('professionals', views.ProfessionalViewSet, basename='professionals')
router.register('portfolio', views.PortfolioViewSet, basename='portfolio')
router.register('bookings', views.BookingViewSet, basename='bookings')
router.register('quotes', views.QuoteViewSet, basename='quotes')
router.register('promotions', views.PromotionViewSet, basename='promotions')
router.register('notifications', views.NotificationViewSet, basename='notifications')
router.register('slots', SlotViewSet, basename='slots')
urlpatterns = [
    path('payments/ipn/', ipn), path('payments/return/', payment_return),
    path('professionals/<int:professional_id>/availability/', availability),
    path('', include(router.urls)), path('health/', views.health),
    path('auth/register/', views.RegisterView.as_view()), path('auth/login/', views.LoginView.as_view()),
    path('auth/refresh/', views.RefreshView.as_view()), path('auth/logout/', TokenBlacklistView.as_view()),
    path('auth/password-reset/', accounts.PasswordResetRequest.as_view()),
    path('auth/password-reset/confirm/', accounts.PasswordResetConfirm.as_view()),
    path('auth/email-verification/', accounts.EmailVerificationRequest.as_view()),
    path('auth/email-verification/confirm/', accounts.EmailVerificationConfirm.as_view()),
    path('me/', views.MeView.as_view()), path('profile/', views.OwnProfileView.as_view()),
    path('categories/', views.CategoryView.as_view()), path('areas/', views.AreaView.as_view()),
    path('reviews/', views.ReviewView.as_view()), path('packages/', views.PackageView.as_view()),
    path('reports/', views.ReportView.as_view()), path('analytics/', views.analytics),
    path('devices/', views.device),
]
