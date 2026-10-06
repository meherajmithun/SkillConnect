import 'package:flutter/material.dart';

import 'api.dart';
import 'ui.dart';
import 'screens/discover.dart';
import 'screens/activity.dart';
import 'screens/account.dart';
import 'screens/professional.dart';
import 'screens/server.dart';

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
  Widget build(BuildContext context) => MaterialApp(
    title: 'SkillConnect',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: AnimatedBuilder(
      animation: api,
      builder: (context, _) => api.ready
          ? HomeShell(key: ValueKey(api.serverUrl), api: api)
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
  @override
  Widget build(BuildContext context) {
    final api = widget.api;
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
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.handshake_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
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
          IconButton(
            tooltip: 'Server connection',
            icon: const Icon(Icons.link_rounded),
            onPressed: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ServerScreen(api: api)),
                ).then((_) {
                  if (mounted) setState(() => selected = 0);
                }),
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
