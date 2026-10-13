import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedLogin {
  final String email, username, password, role;
  final int userId;
  const SavedLogin({
    required this.email,
    required this.username,
    required this.password,
    required this.role,
    required this.userId,
  });
  String get identity => email.isEmpty ? username : email;
  Map<String, dynamic> toJson() => {
    'email': email,
    'username': username,
    'password': password,
    'role': role,
    'user_id': userId,
  };
  factory SavedLogin.fromJson(Map<String, dynamic> data) => SavedLogin(
    email: data['email'] as String,
    username: data['username'] as String,
    password: data['password'] as String,
    role: data['role'] as String,
    userId: data['user_id'] as int,
  );
}

// The platform's encrypted storage holds credentials only after opting in.
// Separate API addresses never share suggestions or saved passwords.
class SavedLogins {
  final FlutterSecureStorage storage;
  final String server;
  const SavedLogins(this.storage, this.server);
  String get _key => 'saved_logins_v1_${base64Url.encode(utf8.encode(server))}';

  Future<List<SavedLogin>> load() async {
    final value = await storage.read(key: _key);
    if (value == null) return [];
    try {
      return (jsonDecode(value) as List)
          .map((v) => SavedLogin.fromJson(Map<String, dynamic>.from(v)))
          .toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  Future<void> _write(List<SavedLogin> accounts) => accounts.isEmpty
      ? storage.delete(key: _key)
      : storage.write(
          key: _key,
          value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
        );

  Future<void> save(SavedLogin account) async {
    final others = (await load()).where((a) => a.userId != account.userId);
    await _write([account, ...others.take(7)]);
  }

  Future<void> forget(int userId) async =>
      _write((await load()).where((a) => a.userId != userId).toList());

  Future<void> forgetEmail(String email) async => _write(
    (await load())
        .where((a) => a.email.toLowerCase() != email.trim().toLowerCase())
        .toList(),
  );

  Future<void> updateAccount(Map<String, dynamic> user) async {
    final old = (await load()).where((a) => a.userId == user['id']).firstOrNull;
    if (old == null) return;
    await save(
      SavedLogin(
        userId: old.userId,
        email: user['email'] as String,
        username: user['username'] as String,
        password: old.password,
        role: old.role,
      ),
    );
  }
}
