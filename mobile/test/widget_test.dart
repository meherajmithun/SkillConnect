import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api.dart';
import 'package:mobile/main.dart';
import 'package:mobile/screens/account.dart';
import 'package:mobile/screens/activity.dart';
import 'package:mobile/ui.dart';

const profile = <String, dynamic>{
  'id': 1,
  'business_name': 'Rahim Electrical Works',
  'name': 'Rahim Uddin',
  'phone': '+8801700000000',
  'bio': 'Reliable electrical care for your home.',
  'skills': 'Wiring, lighting',
  'experience_years': 8,
  'available': true,
  'verified': true,
  'starting_price': '450.00',
  'rating': 4.8,
  'review_count': 12,
  'categories': [
    {'id': 1, 'name': 'Electrician', 'icon': 'bolt'},
  ],
  'areas': [
    {'id': 1, 'name': 'Mirpur', 'latitude': 23.82, 'longitude': 90.36},
  ],
  'portfolio': [],
  'latitude': null,
  'longitude': null,
  'promoted': false,
};

Api testApi({bool error = false, void Function(http.Request)? inspect}) => Api(
  client: MockClient((request) async {
    inspect?.call(request);
    if (error) {
      return http.Response(jsonEncode({'detail': 'Server unavailable'}), 503);
    }
    final path = request.url.path;
    final dynamic body = switch (path) {
      '/api/categories/' => profile['categories'],
      '/api/areas/' => profile['areas'],
      '/api/professionals/' => {
        'count': 1,
        'results': [profile],
        'next': null,
        'previous': null,
      },
      '/api/professionals/1/' => profile,
      '/api/professionals/1/reviews/' => {'results': [], 'count': 0},
      '/api/auth/login/' => {
        'access': 'access-value',
        'refresh': 'refresh-value',
      },
      '/api/auth/refresh/' => {
        'access': 'new-access',
        'refresh': 'new-refresh',
      },
      '/api/me/' => {
        'id': 1,
        'username': 'nadia',
        'first_name': 'Nadia',
        'last_name': 'Rahman',
        'role': 'customer',
        'is_staff': false,
        'email': 'n@example.com',
      },
      '/api/bookings/' => {'id': 1},
      _ => {'detail': 'OK'},
    };
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  }),
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final width in [360.0, 1000.0]) {
    testWidgets('Discovery and profile render at $width px', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = testApi()..ready = true;
      await tester.pumpWidget(SkillConnectApp(api: api));
      await tester.pumpAndSettle();
      expect(find.text('SkillConnect'), findsOneWidget);
      expect(find.text('A little help.\nRight around here.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Rahim Electrical Works'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Rahim Electrical Works'));
      await tester.pumpAndSettle();
      expect(find.text('Book service'), findsOneWidget);
      expect(find.text('Request quote'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Network errors show a retry action', (tester) async {
    await tester.pumpWidget(
      SkillConnectApp(api: testApi(error: true)..ready = true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not connect'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
  testWidgets('Login validates empty credentials', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: AuthScreen(api: testApi()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('This field is required.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Quote request sends selected service and area', (tester) async {
    http.Request? sent;
    final api = testApi(
      inspect: (req) {
        if (req.method == 'POST') sent = req;
      },
    );
    api.user = {'role': 'customer'};
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: ServiceRequestScreen(api: api, profile: profile, isQuote: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Repair the kitchen lights',
    );
    await tester.tap(find.text('Send quote request'));
    await tester.pumpAndSettle();
    expect(sent?.url.path, '/api/quotes/');
    final body = jsonDecode(sent!.body);
    expect(body['professional'], 1);
    expect(body['category'], 1);
    expect(body['area'], 1);
    expect(body['details'], 'Repair the kitchen lights');
  });
  test('JWT refresh retries requests and persists rotated tokens', () async {
    FlutterSecureStorage.setMockInitialValues({
      'access': 'expired',
      'refresh': 'original',
    });
    final api = Api(
      client: MockClient((req) async {
        if (req.url.path == '/api/auth/refresh/') {
          return http.Response(
            jsonEncode({'access': 'renewed', 'refresh': 'rotated'}),
            200,
          );
        }
        if (req.headers['Authorization'] == 'Bearer expired') {
          return http.Response('{"detail":"Expired"}', 401);
        }
        return http.Response('{"id":1,"role":"customer"}', 200);
      }),
    );
    await api.initialize();
    expect(api.user?['id'], 1);
    expect(await api.storage.read(key: 'refresh'), 'rotated');
    expect(api.ready, isTrue);
  });
}
