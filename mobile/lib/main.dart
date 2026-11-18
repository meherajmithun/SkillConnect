import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'ui.dart';
import 'screens/discover.dart';
import 'screens/activity.dart';
import 'screens/account.dart';
import 'screens/professional.dart';
import 'screens/welcome.dart';

final skillConnectNavigator = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = Api();
  runApp(SkillConnectApp(api: api));
  api.initialize();
}

class SkillConnectApp extends StatelessWidget {
  final Api api;
  const SkillConnectApp({super.key, required this.api});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: api,
    builder: (context, _) => MaterialApp(
      title: 'SkillConnect',
      navigatorKey: skillConnectNavigator,
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      darkTheme: appTheme(brightness: Brightness.dark),
      themeMode: switch (api.themeModePreference) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      builder: (context, child) => !api.demoMode
          ? child!
          : Column(
              children: [
                Material(
                  color: const Color(0xFF142436),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.cloud_off_rounded,
                            color: Color(0xFF92D9F7),
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Offline demo',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: -.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(child: child!),
              ],
            ),
      home: api.ready
          ? !api.signedIn && !api.demoMode
                ? WelcomeScreen(api: api)
                : HomeShell(
                    key: ValueKey(
                      '${api.serverUrl}:${api.demoMode}:${api.demoGeneration}:${api.user?['id']}',
                    ),
                    api: api,
                  )
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    ),
  );
}

class HomeShell extends StatefulWidget {
  final Api api;
  const HomeShell({super.key, required this.api});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selected = 0;
  StreamSubscription<String>? foreground;
  StreamSubscription<void>? opened;

  @override
  void initState() {
    super.initState();
    if (widget.api.isProfessional && !widget.api.demoMode) selected = 2;
    foreground = widget.api.push.foregroundMessages.stream.listen((message) {
      if (mounted) showMessage(context, message);
    });
    opened = widget.api.push.openedNotifications.stream.listen(
      (_) => openNotifications(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => openNotifications());
  }

  void openNotifications() {
    if (!mounted || !widget.api.signedIn || !widget.api.push.pendingOpen) {
      return;
    }
    widget.api.push.pendingOpen = false;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotificationsScreen(api: widget.api)),
    );
  }

  @override
  void dispose() {
    foreground?.cancel();
    opened?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    if (api.push.pendingOpen && api.signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ModalRoute.of(context)?.isCurrent == true) openNotifications();
      });
    }
    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.explore_outlined),
        selectedIcon: Icon(Icons.explore_rounded),
        label: 'Discover',
      ),
      const NavigationDestination(
        icon: Icon(Icons.event_note_outlined),
        selectedIcon: Icon(Icons.event_note_rounded),
        label: 'Activity',
      ),
      if (api.isProfessional)
        const NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          label: 'My business',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Account',
      ),
    ];
    if (selected >= destinations.length) selected = 0;
    final pages = [
      DiscoverScreen(api: api),
      ActivityScreen(api: api),
      if (api.isProfessional) BusinessScreen(api: api),
      AccountScreen(api: api),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandIcon(),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'SkillConnect',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Appearance',
            initialValue: api.themeModePreference,
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
            ),
            onSelected: api.setThemeMode,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'system', child: Text('Use device setting')),
              PopupMenuItem(value: 'light', child: Text('Light mode')),
              PopupMenuItem(value: 'dark', child: Text('Dark mode')),
            ],
          ),
          if (api.signedIn)
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationsScreen(api: api),
                ),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: pages[selected],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        destinations: destinations,
        onDestinationSelected: (i) => setState(() => selected = i),
      ),
    );
  }
}
