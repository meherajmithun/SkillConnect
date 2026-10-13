import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'push.dart';
import 'demo.dart';
import 'credentials.dart';

typedef Json = Map<String, dynamic>;

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class Api extends ChangeNotifier {
  static const demoAvailable = bool.fromEnvironment(
    'DEMO_AVAILABLE',
    defaultValue: true,
  );
  late final PushService push = PushService(this);
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8000/api/',
  );
  final http.Client client;
  String serverUrl = baseUrl;
  final FlutterSecureStorage storage;
  String? _access;
  String? _refresh;
  Future<void>? _refreshing;
  Json? user;
  bool ready = false;
  String? startupError;
  bool demoMode = false;
  int demoGeneration = 0;
  DemoStore? _demo;
  bool get signedIn => user != null;
  bool get isProfessional => user?['role'] == 'professional';
  SavedLogins get savedLogins => SavedLogins(storage, serverUrl);

  // Render's free service can take about a minute to wake after inactivity.
  static Duration _connectionTimeout(String url) => Duration(
    seconds: Uri.parse(url).host.endsWith('.onrender.com') ? 90 : 20,
  );

  Api({http.Client? client, FlutterSecureStorage? storage})
    : client = client ?? http.Client(),
      storage = storage ?? const FlutterSecureStorage();

  Uri uri(String path, [Json? query]) =>
      Uri.parse('$serverUrl$path')
          .replace(queryParameters: query?.map((k, v) => MapEntry(k, '$v')));

  Future<void> initialize() async {
    try {
      final savedServer = await storage.read(key: 'server_url');
      final needsHostedServer =
          !const bool.fromEnvironment('ALLOW_HTTP') &&
          Uri.parse(baseUrl).scheme == 'https' &&
          Uri.tryParse(savedServer ?? '')?.scheme == 'http';
      serverUrl = needsHostedServer ? baseUrl : savedServer ?? baseUrl;
      if (needsHostedServer) {
        // Retire local-server tokens before connecting to the hosted database.
        await clearSession();
        await storage.write(key: 'server_url', value: serverUrl);
      }
      final savedDemo = demoAvailable
          ? await storage.read(key: 'demo_enabled')
          : 'false';
      if (savedDemo == 'true' ||
          savedDemo == null && const bool.fromEnvironment('DEMO_MODE')) {
        await startDemo();
        return;
      }
      await push.initialize();
      _access = await storage.read(key: 'access');
      _refresh = await storage.read(key: 'refresh');
      if (_access != null) {
        user = await get('me/');
        await push.restoreForUser();
      }
    } catch (e) {
      startupError = 'Could not restore your session. Sign in again when the server is available.';
      await clearSession();
    } finally {
      ready = true;
      notifyListeners();
    }
  }

  dynamic decode(http.Response response) {
    dynamic value;
    try {
      value = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
        'The server returned an unexpected response.',
        response.statusCode,
      );
    }
    if (response.statusCode >= 400) {
      String describe(dynamic v) {
        if (v is Map) {
          return v.entries
              .map(
                (e) =>
                    '${e.key == 'detail' || e.key == 'non_field_errors' ? '' : '${e.key}: '}${describe(e.value)}',
              )
              .join('\n');
        }
        if (v is List) return v.map(describe).join(' ');
        return '$v';
      }

      throw ApiException(describe(value), response.statusCode);
    }
    return value;
  }

  Future<void> refreshSession() async {
    if (_refresh == null) throw ApiException('Please sign in again.', 401);
    try {
      final response = await client
          .post(
            uri('auth/refresh/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': _refresh}),
          )
          .timeout(_connectionTimeout(serverUrl));
      final data = decode(response) as Json;
      _access = data['access'];
      _refresh = data['refresh'] ?? _refresh;
      await saveTokens();
    } on ApiException catch (e) {
      if (e.status == 401) await clearSession();
      rethrow;
    }
  }

  Future<dynamic> request(
    String method,
    String path, {
    Json? body,
    Json? query,
    bool retry = true,
  }) async {
    if (demoMode) {
      try {
        final result = _demo!.handle(method, path, body: body, query: query);
        if (user != null && _demo!.userId == null) {
          user = null;
          notifyListeners();
        }
        return result;
      } finally {
        // Attempts and read receipts also change local state.
        await storage.write(
          key: 'demo_state_v1',
          value: jsonEncode(_demo!.state),
        );
      }
    }
    final req = http.Request(method, uri(path, query));
    req.headers['Content-Type'] = 'application/json';
    if (_access != null) req.headers['Authorization'] = 'Bearer $_access';
    if (body != null) req.body = jsonEncode(body);
    http.Response response;
    try {
      response = await http.Response.fromStream(
        await client.send(req).timeout(_connectionTimeout(serverUrl)),
      );
    } catch (_) {
      throw ApiException(
        'Cannot reach SkillConnect. Check your connection and API address.',
      );
    }
    if (response.statusCode == 401 && _refresh != null && retry) {
      _refreshing ??= refreshSession();
      try {
        await _refreshing;
      } finally {
        _refreshing = null;
      }
      return request(method, path, body: body, query: query, retry: false);
    }
    return decode(response);
  }

  Future<dynamic> get(String path, {Json? query}) =>
      request('GET', path, query: query);
  Future<dynamic> post(String path, Json body) =>
      request('POST', path, body: body);
  Future<dynamic> patch(String path, Json body) =>
      request('PATCH', path, body: body);
  Future<dynamic> delete(String path) => request('DELETE', path);

  Future<List<Json>> list(String path, {Json? query}) async {
    final value = await get(path, query: query);
    final rows = value is List ? value : value['results'] as List;
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> login(String username, String password) async {
    if (demoMode) {
      user = await post('auth/login/', {
        'username': username,
        'password': password,
      });
      notifyListeners();
      return;
    }
    final data = await post('auth/login/', {
      'username': username,
      'password': password,
    });
    _access = data['access'];
    _refresh = data['refresh'];
    await saveTokens();
    user = await get('me/');
    await push.restoreForUser();
    notifyListeners();
  }

  Future<void> saveTokens() async {
    await storage.write(key: 'access', value: _access);
    await storage.write(key: 'refresh', value: _refresh);
  }

  void updateUser(Json value) {
    user = value;
    notifyListeners();
  }

  Future<void> changeServer(String value) async {
    var url = value.trim();
    if (!url.endsWith('/')) url += '/';
    final parsed = Uri.tryParse(url);
    if (parsed == null ||
        !['http', 'https'].contains(parsed.scheme) ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment ||
        !parsed.path.endsWith('/api/')) {
      throw ApiException(
        'Enter a server URL ending in /api/, for example http://192.168.1.10:8000/api/.',
      );
    }
    if (parsed.scheme == 'http' &&
        !const bool.fromEnvironment('ALLOW_HTTP', defaultValue: false)) {
      throw ApiException('This build requires an HTTPS server.');
    }
    try {
      final response = await client
          .get(parsed.resolve('health/'))
          .timeout(_connectionTimeout(url));
      final data = decode(response);
      if (data is! Map || data['service'] != 'SkillConnect') {
        throw ApiException('This address is not a SkillConnect server.');
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Could not connect. Check the address and make sure the server is running.',
      );
    }
    if (demoMode) await stopDemo();
    await push.unregister();
    await clearSession();
    serverUrl = url;
    await storage.write(key: 'server_url', value: serverUrl);
    startupError = null;
    notifyListeners();
  }

  Future<void> clearSession() async {
    if (demoMode) {
      _demo!.userId = null;
      user = null;
      await storage.write(
        key: 'demo_state_v1',
        value: jsonEncode(_demo!.state),
      );
      notifyListeners();
      return;
    }
    _access = null;
    _refresh = null;
    user = null;
    await storage.delete(key: 'access');
    await storage.delete(key: 'refresh');
    notifyListeners();
  }

  Future<void> logout() async {
    if (demoMode) return clearSession();
    try {
      await push.unregister();
      if (_refresh != null) await post('auth/logout/', {'refresh': _refresh});
    } finally {
      await clearSession();
    }
  }

  Future<dynamic> uploadPortfolio(
    Json fields, {
    Uint8List? bytes,
    String? filename,
  }) async {
    if (demoMode) {
      return post('portfolio/', {
        ...fields,
        'image': bytes == null
            ? null
            : 'data:image/jpeg;base64,${base64Encode(bytes)}',
      });
    }
    if (_refresh != null) await refreshSession();
    final req = http.MultipartRequest('POST', uri('portfolio/'));
    req.headers['Authorization'] = 'Bearer $_access';
    req.fields.addAll(fields.map((k, v) => MapEntry(k, '$v')));
    if (bytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: filename),
      );
    }
    try {
      return decode(
        await http.Response.fromStream(
          await client.send(req).timeout(const Duration(seconds: 30)),
        ),
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Portfolio upload failed. Check your connection and try again.',
      );
    }
  }

  Future<void> startDemo() async {
    if (!demoAvailable) {
      throw ApiException('This build uses the live SkillConnect server.');
    }
    if (demoMode) return;
    final saved = await storage.read(key: 'demo_state_v1');
    _demo = saved == null
        ? DemoStore.fresh()
        : DemoStore(Map<String, dynamic>.from(jsonDecode(saved)));
    demoMode = true;
    demoGeneration++;
    user = _demo!.userId == null ? null : _demo!.publicUser(_demo!.account());
    startupError = null;
    await storage.write(key: 'demo_enabled', value: 'true');
    await storage.write(key: 'demo_state_v1', value: jsonEncode(_demo!.state));
    notifyListeners();
  }

  Future<void> switchDemoRole(String role) async {
    if (!demoMode) return;
    _demo!.userId = role == 'professional' ? 2 : 1;
    demoGeneration++;
    user = _demo!.publicUser(_demo!.account());
    await storage.write(key: 'demo_state_v1', value: jsonEncode(_demo!.state));
    notifyListeners();
  }

  Future<void> resetDemo() async {
    if (!demoMode) return;
    _demo = DemoStore.fresh();
    demoGeneration++;
    user = _demo!.publicUser(_demo!.account());
    await storage.write(key: 'demo_state_v1', value: jsonEncode(_demo!.state));
    notifyListeners();
  }

  Future<void> stopDemo() async {
    demoMode = false;
    user = null;
    _access = null;
    _refresh = null;
    await storage.write(key: 'demo_enabled', value: 'false');
    await push.initialize();
    notifyListeners();
  }
}
