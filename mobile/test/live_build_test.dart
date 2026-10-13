import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api.dart';
import 'package:mobile/main.dart';
import 'package:mobile/screens/server.dart';
import 'package:mobile/ui.dart';

void main() {
  test(
    'HTTPS update migrates saved HTTP server and retires local tokens',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'server_url': 'http://192.168.0.174:8000/api/',
        'access': 'old-local-access-token',
        'refresh': 'old-local-refresh-token',
      });
      final requests = <http.Request>[];
      final api = Api(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"status":"ok"}', 200);
        }),
      );
      await api.initialize();
      expect(api.serverUrl, Api.baseUrl);
      expect(api.user, isNull);
      expect(api.startupError, isNull);
      expect(await api.storage.read(key: 'access'), isNull);
      expect(await api.storage.read(key: 'refresh'), isNull);
      expect(await api.storage.read(key: 'server_url'), Api.baseUrl);
      expect(requests, isEmpty);
      await api.get('health/');
      expect(requests.single.url.toString(), '${Api.baseUrl}health/');
      expect(requests.single.headers['Authorization'], isNull);
    },
    skip:
        !Api.baseUrl.startsWith('https://') ||
        const bool.fromEnvironment('ALLOW_HTTP'),
  );

  test('HTTPS update preserves an explicitly saved HTTPS server', () async {
    const saved = 'https://custom-api.example/api/';
    FlutterSecureStorage.setMockInitialValues({'server_url': saved});
    final api = Api();
    await api.initialize();
    expect(api.serverUrl, saved);
    expect(await api.storage.read(key: 'server_url'), saved);
  }, skip: !Api.baseUrl.startsWith('https://'));

  testWidgets('Live build ignores saved demo mode and removes demo controls', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      'demo_enabled': 'true',
      'demo_state_v1': 'This old demo state must not be loaded.',
    });
    final requests = <String>[];
    final api = Api(
      client: MockClient((request) async {
        requests.add(request.url.path);
        return http.Response(
          jsonEncode(
            request.url.path.contains('professionals')
                ? {'count': 0, 'results': [], 'next': null, 'previous': null}
                : [],
          ),
          200,
        );
      }),
    );
    await api.initialize();
    expect(api.demoMode, isFalse);
    expect(api.startupError, isNull);
    await expectLater(api.startDemo(), throwsA(isA<ApiException>()));
    await tester.pumpWidget(SkillConnectApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Offline demo'), findsNothing);
    expect(find.text('Explore offline demo'), findsNothing);
    expect(requests, contains('/api/professionals/'));
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: ServerScreen(api: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Server connection'), findsOneWidget);
    expect(find.text('Start offline demo'), findsNothing);
    expect(find.text('Explore without hosting'), findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: Api.demoAvailable);
}
