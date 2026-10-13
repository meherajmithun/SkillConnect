import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';

class RecoveryScreen extends StatefulWidget {
  final Api api;
  final bool verification;
  const RecoveryScreen({
    super.key,
    required this.api,
    this.verification = false,
  });
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final form = GlobalKey<FormState>();
  late final email = TextEditingController(
    text: widget.verification ? '${widget.api.user?['email'] ?? ''}' : '',
  );
  final code = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool sent = false;

  @override
  void dispose() {
    for (final c in [email, code, password, confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> send() async {
    if (!sent && !form.currentState!.validate()) return;
    final result = await widget.api.post(
      widget.verification ? 'auth/email-verification/' : 'auth/password-reset/',
      widget.verification ? {} : {'email': email.text.trim()},
    );
    if (!mounted) return;
    setState(() => sent = true);
    showMessage(context, result['detail']);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.verification ? 'Verify email' : 'Reset password'),
    ),
    body: PageBody(
      width: 520,
      children: [
        SectionTitle(
          sent
              ? 'Check your email'
              : widget.verification
              ? 'Confirm your email address'
              : 'Recover your account',
          subtitle: widget.api.demoMode
              ? sent
                    ? 'Demo code: 12345678. No email is sent.'
                    : 'Simulate email verification with a local demo code.'
              : sent
              ? 'Enter the eight-digit code within 15 minutes.'
              : 'We’ll send a code to your email address.',
        ),
        Form(
          key: form,
          child: Column(
            children: [
              TextFormField(
                controller: email,
                readOnly: sent || widget.verification,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email address'),
                validator: (v) =>
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v ?? '')
                    ? null
                    : 'Enter a valid email address.',
              ),
              if (sent) ...[
                const Gap(),
                TextFormField(
                  controller: code,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 8,
                  decoration: const InputDecoration(labelText: 'Email code'),
                  validator: (v) => RegExp(r'^\d{8}$').hasMatch(v ?? '')
                      ? null
                      : 'Enter the eight-digit code.',
                ),
                if (!widget.verification) ...[
                  const Gap(),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'New password',
                    ),
                    validator: (v) => (v ?? '').length >= 8
                        ? null
                        : 'Use at least 8 characters.',
                  ),
                  const Gap(),
                  TextFormField(
                    controller: confirm,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                    ),
                    validator: (v) =>
                        v == password.text ? null : 'Passwords must match.',
                  ),
                ],
              ],
              const Gap(24),
              ActionButton(
                label: !sent
                    ? 'Send email code'
                    : widget.verification
                    ? 'Verify email'
                    : 'Update password',
                action: () async {
                  if (!form.currentState!.validate()) return;
                  if (!sent) return send();
                  final result = await widget.api.post(
                    widget.verification
                        ? 'auth/email-verification/confirm/'
                        : 'auth/password-reset/confirm/',
                    {
                      'code': code.text.trim(),
                      if (!widget.verification) ...{
                        'email': email.text.trim(),
                        'new_password': password.text,
                      },
                    },
                  );
                  if (widget.verification) {
                    widget.api.updateUser(await widget.api.get('me/'));
                  } else if (!widget.api.demoMode) {
                    await widget.api.savedLogins.forgetEmail(email.text);
                    if ('${widget.api.user?['email']}'.toLowerCase() ==
                        email.text.trim().toLowerCase()) {
                      await widget.api.clearSession();
                    }
                  }
                  if (context.mounted) {
                    showMessage(context, result['detail']);
                    Navigator.pop(context);
                  }
                },
              ),
              if (sent) ...[
                const Gap(),
                ActionButton(label: 'Resend code', action: send),
                if (!widget.verification)
                  TextButton(
                    onPressed: () => setState(() {
                      sent = false;
                      code.clear();
                    }),
                    child: const Text('Use a different email'),
                  ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
