import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';

/// Native FCM is opt-in; in-app notifications work without a Firebase project.
class PushService {
  final Api api;
  StreamSubscription<String>? _subscription;
  String? _token;
  PushService(this.api);
  static const enabled = bool.fromEnvironment('FIREBASE_ENABLED');

  Future<void> initialize() async {
    if (!enabled || kIsWeb) return;
    try {
      await Firebase.initializeApp();
      _subscription = FirebaseMessaging.instance.onTokenRefresh.listen((
        token,
      ) async {
        _token = token;
        if (api.signedIn) {
          try {
            await api.post('devices/', {'token': token});
          } catch (_) {
            /* Retry on next sign-in. */
          }
        }
      });
    } catch (_) {
      // The marketplace remains usable if Firebase has not been configured.
    }
  }

  Future<void> enableForUser() async {
    if (!enabled || kIsWeb || Firebase.apps.isEmpty) {
      throw ApiException(
        'Push notifications are not configured for this build. Updates are available in Notifications.',
      );
    }
    final permission = await FirebaseMessaging.instance.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      throw ApiException(
        'Enable notification permission in your device settings.',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await FirebaseMessaging.instance.getAPNSToken() == null) {
      throw ApiException(
        'Your device is still registering for notifications. Try again shortly.',
      );
    }
    _token = await FirebaseMessaging.instance.getToken();
    if (_token == null) {
      throw ApiException('No notification token available. Try again.');
    }
    await api.post('devices/', {'token': _token});
  }

  Future<void> unregister() async {
    if (_token != null && api.signedIn) {
      await api.request('DELETE', 'devices/', body: {'token': _token});
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
