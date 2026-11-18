import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';
import 'account.dart';

const _night = Color(0xFF071824);
const _ice = Color(0xFFF4F8FF);
const _aqua = Color(0xFF43D3C6);

class WelcomeScreen extends StatefulWidget {
  final Api api;
  const WelcomeScreen({super.key, required this.api});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool choosingRole = false;

  void showRoles() => setState(() => choosingRole = true);

  Future<void> openAuth(String role) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          AuthScreen(api: widget.api, initialRole: role, roleLocked: true),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _night,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _ConnectionBackdropPainter()),
        SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(.04, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: choosingRole
                ? _RoleChoice(
                    key: const ValueKey('roles'),
                    onBack: () => setState(() => choosingRole = false),
                    onCustomer: () => openAuth('customer'),
                    onProfessional: () => openAuth('professional'),
                  )
                : _Cover(key: const ValueKey('cover'), onContinue: showRoles),
          ),
        ),
      ],
    ),
  );
}

class _Cover extends StatelessWidget {
  final VoidCallback onContinue;
  const _Cover({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 52),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BrandHeader(),
                const SizedBox(height: 64),
                const _ConnectionMark(),
                const SizedBox(height: 42),
                const Text(
                  'LOCAL SKILLS. REAL PEOPLE.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _aqua,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'The right help,\nright around you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    height: 1.04,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.8,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Find trusted local professionals—or turn your own skills into a growing business.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFC9D8E7),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 42),
                FilledButton.icon(
                  onPressed: onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: _ice,
                    foregroundColor: _night,
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text(
                    'Get started',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Customer and professional accounts are kept separate.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8EA5B9), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _RoleChoice extends StatelessWidget {
  final VoidCallback onBack, onCustomer, onProfessional;
  const _RoleChoice({
    super.key,
    required this.onBack,
    required this.onCustomer,
    required this.onProfessional,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 44),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton.filledTonal(
                    tooltip: 'Back to cover',
                    onPressed: onBack,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .08),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Choose your side\nof the connection.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.4,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'This keeps your tools and account experience focused on what you came to do.',
                  style: TextStyle(
                    color: Color(0xFFC9D8E7),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 34),
                _RoleCard(
                  eyebrow: 'CUSTOMER',
                  title: 'I need a service',
                  description: 'Find professionals, request quotes and keep every booking in one place.',
                  icon: Icons.travel_explore_rounded,
                  accent: const Color(0xFF8FB0FF),
                  onTap: onCustomer,
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  eyebrow: 'PROFESSIONAL',
                  title: 'I offer services',
                  description: 'Publish your skills, respond to customers and manage your local business.',
                  icon: Icons.handyman_rounded,
                  accent: _aqua,
                  onTap: onProfessional,
                ),
                const SizedBox(height: 30),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF8EA5B9),
                      size: 15,
                    ),
                    SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'Your account role cannot be changed after registration.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8EA5B9),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 42,
        height: 42,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: _ice,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const BrandIcon(size: 32),
      ),
      const SizedBox(width: 11),
      const Text(
        'SkillConnect',
        style: TextStyle(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -.7,
        ),
      ),
    ],
  );
}

class _ConnectionMark extends StatelessWidget {
  const _ConnectionMark();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: _MiniRole(icon: Icons.person_search_rounded, label: 'Find help'),
      ),
      Container(width: 28, height: 2, color: Colors.white24),
      Container(
        width: 82,
        height: 82,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: _ice,
          shape: BoxShape.circle,
          border: Border.all(color: _aqua.withValues(alpha: .75), width: 2),
          boxShadow: [
            BoxShadow(
              color: _aqua.withValues(alpha: .18),
              blurRadius: 28,
              spreadRadius: 8,
            ),
          ],
        ),
        child: const BrandIcon(size: 64),
      ),
      Container(width: 28, height: 2, color: Colors.white24),
      const Expanded(
        child: _MiniRole(icon: Icons.handyman_rounded, label: 'Offer skills'),
      ),
    ],
  );
}

class _MiniRole extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniRole({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: const Color(0xFFC9D8E7)),
      ),
      const SizedBox(height: 8),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFAFC1D2),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _RoleCard extends StatelessWidget {
  final String eyebrow, title, description;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  const _RoleCard({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .07),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: accent.withValues(alpha: .38)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: accent, size: 29),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: TextStyle(
                      color: accent,
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFFB9CAD9),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_rounded, color: accent),
          ],
        ),
      ),
    ),
  );
}

class _ConnectionBackdropPainter extends CustomPainter {
  const _ConnectionBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader =
          const RadialGradient(colors: [Color(0x443A72E8), Color(0x00071824)])
              .createShader(
                Rect.fromCircle(
                  center: Offset(size.width * .78, size.height * .18),
                  radius: size.shortestSide * .72,
                ),
              );
    canvas.drawRect(Offset.zero & size, glow);

    final path = Path()
      ..moveTo(-30, size.height * .72)
      ..cubicTo(
        size.width * .2,
        size.height * .58,
        size.width * .52,
        size.height * .96,
        size.width + 30,
        size.height * .72,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = _aqua.withValues(alpha: .08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (final point in [
      Offset(size.width * .08, size.height * .68),
      Offset(size.width * .88, size.height * .75),
    ]) {
      canvas.drawCircle(point, 5, Paint()..color = _aqua.withValues(alpha: .3));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
