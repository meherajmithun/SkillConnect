import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/credentials.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  const storage = FlutterSecureStorage();
  const vault = SavedLogins(storage, 'https://skillconnect.example/api/');
  const customer = SavedLogin(
    email: 'customer@example.com',
    username: 'customer',
    password: 'Example123!',
    role: 'customer',
    userId: 1,
  );
  const provider = SavedLogin(
    email: 'provider@example.com',
    username: 'provider',
    password: 'Provider123!',
    role: 'professional',
    userId: 2,
  );

  test(
    'both roles persist independently and another server gets no suggestions',
    () async {
      await vault.save(customer);
      await vault.save(provider);
      final reopened = SavedLogins(storage, vault.server);
      expect((await reopened.load()).map((a) => a.email), [
        provider.email,
        customer.email,
      ]);
      expect((await reopened.load()).last.password, customer.password);
      expect(
        await const SavedLogins(storage, 'https://another.example/api/').load(),
        isEmpty,
      );
      await vault.forget(provider.userId);
      expect((await vault.load()).single.email, customer.email);
    },
  );

  test('account edits update suggestions and password reset forgets only that email', () async {
    await vault.save(customer);
    await vault.save(provider);
    await vault.updateAccount({
      'id': 1,
      'email': 'new@example.com',
      'username': 'customer',
    });
    expect((await vault.load()).first.email, 'new@example.com');
    expect((await vault.load()).first.password, customer.password);
    await vault.forgetEmail(' NEW@EXAMPLE.COM ');
    expect((await vault.load()).single.email, provider.email);
  });
}
