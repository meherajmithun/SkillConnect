from datetime import timedelta
from decimal import Decimal
import pytest
from django.utils import timezone
from rest_framework.test import APIClient
from marketplace.models import (User, Professional, Category, Area, Booking, Review,
                                Promotion, PromotionPackage, Quote, Notification)
from marketplace.services import activate_promotion

pytestmark = pytest.mark.django_db


@pytest.fixture
def world():
    customer = User.objects.create_user(username='customer', email='c@example.com', password='SecureTestingPass42!')
    stranger = User.objects.create_user(username='stranger', email='s@example.com', password='SecureTestingPass42!')
    owner = User.objects.create_user(username='professional', email='p@example.com', password='SecureTestingPass42!', role='professional')
    category = Category.objects.create(name='Electrician')
    area = Area.objects.create(name='Mirpur', latitude=23.82, longitude=90.36)
    other = Area.objects.create(name='Gulshan', latitude=23.79, longitude=90.40)
    profile = Professional.objects.create(user=owner, business_name='Electrical Works', bio='Safe wiring',
        latitude=23.82, longitude=90.36, skills='Lighting', verified=True)
    profile.categories.add(category)
    profile.areas.add(area, other)
    package = PromotionPackage.objects.create(name='Weekly', days=7, price=300)
    return locals()


def client(user=None):
    api = APIClient()
    if user:
        api.force_authenticate(user)
    return api


def booking_payload(w):
    return {'professional': w['profile'].id, 'category': w['category'].id, 'area': w['area'].id,
            'scheduled_at': (timezone.now() + timedelta(days=1)).isoformat(),
            'address': 'House 2, Mirpur', 'details': 'Repair a switchboard'}


def make_booking(w, state='pending'):
    return Booking.objects.create(customer=w['customer'], professional=w['profile'], category=w['category'],
        area=w['area'], scheduled_at=timezone.now() + timedelta(days=1), address='Mirpur', details='Repair', status=state)


def test_registration_hashes_password_and_blocks_admin_escalation():
    response = client().post('/api/auth/register/', {'username': 'newpro', 'email': 'new@example.com',
        'password': 'UncommonPassword47!', 'role': 'professional', 'is_staff': True, 'is_superuser': True})
    assert response.status_code == 201
    user = User.objects.get(username='newpro')
    assert user.check_password('UncommonPassword47!')
    assert not user.is_staff and not user.is_superuser
    assert Professional.objects.filter(user=user).exists()
    assert 'password' not in response.data


def test_weak_password_rejected():
    response = client().post('/api/auth/register/', {'username': 'weak', 'email': 'weak@example.com', 'password': '12345678'})
    assert response.status_code == 400


def test_jwt_refresh_and_logout(world):
    api = client()
    login = api.post('/api/auth/login/', {'username': 'customer', 'password': 'SecureTestingPass42!'})
    assert login.status_code == 200
    access, refresh = login.data['access'], login.data['refresh']
    api.credentials(HTTP_AUTHORIZATION=f'Bearer {access}')
    assert api.get('/api/me/').data['id'] == world['customer'].id
    rotated = api.post('/api/auth/refresh/', {'refresh': refresh})
    assert rotated.status_code == 200
    assert api.post('/api/auth/refresh/', {'refresh': refresh}).status_code == 401
    assert api.post('/api/auth/logout/', {'refresh': rotated.data['refresh']}).status_code == 200
    assert api.post('/api/auth/refresh/', {'refresh': rotated.data['refresh']}).status_code == 401


def test_user_cannot_change_role_or_staff(world):
    result = client(world['customer']).patch('/api/me/', {'role': 'professional', 'is_staff': True})
    assert result.status_code == 200
    world['customer'].refresh_from_db()
    assert world['customer'].role == 'customer' and not world['customer'].is_staff


def test_customer_booking_full_lifecycle_and_review(world):
    customer, pro = client(world['customer']), client(world['owner'])
    response = customer.post('/api/bookings/', booking_payload(world))
    assert response.status_code == 201
    pk = response.data['id']
    assert Notification.objects.filter(user=world['owner']).count() == 1
    assert customer.post(f'/api/bookings/{pk}/status/', {'status': 'accepted'}).status_code == 400
    assert pro.post(f'/api/bookings/{pk}/status/', {'status': 'completed'}).status_code == 400
    assert customer.post('/api/reviews/', {'booking': pk, 'rating': 5, 'comment': 'Excellent'}).status_code == 400
    assert pro.post(f'/api/bookings/{pk}/status/', {'status': 'accepted'}).status_code == 200
    assert pro.post(f'/api/bookings/{pk}/status/', {'status': 'completed'}).status_code == 200
    assert customer.post('/api/reviews/', {'booking': pk, 'rating': 5, 'comment': 'Excellent'}).status_code == 201
    assert customer.post('/api/reviews/', {'booking': pk, 'rating': 4, 'comment': 'Duplicate'}).status_code == 400
    assert customer.post(f'/api/bookings/{pk}/status/', {'status': 'cancelled'}).status_code == 400
    assert client().get(f'/api/professionals/{world["profile"].id}/').data['rating'] == 5


