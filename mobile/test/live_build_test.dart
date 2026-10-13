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
