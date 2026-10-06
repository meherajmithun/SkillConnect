import 'package:flutter/material.dart';

import 'api.dart';

const ink = Color(0xFF122B45);
const blue = Color(0xFF2358D5);
const mist = Color(0xFFF1F5FB);
const teal = Color(0xFF0A786E);
const coral = Color(0xFFE97759);

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: blue,
    primary: blue,
    secondary: teal,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: mist,
  fontFamily: 'sans-serif',
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 38,
      fontWeight: FontWeight.w800,
      color: ink,
      height: 1.1,
      letterSpacing: -1.5,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: ink,
      letterSpacing: -.7,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: ink, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, color: ink, height: 1.4),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: mist,
    foregroundColor: ink,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD5DFEC)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD5DFEC)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(44, 48),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE0E7F0)),
    ),
  ),
);

IconData serviceIcon(String? name) => switch (name) {
  'plumbing' => Icons.plumbing_rounded,
  'bolt' => Icons.bolt_rounded,
  'carpenter' => Icons.carpenter_rounded,
  'format_paint' => Icons.format_paint_rounded,
  'cleaning_services' => Icons.cleaning_services_rounded,
  'build' => Icons.build_rounded,
  'ac_unit' => Icons.ac_unit_rounded,
  'computer' => Icons.computer_rounded,
  'code' => Icons.code_rounded,
  'phone_android' => Icons.phone_android_rounded,
  'palette' => Icons.palette_rounded,
  _ => Icons.handyman_rounded,
};

String money(dynamic value) =>
    'BDT ${num.tryParse('$value')?.toStringAsFixed(0) ?? value}';
String dateLabel(dynamic value) {
  final d = DateTime.tryParse('$value')?.toLocal();
  if (d == null) return '—';
  return '${d.day}/${d.month}/${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

void showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

class PageBody extends StatelessWidget {
  final List<Widget> children;
  final double width;
  const PageBody({super.key, required this.children, this.width = 1000});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    ),
  );
}

class Gap extends StatelessWidget {
  final double height;
  const Gap([this.height = 16, Key? key]) : super(key: key);
  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionTitle(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[
          const Gap(4),
          Text(subtitle!, style: const TextStyle(color: Color(0xFF61758C))),
        ],
      ],
    ),
  );
}

class Tag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Tag(this.text, {super.key, this.color = teal, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final IconData icon;
  const EmptyState(
    this.title,
    this.message, {
    super.key,
    this.icon = Icons.search_rounded,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Column(
        children: [
          Icon(icon, color: blue, size: 48),
          const Gap(),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const Gap(8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class LoadView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(T, VoidCallback) builder;
  const LoadView({super.key, required this.load, required this.builder});
  @override
  State<LoadView<T>> createState() => _LoadViewState<T>();
}

class _LoadViewState<T> extends State<LoadView<T>> {
  late Future<T> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  void reload() {
    if (mounted) setState(() => future = widget.load());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return PageBody(
          children: [
            EmptyState(
              'Could not load this page',
              '${snapshot.error}',
              icon: Icons.wifi_off_rounded,
            ),
            Center(
              child: FilledButton(
                onPressed: reload,
                child: const Text('Try again'),
              ),
            ),
          ],
        );
      }
      return widget.builder(snapshot.data as T, reload);
    },
  );
}

class ActionButton extends StatefulWidget {
  final String label;
  final Future<void> Function() action;
  final IconData? icon;
  const ActionButton({
    super.key,
    required this.label,
    required this.action,
    this.icon,
  });
  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy
        ? null
        : () async {
            setState(() => busy = true);
            try {
              await widget.action();
            } catch (e) {
              if (context.mounted) showMessage(context, '$e');
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
    icon: busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(widget.icon ?? Icons.arrow_forward_rounded, size: 18),
    label: Text(busy ? 'Please wait…' : widget.label),
  );
}

class ProfessionalCard extends StatelessWidget {
  final Json profile;
  final VoidCallback onTap;
  final Widget? trailing;
  const ProfessionalCard({
    super.key,
    required this.profile,
    required this.onTap,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    final categories = profile['categories'] as List;
    final name = '${profile['business_name']}';
    final rating = (profile['rating'] as num?)?.toStringAsFixed(1) ?? 'New';
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: blue.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      serviceIcon(
                        categories.isEmpty ? null : categories.first['icon'],
                      ),
                      color: blue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          categories.map((c) => c['name']).join(' · '),
                          style: const TextStyle(color: Color(0xFF61758C)),
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const Gap(14),
              Text(
                '${profile['bio']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Gap(14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Tag(
                    '$rating (${profile['review_count']})',
                    color: ink,
                    icon: Icons.star_rounded,
                  ),
                  if (profile['verified'] == true)
                    const Tag('Verified', icon: Icons.verified_rounded),
                  if (profile['promoted'] == true)
                    const Tag('Sponsored', color: blue),
                  Tag(
                    profile['available'] == true ? 'Available' : 'Unavailable',
                    color: profile['available'] == true ? teal : Colors.grey,
                  ),
                ],
              ),
              const Gap(14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile['distance_km'] != null
                          ? '${profile['distance_km']} km away'
                          : (profile['areas'] as List)
                                .map((a) => a['name'])
                                .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF61758C),
                      ),
                    ),
                  ),
                  Text(
                    'From ${money(profile['starting_price'])}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
