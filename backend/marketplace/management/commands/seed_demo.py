import os
from datetime import timedelta
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone
from marketplace.models import (User, Category, Area, Professional, Portfolio,
                                Booking, Review, PromotionPackage)


class Command(BaseCommand):
    help = 'Create repeatable demo data. Requires DEMO_PASSWORD; never use on a production database.'

    @transaction.atomic
    def handle(self, *args, **options):
        password = os.getenv('DEMO_PASSWORD')
        if not password or len(password) < 12:
            raise CommandError('Set DEMO_PASSWORD to at least 12 characters.')
        from django.conf import settings
        if not settings.DEBUG:
            raise CommandError('Demo seeding is disabled in production.')
        categories = {}
        for name, icon in [('Plumber', 'plumbing'), ('Electrician', 'bolt'), ('Carpenter', 'carpenter'),
            ('Painter', 'format_paint'), ('Cleaner', 'cleaning_services'), ('Mechanic', 'build'),
            ('AC Technician', 'ac_unit'), ('Computer Technician', 'computer'),
            ('Web Developer', 'code'), ('App Developer', 'phone_android'), ('Graphic Designer', 'palette')]:
            categories[name], _ = Category.objects.get_or_create(name=name, defaults={'icon': icon})
        areas = {}
        for name, lat, lng in [('Mirpur', 23.8223, 90.3654), ('Dhanmondi', 23.7465, 90.3760),
            ('Uttara', 23.8759, 90.3795), ('Gulshan', 23.7925, 90.4078), ('Banani', 23.7937, 90.4066),
            ('Mohammadpur', 23.7658, 90.3581)]:
            areas[name], _ = Area.objects.get_or_create(name=name, defaults={'latitude': lat, 'longitude': lng})
        customer, created = User.objects.get_or_create(username='customer', defaults={
            'email': 'customer@example.com', 'first_name': 'Nadia', 'last_name': 'Rahman', 'phone': '+8801700000000'})
        if created:
            customer.set_password(password)
            customer.save()
        data = [
            ('rahim', 'Rahim', 'Uddin', 'Rahim Electrical Works', 'Electrician', 'Mirpur', 8, 450,
             'Safe wiring, switchboard repairs and dependable electrical care for homes and small businesses.', 'Wiring, switchboards, lighting', 5),
            ('sadia', 'Sadia', 'Akter', 'Sadia Web Studio', 'Web Developer', 'Dhanmondi', 5, 2500,
             'Thoughtful websites for local businesses. From your first landing page to a complete online store.', 'Django, Flutter, e-commerce', 5),
            ('karim', 'Karim', 'Hasan', 'Karim Plumbing', 'Plumber', 'Mirpur', 12, 350,
             'Leaking taps, water lines and bathroom installations. Clear estimates before every job.', 'Leak repairs, pipe fitting, installations', 4),
            ('farzana', 'Farzana', 'Islam', 'Fresh Space Cleaning', 'Cleaner', 'Gulshan', 4, 800,
             'A fresh start for your home. Regular cleaning, move-in care and careful deep cleaning.', 'Deep cleaning, home care, office cleaning', 5),
            ('imran', 'Imran', 'Hossain', 'Cool Air Service', 'AC Technician', 'Uttara', 7, 600,
             'Keep your home comfortable with AC servicing, installation and cooling diagnostics.', 'AC maintenance, installation, repairs', 4),
            ('tanim', 'Tanim', 'Ahmed', 'Tanim Design Desk', 'Graphic Designer', 'Banani', 6, 1200,
             'Brand identities and practical design for growing businesses in Dhaka.', 'Logo design, packaging, social media', 5),
        ]
        for username, first, last, business, category, area, years, price, bio, skills, rating in data:
            user, created = User.objects.get_or_create(username=username, defaults={'email': f'{username}@example.com',
                'role': 'professional', 'first_name': first, 'last_name': last, 'phone': '+8801700000000'})
            if created:
                user.set_password(password)
                user.save()
            pro, _ = Professional.objects.get_or_create(user=user, defaults={'business_name': business,
                'bio': bio, 'skills': skills, 'experience_years': years, 'starting_price': price, 'verified': True,
                'latitude': areas[area].latitude, 'longitude': areas[area].longitude})
            pro.categories.add(categories[category])
            pro.areas.add(areas[area], areas['Mirpur'])
            Portfolio.objects.get_or_create(professional=pro, title='Recent local project', defaults={
                'description': f'{category} work completed for a local customer, with a clear estimate and careful follow-up.'})
            booking, _ = Booking.objects.get_or_create(customer=customer, professional=pro, details='Demo completed service',
                defaults={'category': categories[category], 'area': areas[area], 'address': 'Demo address, Dhaka',
                    'scheduled_at': timezone.now() - timedelta(days=7), 'status': 'completed'})
            Review.objects.get_or_create(booking=booking, defaults={'rating': rating,
                'comment': 'Arrived on time, explained the work clearly and left everything tidy.'})
        for name, days, price in [('Starter', 1, 100), ('Weekly', 7, 300), ('Half-Month', 15, 500), ('Monthly', 30, 800)]:
            PromotionPackage.objects.get_or_create(name=name, defaults={'days': days, 'price': price})
        self.stdout.write(self.style.SUCCESS('Demo data ready. Log in as customer or rahim using DEMO_PASSWORD.'))
