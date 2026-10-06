import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ui.dart';

Future<bool> requireLogin(BuildContext context, Api api) async {
  if (api.signedIn) return true;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => AuthScreen(api: api)),
  );
  return api.signedIn;
}

class AuthScreen extends StatefulWidget {
  final Api api;
  const AuthScreen({super.key, required this.api});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  final email = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  bool register = false;
  bool hide = true;
  String role = 'customer';
  @override
  void dispose() {
    for (final c in [username, password, email, name, phone]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(register ? 'Join SkillConnect' : 'Welcome back'),
    ),
    body: PageBody(
      width: 480,
      children: [
        const Gap(20),
        Text(
          register
              ? 'Your next connection\nstarts here.'
              : 'Good work begins\nwith a connection.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Gap(12),
        Text(
          register
              ? 'Find help nearby, or grow your own service business.'
              : 'Sign in to book a professional or manage your business.',
        ),
        const Gap(28),
        Form(
          key: form,
          child: Column(
            children: [
              if (register) ...[
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'customer',
                      label: Text('Find services'),
                      icon: Icon(Icons.search),
                    ),
                    ButtonSegment(
                      value: 'professional',
                      label: Text('Offer services'),
                      icon: Icon(Icons.handyman_outlined),
                    ),
                  ],
                  selected: {role},
                  onSelectionChanged: (v) => setState(() => role = v.first),
                ),
                const Gap(),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: requiredText,
                ),
                const Gap(),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: (v) =>
                      v != null &&
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)
                      ? null
                      : 'Enter a valid email address.',
                ),
                const Gap(),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                  validator: requiredText,
                ),
                const Gap(),
              ],
              TextFormField(
                controller: username,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(labelText: 'Username'),
                validator: requiredText,
              ),
              const Gap(),
              TextFormField(
                controller: password,
                obscureText: hide,
                autofillHints: [
                  register ? AutofillHints.newPassword : AutofillHints.password,
                ],
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: hide ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => hide = !hide),
                    icon: Icon(
                      hide
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Enter your password.'
                    : register && v.length < 8
                    ? 'Use at least 8 characters.'
                    : null,
              ),
              const Gap(24),
              SizedBox(
                width: double.infinity,
                child: ActionButton(
                  label: register ? 'Create account' : 'Sign in',
                  action: () async {
                    if (!form.currentState!.validate()) return;
                    if (register) {
                      final parts = name.text.trim().split(' ');
                      await widget.api.post('auth/register/', {
                        'username': username.text.trim(),
                        'password': password.text,
                        'email': email.text.trim(),
                        'first_name': parts.first,
                        'last_name': parts.skip(1).join(' '),
                        'phone': phone.text.trim(),
                        'role': role,
                      });
                    }
                    await widget.api.login(username.text.trim(), password.text);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
              const Gap(),
              TextButton(
                onPressed: () => setState(() => register = !register),
                child: Text(
                  register
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;

class AccountScreen extends StatelessWidget {
  final Api api;
  const AccountScreen({super.key, required this.api});
  @override
  Widget build(BuildContext context) {
    if (!api.signedIn) {
      return PageBody(
        width: 640,
        children: [
          const Gap(36),
          const Icon(Icons.handshake_outlined, size: 64, color: blue),
          const Gap(24),
          Text(
            'Find skills.\nConnect locally.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const Gap(),
          const Text(
            'Book trusted local help, track your requests and share your experience. Professionals can start a business profile for free.',
          ),
          const Gap(24),
          FilledButton(
            onPressed: () => requireLogin(context, api),
            child: const Text('Sign in or create an account'),
          ),
          if (api.startupError != null) ...[
            const Gap(),
            Text(api.startupError!),
          ],
        ],
      );
    }
    return PageBody(
      width: 720,
      children: [
        const SectionTitle('Your account'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: blue,
                  child: Text(
                    '${api.user!['first_name']}'.isEmpty
                        ? 'S'
                        : '${api.user!['first_name']}'[0],
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${api.user!['first_name']} ${api.user!['last_name']}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text('${api.user!['email']}'),
                      const Gap(8),
                      Tag(api.isProfessional ? 'Professional' : 'Customer'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Edit account details'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditAccountScreen(api: api)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Notifications'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NotificationsScreen(api: api)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('Enable device notifications'),
          subtitle: const Text(
            'Get booking updates even when the app is closed.',
          ),
          onTap: () async {
            try {
              await api.push.enableForUser();
              if (context.mounted) {
                showMessage(context, 'Device notifications enabled.');
              }
            } catch (e) {
              if (context.mounted) showMessage(context, '$e');
            }
          },
        ),
        if (api.user!['is_staff'] == true) ...[
          const Gap(),
          const SectionTitle(
            'Administration',
            subtitle:
                'Manage verification, users, pricing, reviews and reports.',
          ),
          LoadView<Json>(
            load: () async => await api.get('analytics/'),
            builder: (data, reload) => StatsGrid(data: data),
          ),
          const Gap(),
          OutlinedButton.icon(
            onPressed: () async {
              final admin = Uri.parse(api.serverUrl).resolve('../admin/');
              if (!await launchUrl(
                    admin,
                    mode: LaunchMode.externalApplication,
                  ) &&
                  context.mounted) {
                showMessage(context, 'Open $admin in your browser.');
              }
            },
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('Open admin console'),
          ),
        ],
        const Gap(28),
        ActionButton(label: 'Sign out', icon: Icons.logout, action: api.logout),
      ],
    );
  }
}

class EditAccountScreen extends StatefulWidget {
  final Api api;
  const EditAccountScreen({super.key, required this.api});
  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  @override
  void initState() {
    super.initState();
    fields = {
      for (final key in ['first_name', 'last_name', 'email', 'phone'])
        key: TextEditingController(text: '${widget.api.user![key]}'),
    };
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit account')),
    body: PageBody(
      width: 560,
      children: [
        Form(
          key: form,
          child: Column(
            children: [
              for (final e in fields.entries) ...[
                TextFormField(
                  controller: e.value,
                  decoration: InputDecoration(
                    labelText: {
                      'first_name': 'First name',
                      'last_name': 'Last name',
                      'email': 'Email address',
                      'phone': 'Phone number',
                    }[e.key],
                  ),
                  validator: e.key == 'last_name' ? null : requiredText,
                ),
                const Gap(),
              ],
              ActionButton(
                label: 'Save changes',
                action: () async {
                  if (!form.currentState!.validate()) return;
                  widget.api.updateUser(
                    await widget.api.patch(
                      'me/',
                      fields.map((k, v) => MapEntry(k, v.text.trim())),
                    ),
                  );
                  if (context.mounted) {
                    showMessage(context, 'Account updated.');
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class NotificationsScreen extends StatelessWidget {
  final Api api;
  const NotificationsScreen({super.key, required this.api});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: LoadView<List<Json>>(
      load: () => api.list('notifications/'),
      builder: (rows, reload) => PageBody(
        width: 720,
        children: [
          if (rows.isNotEmpty) ...[
            ActionButton(
              label: 'Mark all as read',
              icon: Icons.done_all,
              action: () async {
                await api.post('notifications/read-all/', {});
                reload();
              },
            ),
            const Gap(),
          ],
          if (rows.isEmpty)
            const EmptyState(
              'You’re all caught up',
              'Updates to your bookings, quotes and promotions will appear here.',
              icon: Icons.notifications_outlined,
            ),
          for (final row in rows)
            Card(
              child: ListTile(
                leading: Icon(
                  row['read'] == true
                      ? Icons.notifications_none
                      : Icons.notifications_active_outlined,
                  color: row['read'] == true ? Colors.grey : blue,
                ),
                title: Text('${row['message']}'),
                subtitle: Text(dateLabel(row['created_at'])),
              ),
            ),
        ],
      ),
    ),
  );
}

class StatsGrid extends StatelessWidget {
  final Json data;
  const StatsGrid({super.key, required this.data});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      for (final e in data.entries)
        Container(
          width: 150,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E7F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.value is num
                    ? (e.value is double
                          ? (e.value as double).toStringAsFixed(1)
                          : '${e.value}')
                    : '${e.value}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(e.key.replaceAll('_', ' ')),
            ],
          ),
        ),
    ],
  );
}