def test_booking_is_private_to_participants(world):
    booking = make_booking(world)
    stranger = client(world['stranger'])
    assert stranger.get('/api/bookings/').data['count'] == 0
    assert stranger.get(f'/api/bookings/{booking.id}/').status_code == 404
    assert stranger.post(f'/api/bookings/{booking.id}/status/', {'status': 'cancelled'}).status_code == 404
    assert stranger.post('/api/reviews/', {'booking': booking.id, 'rating': 5, 'comment': 'Forged'}).status_code == 400


@pytest.mark.parametrize('state', ['pending', 'accepted'])
def test_customer_can_cancel_before_completion(world, state):
    booking = make_booking(world, state)
    assert client(world['customer']).post(f'/api/bookings/{booking.id}/status/', {'status': 'cancelled'}).status_code == 200


def test_invalid_service_requests_rejected(world):
    api = client(world['customer'])
    payload = booking_payload(world)
    payload['scheduled_at'] = (timezone.now() - timedelta(days=1)).isoformat()
    assert api.post('/api/bookings/', payload).status_code == 400
    assert client(world['owner']).post('/api/bookings/', booking_payload(world)).status_code == 400
    world['profile'].available = False
    world['profile'].save()
    assert api.post('/api/bookings/', booking_payload(world)).status_code == 400
    world['profile'].available = True
    world['profile'].save()
    category = Category.objects.create(name='Plumber')
    payload = booking_payload(world)
    payload['category'] = category.id
    assert api.post('/api/bookings/', payload).status_code == 400
    area = Area.objects.create(name='Outside area', latitude=0, longitude=0)
    payload = booking_payload(world)
    payload['area'] = area.id
    assert api.post('/api/bookings/', payload).status_code == 400


def test_quote_reply_is_owner_only(world):
    api = client(world['customer'])
    payload = booking_payload(world)
    payload.pop('scheduled_at')
    payload.pop('address')
    response = api.post('/api/quotes/', payload)
    assert response.status_code == 201
    pk = response.data['id']
    reply = {'amount': '750.00', 'response': 'Parts and labor included'}
    assert api.post(f'/api/quotes/{pk}/reply/', reply).status_code == 403
    assert client(world['stranger']).post(f'/api/quotes/{pk}/reply/', reply).status_code == 404
    result = client(world['owner']).post(f'/api/quotes/{pk}/reply/', reply)
    assert result.status_code == 200 and Decimal(result.data['amount']) == 750
    assert client(world['owner']).post(f'/api/quotes/{pk}/reply/', {'amount': -1, 'response': 'Invalid'}).status_code == 400


def test_professional_profile_and_portfolio_ownership(world):
    api = client(world['owner'])
    assert client(world['customer']).get('/api/profile/').status_code == 403
    response = api.patch('/api/profile/', {'bio': 'Updated', 'verified': False}, format='json')
    assert response.status_code == 200
    world['profile'].refresh_from_db()
    assert world['profile'].bio == 'Updated' and world['profile'].verified
    result = api.post('/api/portfolio/', {'title': 'New work', 'description': 'Home wiring'})
    assert result.status_code == 201
    assert client(world['stranger']).delete(f'/api/portfolio/{result.data["id"]}/').status_code == 404
    assert api.delete(f'/api/portfolio/{result.data["id"]}/').status_code == 204


def test_promotion_purchase_snapshots_price_and_duration(world, settings):
    settings.DEMO_PAYMENTS = False
    result = client(world['owner']).post('/api/promotions/', {'package': world['package'].id,
        'category': world['category'].id, 'area': world['area'].id, 'status': 'paid', 'price_paid': '1'})
    assert result.status_code == 201
    promotion = Promotion.objects.get(pk=result.data['id'])
    assert promotion.status == 'pending' and promotion.price_paid == 300 and promotion.duration_days == 7
    world['package'].price, world['package'].days = 999, 30
    world['package'].save()
    active = activate_promotion(promotion.pk)
    assert active.expires_at - active.starts_at == timedelta(days=7)
    expires = active.expires_at
    assert activate_promotion(promotion.pk).expires_at == expires
    assert active.price_paid == 300


