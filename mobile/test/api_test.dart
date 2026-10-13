import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api.dart';

void main() {
  test(
    'lists retrieve later pages from our API without trusting returned URLs',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final requests = <Uri>[];
      final api = Api(
        client: MockClient((r) async {
          requests.add(r.url);
          final page = int.parse(r.url.queryParameters['page']!);
          return http.Response(
            jsonEncode({
              'results': page == 1
                  ? List.generate(30, (i) => {'id': i + 1})
                  : [
                      {'id': 31},
                    ],
              'next': page == 1
                  ? 'https://untrusted.example/steal-token?page=2'
                  : null,
            }),
            200,
          );
        }),
      );
      expect((await api.list('notifications/')).length, 31);
      expect(requests.map((r) => r.host).toSet(), {
        Uri.parse(Api.baseUrl).host,
      });
      expect(requests.last.path, '/api/notifications/');
      expect(requests.last.queryParameters['page'], '2');
    },
  );

  for (final status in [503, 401]) {
    test(
      'session restore ${status == 503 ? 'preserves tokens during outages' : 'removes expired tokens'}',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'access': 'saved-access',
          'refresh': 'saved-refresh',
        });
        final api = Api(
          client: MockClient(
            (_) async => http.Response('{"detail":"Unavailable"}', status),
          ),
        );
        await api.initialize();
        expect(api.ready, isTrue);
        expect(api.startupError, isNotNull);
        expect(
          await api.storage.read(key: 'access'),
          status == 503 ? 'saved-access' : isNull,
        );
        expect(
          await api.storage.read(key: 'refresh'),
          status == 503 ? 'saved-refresh' : isNull,
        );
      },
    );
  }
}
