import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api.dart';
import 'package:mobile/main.dart';
import 'package:mobile/screens/activity.dart';
import 'package:mobile/screens/professional.dart';

import 'widget_test.dart' show profile;

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'new providers start in My business and see the setup action at phone width',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final incomplete = {...profile, 'categories': [], 'areas': []};
      final api =
          Api(
              client: MockClient(
                (request) async => http.Response(
                  jsonEncode(
                    request.url.path.endsWith('/profile/')
                        ? incomplete
                        : {'bookings': 0},
                  ),
                  200,
                ),
              ),
            )
            ..ready = true
            ..user = {'id': 2, 'role': 'professional'};
      await tester.pumpWidget(SkillConnectApp(api: api));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Choose services and areas'));
      expect(find.text('Finish your business setup'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('provider saves multiple service areas and selected services', (
    tester,
  ) async {
    Json? submitted;
    final api = Api(
      client: MockClient((request) async {
        if (request.method == 'PATCH') {
          submitted = jsonDecode(request.body);
          return http.Response(jsonEncode(profile), 200);
        }
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/categories/')
                ? profile['categories']
                : [
                    ...(profile['areas'] as List),
                    {'id': 2, 'name': 'Uttara', 'city': 'Dhaka'},
                  ],
          ),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(api: api, profile: profile),
                ),
              ),
              child: const Text('Edit profile'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Uttara, Dhaka'));
    await tester.tap(find.text('Uttara, Dhaka'));
    await tester.ensureVisible(find.text('Save business profile'));
    await tester.tap(find.text('Save business profile'));
    await tester.pumpAndSettle();
    expect(submitted?['area_ids'], containsAll([1, 2]));
    expect(submitted?['category_ids'], [1]);
    expect(submitted?['business_name'], profile['business_name']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an estimate for a removed service shows guidance instead of a dropdown crash',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceRequestScreen(
            api: Api(),
            profile: profile,
            isQuote: false,
            quote: {
              'id': 3,
              'category': 9,
              'area': 1,
              'details': 'Old request',
            },
          ),
        ),
      );
      expect(find.text('This estimate needs updating'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'provider can edit a portfolio project through its owned endpoint',
    (tester) async {
      http.Request? submitted;
      final api = Api(
        client: MockClient((request) async {
          submitted = request;
          return http.Response('{"id":4,"title":"Updated project"}', 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddPortfolioScreen(
                      api: api,
                      project: {
                        'id': 4,
                        'title': 'Original project',
                        'description': 'Original description',
                      },
                    ),
                  ),
                ),
                child: const Text('Edit project'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit project'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Updated project',
      );
      await tester.ensureVisible(find.text('Save project changes'));
      await tester.tap(find.text('Save project changes'));
      await tester.pumpAndSettle();
      expect(submitted?.method, 'PATCH');
      expect(submitted?.url.path, '/api/portfolio/4/');
      expect(submitted?.body, contains('Updated project'));
    },
  );

  test(
    'demo portfolio edits update the original project without duplicating it',
    () async {
      final api = Api();
      await api.startDemo();
      await api.switchDemoRole('professional');
      final before = await api.get('profile/');
      final projects = before['portfolio'] as List;
      final id = projects.first['id'] as int;
      await api.uploadPortfolio({
        'title': 'Updated demo work',
        'description': 'Updated description',
      }, projectId: id);
      final after = await api.get('profile/');
      expect((after['portfolio'] as List).length, projects.length);
      expect((after['portfolio'] as List).first['title'], 'Updated demo work');
    },
    skip: !Api.demoAvailable,
  );
}
