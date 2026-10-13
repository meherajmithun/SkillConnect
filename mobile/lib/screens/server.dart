import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';

class ServerScreen extends StatefulWidget {
  final Api api;
  const ServerScreen({super.key, required this.api});
  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  late final url = TextEditingController(text: widget.api.serverUrl);
  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Connect to SkillConnect')),
    body: PageBody(
      width: 600,
      children: [
        SectionTitle(
          widget.api.demoMode
              ? 'Offline demo is active'
              : 'Explore without hosting',
          subtitle: 'Try customer and professional flows with sample data saved only on this device. No real bookings, calls, payments or emails are sent.',
        ),
        if (!widget.api.demoMode)
          ActionButton(
            label: 'Start offline demo',
            icon: Icons.touch_app_outlined,
            action: () async {
              await widget.api.startDemo();
              if (context.mounted) Navigator.pop(context);
            },
          )
        else ...[
          const Text(
            'Demo sign-in: demo_customer or demo_pro\nPassword: Demo1234!\nEmail verification/reset code: 12345678',
          ),
          const Gap(),
          ActionButton(
            label: 'Reset demo data',
            action: () async {
              final reset = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset the offline demo?'),
                  content: const Text(
                    'This removes your local demo changes and restores the sample accounts. Your live server data is separate.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep changes'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (reset != true) return;
              await widget.api.resetDemo();
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const Gap(),
          ActionButton(
            label: 'Exit demo and use live server',
            action: () async {
              await widget.api.stopDemo();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
        const Gap(24),
        const SectionTitle(
          'Server connection',
          subtitle: 'For a shared test build, use the server address provided by the person hosting SkillConnect.',
        ),
        const Text(
          'On the same Wi-Fi, enter the hosting computer’s local address. For use from anywhere, connect to an HTTPS server.',
        ),
        const Gap(24),
        TextField(
          controller: url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Server URL',
            hintText: 'https://your-server.example/api/',
          ),
        ),
        const Gap(),
        const Text(
          'Switching servers signs you out. Your data stays on the server where you created it.',
        ),
        const Gap(24),
        ActionButton(
          label: 'Test connection & save',
          icon: Icons.link,
          action: () async {
            await widget.api.changeServer(url.text);
            if (context.mounted) {
              showMessage(
                context,
                'Connected. Sign in to this server to continue.',
              );
              Navigator.pop(context);
            }
          },
        ),
      ],
    ),
  );
}
