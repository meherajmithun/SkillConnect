import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api.dart';
import 'package:mobile/screens/activity.dart';
import 'package:mobile/screens/calendar.dart';
import 'package:mobile/screens/messages.dart';
import 'package:mobile/screens/recovery.dart';

import 'widget_test.dart' show profile;

Api mockApi(dynamic Function(http.Request) respond) => Api(
  client: MockClient(
    (request) async => http.Response(
      jsonEncode(respond(request)),
      200,
      headers: {'content-type': 'application/json'},
    ),
  ),
)..user = {'id': 1, 'role': 'customer', 'email': 'customer@example.com'};

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'Password recovery sends code and submits a matching new password',
    (tester) async {
      final requests = <http.Request>[];
      final api = mockApi((request) {
        requests.add(request);
        return {'detail': 'Check your email.'};
      });
      await tester.pumpWidget(MaterialApp(home: RecoveryScreen(api: api)));
      await tester.enterText(
        find.byType(TextFormField).first,
        'customer@example.com',
      );
      await tester.tap(find.text('Send email code'));
      await tester.pumpAndSettle();
      expect(find.text('Email code'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), '12345678');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'UpdatedPassword42!',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'MismatchPassword',
      );
      await tester.ensureVisible(find.text('Update password'));
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(find.text('Passwords must match.'), findsOneWidget);
      expect(requests.length, 1);
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'UpdatedPassword42!',
      );
      await tester.ensureVisible(find.text('Update password'));
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(requests.last.url.path, '/api/auth/password-reset/confirm/');
      expect(jsonDecode(requests.last.body), {
        'email': 'customer@example.com',
        'code': '12345678',
        'new_password': 'UpdatedPassword42!',
      });
    },
  );

  testWidgets(
    'Calendar-restricted professional does not offer arbitrary times',
    (tester) async {
      final api = mockApi((_) => {'schedule_enabled': true, 'slots': []});
      await tester.pumpWidget(
        MaterialApp(home: AppointmentScreen(api: api, professional: 1)),
      );
      await tester.pumpAndSettle();
      expect(find.text('No published appointments'), findsOneWidget);
      expect(find.text('Request another time'), findsNothing);
    },
  );

  testWidgets(
    'Accepting an estimate sends its revision and selected calendar slot',
    (tester) async {
      Json? submitted;
      final start = DateTime.now().toUtc().add(const Duration(days: 2));
      final api = mockApi((request) {
        if (request.url.path.endsWith('/availability/')) {
          return {
            'schedule_enabled': true,
            'slots': [
              {
                'id': 9,
                'starts_at': start.toIso8601String(),
                'ends_at': start
                    .add(const Duration(minutes: 90))
                    .toIso8601String(),
              },
            ],
          };
        }
        if (request.method == 'POST') submitted = jsonDecode(request.body);
        return {'id': 5};
      });
      final quote = <String, dynamic>{
        'id': 7,
        'professional': 1,
        'category': 1,
        'area': 1,
        'details': 'Repair the wiring',
        'amount': '750.00',
        'response': 'Parts included',
        'revision': 2,
      };
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceRequestScreen(
            api: api,
            profile: profile,
            isQuote: false,
            quote: quote,
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'House 12, Mirpur',
      );
      await tester.tap(find.text('Choose date & time'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.event_available_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Agreed price: BDT 750.00'), findsOneWidget);
      await tester.ensureVisible(
        find.text('Accept estimate and request booking'),
      );
      await tester.tap(find.text('Accept estimate and request booking'));
      await tester.pumpAndSettle();
      expect(submitted?['quote_revision'], 2);
      expect(submitted?['slot'], 9);
      expect(submitted?['duration_minutes'], 90);
      expect(submitted?['details'], 'Repair the wiring');
    },
  );

  for (final width in [360.0, 1000.0]) {
    testWidgets(
      'Messages render at $width px and send through the request conversation',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final sent = <http.Request>[];
        final api = mockApi((request) {
          if (request.method == 'POST') {
            sent.add(request);
            return {'detail': 'OK'};
          }
          return {
            'results': [
              {
                'id': 3,
                'sender': 2,
                'sender_name': 'Rahim',
                'body': 'I can bring the parts.',
                'created_at': DateTime.now().toIso8601String(),
                'read_at': null,
              },
            ],
            'next': null,
            'previous': null,
            'count': 1,
          };
        });
        await tester.pumpWidget(
          MaterialApp(
            home: MessagesScreen(
              api: api,
              kind: 'bookings',
              requestId: 5,
              title: 'Rahim',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('I can bring the parts.'), findsOneWidget);
        expect(jsonDecode(sent.first.body)['through_id'], 3);
        await tester.enterText(
          find.byType(TextField),
          'Thank you, please bring them.',
        );
        await tester.tap(find.text('Send message'));
        await tester.pumpAndSettle();
        expect(
          sent.any(
            (r) =>
                r.url.path == '/api/bookings/5/messages/' &&
                jsonDecode(r.body)['body'] == 'Thank you, please bring them.',
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox()); // Dispose polling timer.
      },
    );
  }
}
