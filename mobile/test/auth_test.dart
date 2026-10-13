import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api.dart';
import 'package:mobile/screens/account.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> openAuth(WidgetTester tester, Api api) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AuthScreen(api: api)),
            ),
            child: const Text('Open sign in'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open sign in'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final role in ['customer', 'professional']) {
    testWidgets(
      '$role saves email and password after successful sign-in and suggests both',
      (tester) async {
        final calls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.textInput,
          (call) async {
            calls.add(call);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.textInput,
            null,
          ),
        );
        final api = Api(
          client: MockClient(
            (request) async => http.Response(
              jsonEncode(
                request.url.path.endsWith('/me/')
                    ? {
                        'id': 7,
                        'email': '$role@example.com',
                        'username': role,
                        'role': role,
                      }
                    : {'access': 'token', 'refresh': 'refresh'},
              ),
              200,
            ),
          ),
        );
        await openAuth(tester, api);
        await tester.enterText(field('Email or username'), '$role@example.com');
        await tester.enterText(field('Password'), 'ExamplePassword42!');
        await tester.ensureVisible(find.text('Save email and password'));
        await tester.tap(find.text('Save email and password'));
        await tester.ensureVisible(find.text('Sign in').last);
        await tester.tap(find.text('Sign in').last);
        await tester.pumpAndSettle();
        final saved = (await api.savedLogins.load()).single;
        expect(saved.email, '$role@example.com');
        expect(saved.password, 'ExamplePassword42!');
        expect(saved.role, role);
        expect(
          calls.any(
            (c) =>
                c.method == 'TextInput.finishAutofillContext' &&
                c.arguments == true,
          ),
          isTrue,
        );
        await api.logout();
        await tester.tap(find.text('Open sign in'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('$role@example.com'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(field('Email or username'))
              .controller!
              .text,
          '$role@example.com',
        );
        expect(
          tester.widget<TextFormField>(field('Password')).controller!.text,
          'ExamplePassword42!',
        );
        await tester.tap(find.byTooltip('Forget saved account'));
        await tester.pumpAndSettle();
        expect(await api.savedLogins.load(), isEmpty);
        expect(
          tester.widget<TextFormField>(field('Password')).controller!.text,
          isEmpty,
        );
      },
    );
  }

  testWidgets('failed sign-in never saves credentials', (tester) async {
    final api = Api(
      client: MockClient(
        (_) async =>
            http.Response('{"detail":"Invalid email or password."}', 401),
      ),
    );
    await openAuth(tester, api);
    await tester.enterText(field('Email or username'), 'bad@example.com');
    await tester.enterText(field('Password'), 'IncorrectPassword');
    await tester.ensureVisible(find.text('Save email and password'));
    await tester.tap(find.text('Save email and password'));
    await tester.ensureVisible(find.text('Sign in').last);
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(await api.savedLogins.load(), isEmpty);
    expect(api.signedIn, isFalse);
    expect(find.text('Invalid email or password.'), findsOneWidget);
  });

  testWidgets(
    'manual sign-in leaves password storage empty without opting in',
    (tester) async {
      final api = Api(
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(
              r.url.path.endsWith('/me/')
                  ? {
                      'id': 1,
                      'email': 'customer@example.com',
                      'username': 'customer',
                      'role': 'customer',
                    }
                  : {'access': 'token', 'refresh': 'refresh'},
            ),
            200,
          ),
        ),
      );
      await openAuth(tester, api);
      await tester.enterText(
        field('Email or username'),
        'customer@example.com',
      );
      await tester.enterText(field('Password'), 'ExamplePassword42!');
      await tester.ensureVisible(find.text('Sign in').last);
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();
      expect(api.signedIn, isTrue);
      expect(await api.savedLogins.load(), isEmpty);
    },
  );
}
