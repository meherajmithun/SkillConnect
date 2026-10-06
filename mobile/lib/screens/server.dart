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
