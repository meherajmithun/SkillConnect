# SkillConnect mobile app

Flutter client for Android, iOS and web. Uses the Node.js/Express API in `../backend`.

From the repository root, follow the [development setup guide](../docs/sprint-1/SETUP.md)
or [main README](../README.md), start the backend, then:

```sh
cd mobile
flutter pub get
flutter run -d chrome --web-port=8080 --dart-define=ALLOW_HTTP=true
```

For an Android emulator, use `API_URL=http://10.0.2.2:8000/api/` as a Dart define.
The server connection action in the app tests and saves a different backend.

Main entry: `lib/main.dart`; API/authentication: `lib/api.dart`; shared theme and
widgets: `lib/ui.dart`; feature screens: `lib/screens/`.

```sh
flutter analyze
flutter test
```

The [Sprint 1 design prototype](../docs/sprint-1/prototype/index.html) is a separate,
offline review artifact. Run `make prototype` from the repository root to inspect
it in a phone frame. The production interface is the Flutter code in this folder.
