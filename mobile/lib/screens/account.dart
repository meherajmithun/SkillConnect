import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../credentials.dart';
import '../ui.dart';
import 'recovery.dart';

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
  final confirmPassword = TextEditingController();
  final email = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  bool register = false;
  bool hide = true;
  bool savePassword = false;
  List<SavedLogin> saved = [];
  String role = 'customer';
  @override
  void initState() {
    super.initState();
    loadSaved();
  }

  Future<void> loadSaved() async {
    if (widget.api.demoMode) return;
    try {
      final accounts = await widget.api.savedLogins.load();
      if (mounted) setState(() => saved = accounts);
    } catch (_) {
      // A unavailable password store must not prevent manual sign-in.
    }
  }

  @override
  void dispose() {
    for (final c in [username, password, confirmPassword, email, name, phone]) {
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
        if (widget.api.demoMode) ...[
          const Text(
            'Offline demo accounts: demo_customer or demo_pro\nPassword: Demo1234!\nUse sample details when creating a local demo account.',
          ),
          const Gap(),
        ],
        if (!register && saved.isNotEmpty) ...[
          const Text('Saved accounts on this device'),
          for (final account in saved)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.key_outlined),
              title: Text(account.identity),
              subtitle: Text(
                account.role == 'professional'
                    ? 'Service provider'
                    : 'Customer',
              ),
              onTap: () => setState(() {
                username.text = account.identity;
                password.text = account.password;
                savePassword = true;
              }),
              trailing: IconButton(
                tooltip: 'Forget saved account',
                icon: const Icon(Icons.close),
                onPressed: () async {
                  try {
                    await widget.api.savedLogins.forget(account.userId);
                    if (username.text == account.identity) password.clear();
                    await loadSaved();
                  } catch (e) {
                    if (context.mounted) showMessage(context, '$e');
                  }
                },
              ),
            ),
          const Gap(),
        ],
        AutofillGroup(
          key: ValueKey(register),
          onDisposeAction: AutofillContextAction.cancel,
          child: Form(
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
                    keyboardType: TextInputType.name,
                    autofillHints: const [AutofillHints.name],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: requiredText,
                  ),
                  const Gap(),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                    ),
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
                    autofillHints: const [AutofillHints.telephoneNumber],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                    ),
                    validator: requiredText,
                  ),
                  const Gap(),
                ],
                TextFormField(
                  controller: username,
                  keyboardType: register
                      ? TextInputType.text
                      : TextInputType.emailAddress,
                  autofillHints: register
                      ? null
                      : const [AutofillHints.username, AutofillHints.email],
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: register ? 'Username' : 'Email or username',
                  ),
                  validator: requiredText,
                ),
                const Gap(),
                TextFormField(
                  controller: password,
                  obscureText: hide,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  autofillHints: [
                    register
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
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
                if (register) ...[
                  const Gap(),
                  TextFormField(
                    controller: confirmPassword,
                    obscureText: hide,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: null,
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                    ),
                    validator: (v) =>
                        v == password.text ? null : 'Passwords must match.',
                  ),
                ],
                if (!widget.api.demoMode)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Save email and password'),
                    subtitle: const Text(
                      'Suggest this account next time on this device.',
                    ),
                    value: savePassword,
                    onChanged: (value) =>
                        setState(() => savePassword = value ?? false),
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
                      await widget.api.login(
                        register ? email.text.trim() : username.text.trim(),
                        password.text,
                      );
                      if (!widget.api.demoMode) {
                        try {
                          final user = widget.api.user!;
                          if (savePassword) {
                            await widget.api.savedLogins.save(
                              SavedLogin(
                                email: user['email'],
                                username: user['username'],
                                password: password.text,
                                role: user['role'],
                                userId: user['id'],
                              ),
                            );
                          } else {
                            await widget.api.savedLogins.forget(user['id']);
                          }
                        } catch (_) {
                          if (context.mounted) {
                            showMessage(
                              context,
                              'Signed in, but this device could not save your password.',
                            );
                          }
                        }
                        TextInput.finishAutofillContext(
                          shouldSave: savePassword,
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
                const Gap(),
                if (!register)
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecoveryScreen(api: widget.api),
                      ),
                    ),
                    child: const Text('Forgot password?'),
                  ),
                TextButton(
                  onPressed: () {
                    TextInput.finishAutofillContext(shouldSave: false);
                    setState(() => register = !register);
                  },
                  child: Text(
                    register
                        ? 'Already have an account? Sign in'
                        : 'New here? Create an account',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;

class DemoAccountSwitch extends StatelessWidget {
  final Api api;
  const DemoAccountSwitch({super.key, required this.api});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.switch_account_outlined),
    title: const Text('Switch demo account'),
    subtitle: const Text(
      'Explore both sides of the project with sample accounts.',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () async {
      final role = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choose a demo account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: const Text('Customer'),
                subtitle: const Text('Find services, book and review work.'),
                trailing: api.user?['id'] == 1
                    ? const Icon(Icons.check, color: teal)
                    : null,
                onTap: () => Navigator.pop(context, 'customer'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Professional'),
                subtitle: const Text(
                  'Manage a business and respond to requests.',
                ),
                trailing: api.user?['id'] == 2
                    ? const Icon(Icons.check, color: teal)
                    : null,
                onTap: () => Navigator.pop(context, 'professional'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (role != null) await api.switchDemoRole(role);
    },
  );
}

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
          const Center(child: BrandIcon(size: 88)),
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
          if (api.demoMode) ...[const Gap(), DemoAccountSwitch(api: api)],
          if (api.startupError != null) ...[
            const Gap(),
            Text(api.startupError!),
            ActionButton(label: 'Retry saved session', action: api.initialize),
          ],
        ],
      );
    }
    return PageBody(
      width: 720,
      children: [
        const SectionTitle('Your account'),
        if (api.demoMode) ...[DemoAccountSwitch(api: api), const Gap()],
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
          leading: Icon(
            api.user!['email_verified'] == true
                ? Icons.verified_outlined
                : Icons.mark_email_unread_outlined,
          ),
          title: Text(
            api.user!['email_verified'] == true
                ? 'Email verified'
                : 'Verify your email',
          ),
          subtitle: const Text('Confirm ownership of your email address.'),
          onTap: api.user!['email_verified'] == true
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RecoveryScreen(api: api, verification: true),
                  ),
                ),
        ),
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
          title: Text(
            api.demoMode
                ? 'Try a demo notification'
                : 'Enable device notifications',
          ),
          subtitle: Text(
            api.demoMode
                ? 'Adds a sample update to your local Notifications.'
                : 'Get booking updates even when the app is closed.',
          ),
          onTap: () async {
            try {
              if (api.demoMode) {
                await api.post('demo/notification/', {});
                if (context.mounted) {
                  showMessage(
                    context,
                    'Demo update added. Open Notifications to view it.',
                  );
                }
                return;
              }
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
                  final updated = await widget.api.patch(
                    'me/',
                    fields.map((k, v) => MapEntry(k, v.text.trim())),
                  );
                  widget.api.updateUser(updated);
                  if (!widget.api.demoMode) {
                    try {
                      await widget.api.savedLogins.updateAccount(updated);
                    } catch (_) {
                      // Account changes succeeded even if device storage is unavailable.
                    }
                  }
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
