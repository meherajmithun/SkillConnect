import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';

FirebaseOptions? pushOptions() {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const androidApp = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  const iosApp = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  final appId = defaultTargetPlatform == TargetPlatform.iOS
      ? iosApp
      : androidApp;
  if (apiKey.isEmpty || projectId.isEmpty || sender.isEmpty || appId.isEmpty) {
    return null;
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: sender,
    projectId: projectId,
  );
}

@pragma('vm:entry-point')
Future<void> backgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: pushOptions());
}

/// In-app notifications continue to work when native Firebase is unconfigured.
class PushService {
  final Api api;
  StreamSubscription<String>? _subscription;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  final foregroundMessages = StreamController<String>.broadcast();
  final openedNotifications = StreamController<void>.broadcast();
  bool pendingOpen = false;
  String? configurationError;
  String? _token;
  PushService(this.api);
  static const enabled = bool.fromEnvironment('FIREBASE_ENABLED');

  Future<void> initialize() async {
    if (!enabled || kIsWeb) return;
    try {
      await Firebase.initializeApp(options: pushOptions());
      FirebaseMessaging.onBackgroundMessage(backgroundMessage);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
      _foreground = FirebaseMessaging.onMessage.listen((message) {
        if (api.signedIn && message.notification?.body != null) {
          foregroundMessages.add(message.notification!.body!);
        }
      });
      _opened = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        pendingOpen = true;
        openedNotifications.add(null);
      });
      pendingOpen =
          await FirebaseMessaging.instance.getInitialMessage() != null;
      _subscription = FirebaseMessaging.instance.onTokenRefresh.listen((
        token,
      ) async {
        _token = token;
        if (api.signedIn &&
            await api.storage.read(key: 'push_enabled') == 'true') {
          try {
            await api.post('devices/', {'token': token});
          } catch (_) {
            /* Retry on next sign-in. */
          }
        }
      });
    } catch (_) {
      configurationError =
          'Firebase configuration is unavailable for this build.';
    }
  }

  Future<void> restoreForUser() async {
    if (!enabled || kIsWeb || Firebase.apps.isEmpty || !api.signedIn) return;
    if (await api.storage.read(key: 'push_enabled') != 'true') return;
    try {
      final permission = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (![
        AuthorizationStatus.authorized,
        AuthorizationStatus.provisional,
      ].contains(permission.authorizationStatus)) {
        return;
      }
      _token = await FirebaseMessaging.instance.getToken();
      if (_token != null) await api.post('devices/', {'token': _token});
    } catch (_) {
      /* The next sign-in or explicit enable action retries registration. */
    }
  }

  Future<void> enableForUser() async {
    if (!enabled || kIsWeb || Firebase.apps.isEmpty) {
      throw ApiException(
        configurationError ?? 'Push notifications are not configured for this build. Updates are available in Notifications.',
      );
    }
    final permission = await FirebaseMessaging.instance.requestPermission();
    if (![
      AuthorizationStatus.authorized,
      AuthorizationStatus.provisional,
    ].contains(permission.authorizationStatus)) {
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
    await api.storage.write(key: 'push_enabled', value: 'true');
  }

  Future<void> unregister() async {
    if (_token != null && api.signedIn) {
      await api.request('DELETE', 'devices/', body: {'token': _token});
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _foreground?.cancel();
    await _opened?.cancel();
    await foregroundMessages.close();
    await openedNotifications.close();
  }
}