def test_promotions_scoped_to_service_area_and_expire(world):
    pro = world['profile']
    now = timezone.now()
    promotion = Promotion.objects.create(professional=pro, package=world['package'], category=world['category'],
        area=world['area'], price_paid=300, duration_days=7, status='paid', starts_at=now - timedelta(days=1), expires_at=now + timedelta(days=6))
    api = client()
    exact = f'/api/professionals/?category={world["category"].id}&area={world["area"].id}'
    assert api.get(exact).data['results'][0]['promoted']
    assert not api.get(f'/api/professionals/?category={world["category"].id}&area={world["other"].id}').data['results'][0]['promoted']
    assert not api.get('/api/professionals/').data['results'][0]['promoted']
    promotion.expires_at = now - timedelta(seconds=1)
    promotion.save()
    assert not api.get(exact).data['results'][0]['promoted']


def test_demo_checkout_requires_explicit_setting(world, settings):
    settings.DEMO_PAYMENTS = True
    result = client(world['owner']).post('/api/promotions/', {'package': world['package'].id,
        'category': world['category'].id, 'area': world['area'].id})
    assert result.status_code == 201
    assert client(world['owner']).get('/api/promotions/').data['results'][0]['active']


def test_distance_rating_filters_and_moderation(world):
    booking = make_booking(world, 'completed')
    review = Review.objects.create(booking=booking, rating=5, comment='Great')
    api = client()
    assert api.get('/api/professionals/?lat=23.82&lng=90.36&max_distance=1&min_rating=4.5').data['count'] == 1
    assert api.get('/api/professionals/?lat=0&lng=0&max_distance=1').data['count'] == 0
    assert api.get('/api/professionals/?lat=invalid&lng=0').status_code == 400
    assert api.get('/api/professionals/?max_distance=5').status_code == 400
    assert api.get('/api/professionals/?min_rating=nan').status_code == 400
    review.visible = False
    review.save()
    assert api.get('/api/professionals/?min_rating=4.5').data['count'] == 0
    assert api.get(f'/api/professionals/{world["profile"].id}/reviews/').data['count'] == 0


def test_paid_ranking_balances_quality(world):
    # A paid, unrated empty profile cannot outrank a well-reviewed business.
    good = world['profile']
    Review.objects.create(booking=make_booking(world, 'completed'), rating=5, comment='Good')
    other_user = User.objects.create_user(username='advertiser', email='ad@example.com', role='professional')
    weak = Professional.objects.create(user=other_user, business_name='Advertiser')
    weak.categories.add(world['category'])
    weak.areas.add(world['area'])
    promo = Promotion.objects.create(professional=weak, package=world['package'], category=world['category'],
        area=world['area'], price_paid=300, duration_days=7)
    activate_promotion(promo.pk)
    results = client().get(f'/api/professionals/?category={world["category"].id}&area={world["area"].id}').data['results']
    assert results[0]['id'] == good.id and results[1]['promoted']


def test_reports_notifications_and_analytics_are_scoped(world):
    api = client(world['customer'])
    result = api.post('/api/reports/', {'professional': world['profile'].id, 'reason': 'Investigate', 'resolved': True})
    assert result.status_code == 201 and not result.data['resolved']
    assert client(world['stranger']).get('/api/reports/').data['count'] == 0
    Notification.objects.create(user=world['customer'], message='Update')
    Notification.objects.create(user=world['owner'], message='Private')
    assert api.get('/api/notifications/').data['count'] == 1
    assert api.post('/api/notifications/read-all/').status_code == 200
    assert Notification.objects.get(user=world['owner']).read is False
    assert 'users' not in api.get('/api/analytics/').data
    world['customer'].is_staff = True
    world['customer'].save()
    assert api.get('/api/analytics/').data['users'] == 3


def test_authentication_required_for_mutations(world):
    assert client().post('/api/bookings/', booking_payload(world)).status_code == 401
    assert client().get('/api/analytics/').status_code == 401
    assert client().get('/api/categories/').status_code == 200


def test_device_registration_owned_and_deleted(world):
    from marketplace.models import Device
    token = 'test-token-012345678901234567890123456789'
    api = client(world['customer'])
    assert api.post('/api/devices/', {'token': token}).status_code == 200
    assert client(world['stranger']).delete('/api/devices/', {'token': token}, format='json').status_code == 204
    assert Device.objects.filter(user=world['customer']).exists()
    assert api.delete('/api/devices/', {'token': token}, format='json').status_code == 204
    assert not Device.objects.exists()
