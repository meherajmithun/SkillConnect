import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/api.dart';
import 'package:mobile/main.dart';

Api offlineApi() => Api(
  client: MockClient((request) async {
    fail('Offline demo attempted a network request: ${request.url}');
  }),
);

Future<Api> demoApi() async {
  final api = offlineApi();
  await api.startDemo();
  api.ready = true;
  return api;
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Offline customer/professional quotation, booking, messages and review journey', () async {
    final api = await demoApi();
    final quote = await api.post('quotes/', {
      'professional': 1,
      'category': 1,
      'area': 1,
      'details': 'Fix the lights',
    });
    final id = quote['id'];
    await api.post('quotes/$id/messages/', {'body': 'Can you help tomorrow?'});
    await api.switchDemoRole('professional');
    final inbox = await api.get('quotes/$id/messages/');
    expect(inbox['results'].single['body'], 'Can you help tomorrow?');
    await api.post('quotes/$id/messages/read/', {
      'through_id': inbox['results'].single['id'],
    });
    await api.post('quotes/$id/messages/', {
      'body': 'Yes, choose an appointment.',
    });
    final estimate = await api.post('quotes/$id/reply/', {
      'amount': '700.00',
      'response': 'Labour included',
    });
    await api.switchDemoRole('customer');
    final messages = await api.get('quotes/$id/messages/');
    expect(messages['results'].last['read_at'], isNotNull);
    final availability = await api.get('professionals/1/availability/');
    final slot = availability['slots'].first;
    final payload = {
      'quote_revision': estimate['revision'],
      'slot': slot['id'],
      'scheduled_at': slot['starts_at'],
      'duration_minutes': 60,
      'address': 'My demo home',
    };
    final booking = await api.post('quotes/$id/accept/', payload);
    expect(booking['agreed_price'], '700.00');
    expect(
      (await api.post('quotes/$id/accept/', payload))['id'],
      booking['id'],
    );
    expect((await api.get('quotes/$id/'))['booking_id'], booking['id']);
    await api.switchDemoRole('professional');
    await api.post('bookings/${booking['id']}/status/', {'status': 'accepted'});
    await api.post('bookings/${booking['id']}/status/', {
      'status': 'completed',
    });
    await api.switchDemoRole('customer');
    await api.post('reviews/', {
      'booking': booking['id'],
      'rating': 4,
      'comment': 'Good demo work',
    });
    await expectLater(
      api.post('reviews/', {
        'booking': booking['id'],
        'rating': 5,
        'comment': 'Duplicate',
      }),
      throwsA(isA<ApiException>()),
    );
    final completed = await api.get('bookings/${booking['id']}/');
    expect(completed['review']['comment'], 'Good demo work');
    expect((await api.list('notifications/')).length, greaterThan(1));
    await api.post('notifications/read-all/', {});
    expect(
      (await api.list('notifications/')).every((n) => n['read'] == true),
      isTrue,
    );
    await api.post('reports/', {
      'professional': 1,
      'reason': 'A sample concern',
    });
    expect((await api.list('reports/')).single['reason'], 'A sample concern');
  });

  test(
    'Offline calendar, portfolio, promotions and search change local data',
    () async {
      final api = await demoApi();
      await api.switchDemoRole('professional');
      await api.patch('profile/', {
        'business_name': 'Updated demo business',
        'schedule_enabled': true,
      });
      final start = DateTime.now().add(const Duration(days: 7)).toUtc();
      final slot = await api.post('slots/', {
        'starts_at': start.toIso8601String(),
        'ends_at': start.add(const Duration(hours: 1)).toIso8601String(),
      });
      await expectLater(
        api.post('slots/', {
          'starts_at': start.toIso8601String(),
          'ends_at': start.add(const Duration(hours: 1)).toIso8601String(),
        }),
        throwsA(isA<ApiException>()),
      );
      final photo = await api.uploadPortfolio({
        'title': 'Local project',
        'description': 'Saved photo',
      }, bytes: Uint8List.fromList([1, 2, 3]));
      expect(photo['image'], startsWith('data:image/'));
      expect(base64Decode(photo['image'].split(',').last), [1, 2, 3]);
      await api.delete('portfolio/${photo['id']}/');
      expect((await api.get('profile/'))['portfolio'].length, 1);
      await api.post('promotions/', {'package': 2, 'category': 1, 'area': 1});
      expect(
        (await api.get(
          'professionals/',
          query: {'category': 1, 'area': 1},
        ))['results'].single['promoted'],
        isTrue,
      );
      expect(
        (await api.get(
          'professionals/',
          query: {'category': 1, 'area': 3},
        ))['results'].single['promoted'],
        isFalse,
      );
      await api.switchDemoRole('customer');
      final booking = await api.post('bookings/', {
        'professional': 1,
        'category': 1,
        'area': 1,
        'details': 'Sample job',
        'slot': slot['id'],
        'scheduled_at': slot['starts_at'],
        'duration_minutes': 60,
        'address': 'Demo home',
      });
      expect(
        (await api.get(
          'professionals/1/availability/',
        ))['slots'].any((s) => s['id'] == slot['id']),
        isFalse,
      );
      await api.post('bookings/${booking['id']}/status/', {
        'status': 'cancelled',
      });
      expect(
        (await api.get(
          'professionals/1/availability/',
        ))['slots'].any((s) => s['id'] == slot['id']),
        isTrue,
      );
      await api.switchDemoRole('professional');
      await expectLater(
        api.delete('slots/${slot['id']}/'),
        throwsA(isA<ApiException>()),
      );
      expect((await api.get('analytics/'))['active_promotions'], 1);
      await api.patch('profile/', {'available': false});
      expect(
        (await api.get(
          'professionals/',
          query: {'category': 1, 'available': true},
        ))['count'],
        0,
      );
    },
  );

  test(
    'Local accounts, verification, recovery, persistence and live isolation',
    () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'access', value: 'real-access-token');
      await storage.write(key: 'refresh', value: 'real-refresh-token');
      final api = await demoApi();
      await api.post('auth/register/', {
        'username': 'local_customer',
        'password': 'Example123!',
        'email': 'local@example.com',
        'first_name': 'Local',
        'last_name': 'Customer',
        'phone': 'Sample contact',
        'role': 'customer',
      });
      await api.login('local_customer', 'Example123!');
      expect(api.user!['username'], 'local_customer');
      await api.post('auth/email-verification/', {});
      await api.post('auth/email-verification/confirm/', {'code': '12345678'});
      expect((await api.get('me/'))['email_verified'], isTrue);
      await api.patch('me/', {'first_name': 'Updated'});
      final restarted = offlineApi();
      await restarted.initialize();
      expect(restarted.demoMode, isTrue);
      expect(restarted.user!['first_name'], 'Updated');
      await restarted.logout();
      await restarted.post('auth/password-reset/', {
        'email': 'local@example.com',
      });
      await restarted.post('auth/password-reset/confirm/', {
        'email': 'local@example.com',
        'code': '12345678',
        'new_password': 'Changed123!',
      });
      await restarted.login('local_customer', 'Changed123!');
      await expectLater(
        restarted.post('bookings/1/messages/', {'body': 'Foreign request'}),
        throwsA(isA<ApiException>()),
      );
      await restarted.resetDemo();
      expect(restarted.user!['username'], 'demo_customer');
      expect(await storage.read(key: 'access'), 'real-access-token');
      expect(await storage.read(key: 'refresh'), 'real-refresh-token');
      await restarted.stopDemo();
      expect(restarted.demoMode, isFalse);
      expect(await storage.read(key: 'demo_enabled'), 'false');
    },
  );

  for (final width in [360.0, 1000.0]) {
    testWidgets(
      'Demo profile, quote form and role switching are clickable at $width px',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = await demoApi();
        await tester.pumpWidget(SkillConnectApp(api: api));
        await tester.pumpAndSettle();
        expect(find.text('Offline demo'), findsOneWidget);
        expect(find.text('Try professional'), findsNothing);
        expect(find.text('Try customer'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Rahim Electrical Works'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Rahim Electrical Works'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Request quote'));
        await tester.tap(find.text('Request quote'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField),
          'Test clickable demo quote',
        );
        await tester.ensureVisible(find.text('Send quote request'));
        await tester.tap(find.text('Send quote request'));
        await tester.pumpAndSettle();
        expect(
          (await api.list('quotes/')).first['details'],
          'Test clickable demo quote',
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Account'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Switch demo account'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Professional'));
        await tester.pumpAndSettle();
        expect(find.text('My business'), findsOneWidget);
        await tester.tap(find.text('My business'));
        await tester.pumpAndSettle();
        expect(find.text('Manage availability calendar'), findsOneWidget);
        await tester.ensureVisible(find.text('Manage availability calendar'));
        await tester.tap(find.text('Manage availability calendar'));
        await tester.pumpAndSettle();
        expect(find.text('Published appointments'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Account'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Switch demo account'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Customer'));
        await tester.pumpAndSettle();
        expect(api.isProfessional, isFalse);
        expect(find.text('My business'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
