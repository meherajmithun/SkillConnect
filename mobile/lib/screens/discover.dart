import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ui.dart';
import 'account.dart';
import 'activity.dart';

class DiscoverScreen extends StatefulWidget {
  final Api api;
  const DiscoverScreen({super.key, required this.api});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late Future<List<List<Json>>> catalogs;
  Future<Json>? results;
  final search = TextEditingController();
  int? category, area;
  String sort = 'recommended';
  double rating = 0;
  double? distance;
  bool available = false;
  bool map = false;
  List<Json> areas = [];
  final Map<int, Json> compare = {};
  int page = 1;
  @override
  void initState() {
    super.initState();
    catalogs = Future.wait([
      widget.api.list('categories/'),
      widget.api.list('areas/'),
    ]);
    find();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void find({int newPage = 1}) {
    page = newPage;
    final selectedArea = areas.where((a) => a['id'] == area).firstOrNull;
    results = widget.api
        .get(
          'professionals/',
          query: {
            'page': page,
            'sort': sort,
            'min_rating': rating,
            if (category != null) 'category': category,
            if (area != null) 'area': area,
            if (available) 'available': true,
            if (search.text.trim().isNotEmpty) 'q': search.text.trim(),
            if (selectedArea != null) ...{
              'lat': selectedArea['latitude'],
              'lng': selectedArea['longitude'],
            },
            if (distance != null && selectedArea != null)
              'max_distance': distance,
          },
        )
        .then((value) => Map<String, dynamic>.from(value));
    // The catalog may still be loading when this request fails.
    results!.ignore();
  }

  void refresh() => setState(() => find());
  void reconnect() => setState(() {
    catalogs = Future.wait([
      widget.api.list('categories/'),
      widget.api.list('areas/'),
    ]);
    find();
  });
  void open(Json pro) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProfileScreen(api: widget.api, id: pro['id']),
    ),
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<List<List<Json>>>(
    future: catalogs,
    builder: (context, snapshot) {
      final connected = snapshot.hasData && !snapshot.hasError;
      final categories = snapshot.data?[0] ?? <Json>[];
      areas = snapshot.data?[1] ?? <Json>[];
      return PageBody(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(24),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Tag(
                          'LOCAL PEOPLE. SKILLED HANDS.',
                          color: Color(0xFF92D9F7),
                        ),
                        const Gap(18),
                        Text(
                          'A little help.\nRight around here.',
                          style: Theme.of(context).textTheme.headlineLarge!
                              .copyWith(
                                color: Colors.white,
                                fontSize: constraints.maxWidth < 450 ? 32 : 44,
                              ),
                        ),
                        const Gap(14),
                        const Text(
                          'From a leaking tap to your next website.\nFind the person who knows how.',
                          style: TextStyle(
                            color: Color(0xFFC9D9EB),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (constraints.maxWidth > 600)
                    SizedBox(
                      width: 250,
                      child: Column(
                        children: [
                          _ConnectionTile(
                            icon: Icons.bolt_rounded,
                            label: 'Fix it',
                            color: const Color(0xFFF5C36B),
                          ),
                          const Icon(Icons.more_vert, color: Color(0xFF6885A5)),
                          _ConnectionTile(
                            icon: Icons.handshake_outlined,
                            label: 'Connect locally',
                            color: const Color(0xFF92D9F7),
                          ),
                          const Icon(Icons.more_vert, color: Color(0xFF6885A5)),
                          _ConnectionTile(
                            icon: Icons.code_rounded,
                            label: 'Build it',
                            color: const Color(0xFFB4DECE),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!connected) ...[
            const Gap(16),
            if (snapshot.hasError)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Could not connect',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Gap(8),
                      const Text(
                        'You can view the app layout. Connect to a server to load services, areas and professionals.',
                      ),
                      const Gap(8),
                      TextButton.icon(
                        onPressed: reconnect,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                      if (Api.demoAvailable)
                        TextButton.icon(
                          onPressed: widget.api.startDemo,
                          icon: const Icon(Icons.touch_app_outlined),
                          label: const Text('Explore offline demo'),
                        ),
                    ],
                  ),
                ),
              )
            else ...[
              const LinearProgressIndicator(),
              const Gap(8),
              const Text('Connecting to load services and professionals…'),
            ],
          ],
          const Gap(24),
          const SectionTitle(
            'What do you need a hand with?',
            subtitle:
                'Choose a skill and your area to find a local professional.',
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All services'),
                  selected: category == null,
                  onSelected: !connected
                      ? null
                      : (_) {
                          category = null;
                          refresh();
                        },
                ),
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      avatar: Icon(serviceIcon(c['icon']), size: 18),
                      label: Text(c['name']),
                      selected: category == c['id'],
                      onSelected: (_) {
                        category = category == c['id'] ? null : c['id'];
                        refresh();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const Gap(20),
          LayoutBuilder(
            builder: (context, c) {
              final fields = [
                TextField(
                  controller: search,
                  enabled: connected,
                  decoration: const InputDecoration(
                    labelText: 'Search a name or skill',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => refresh(),
                ),
                DropdownButtonFormField<int>(
                  initialValue: areas.any((a) => a['id'] == area) ? area : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Your area',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('All areas'),
                    ),
                    for (final a in areas)
                      DropdownMenuItem(
                        value: a['id'] as int,
                        child: Text(a['name']),
                      ),
                  ],
                  onChanged: !connected
                      ? null
                      : (v) {
                          area = v;
                          if (v == null) distance = null;
                          refresh();
                        },
                ),
              ];
              if (c.maxWidth < 600) {
                return Column(children: [fields[0], const Gap(), fields[1]]);
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: fields[0]),
                  const SizedBox(width: 16),
                  Expanded(child: fields[1]),
                ],
              );
            },
          ),
          const Gap(12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 175,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: sort,
                  decoration: const InputDecoration(labelText: 'Sort by'),
                  items: const [
                    DropdownMenuItem(
                      value: 'recommended',
                      child: Text('Recommended'),
                    ),
                    DropdownMenuItem(
                      value: 'rating',
                      child: Text('Highest rated'),
                    ),
                    DropdownMenuItem(value: 'distance', child: Text('Nearest')),
                  ],
                  onChanged: !connected
                      ? null
                      : (v) {
                          sort = v!;
                          refresh();
                        },
                ),
              ),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<double>(
                  isExpanded: true,
                  initialValue: rating,
                  decoration: const InputDecoration(labelText: 'Rating'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Any rating')),
                    DropdownMenuItem(value: 4, child: Text('4+ stars')),
                    DropdownMenuItem(value: 4.5, child: Text('4.5+ stars')),
                  ],
                  onChanged: !connected
                      ? null
                      : (v) {
                          rating = v!;
                          refresh();
                        },
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<double>(
                  isExpanded: true,
                  key: ValueKey(distance),
                  initialValue: distance,
                  decoration: const InputDecoration(labelText: 'Distance'),
                  items: const [
                    DropdownMenuItem<double>(
                      value: null,
                      child: Text('Any distance'),
                    ),
                    DropdownMenuItem(value: 5, child: Text('Within 5 km')),
                    DropdownMenuItem(value: 10, child: Text('Within 10 km')),
                    DropdownMenuItem(value: 20, child: Text('Within 20 km')),
                  ],
                  onChanged: !connected || area == null
                      ? null
                      : (v) {
                          distance = v;
                          refresh();
                        },
                ),
              ),
              FilterChip(
                label: const Text('Available now'),
                selected: available,
                onSelected: !connected
                    ? null
                    : (v) {
                        available = v;
                        refresh();
                      },
              ),
              IconButton(
                tooltip: map ? 'Show list' : 'Show map',
                onPressed: !connected ? null : () => setState(() => map = !map),
                icon: Icon(map ? Icons.view_list_outlined : Icons.map_outlined),
              ),
              FilledButton.icon(
                onPressed: connected ? refresh : null,
                icon: const Icon(Icons.search),
                label: const Text('Find professionals'),
              ),
            ],
          ),
          if (area != null)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Distances are measured from the selected area’s center.',
                style: TextStyle(fontSize: 12, color: Color(0xFF61758C)),
              ),
            ),
          if (compare.isNotEmpty) ...[
            const Gap(),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: blue.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${compare.length} of 3 profiles selected'),
                  ),
                  TextButton(
                    onPressed: () => setState(compare.clear),
                    child: const Text('Clear'),
                  ),
                  FilledButton(
                    onPressed: compare.length < 2
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CompareScreen(
                                profiles: compare.values.toList(),
                                api: widget.api,
                              ),
                            ),
                          ),
                    child: const Text('Compare'),
                  ),
                ],
              ),
            ),
          ],
          const Gap(24),
          if (connected)
            FutureBuilder<Json>(
              future: results,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      EmptyState(
                        'Search could not finish',
                        '${snapshot.error}',
                      ),
                      TextButton(
                        onPressed: refresh,
                        child: const Text('Try again'),
                      ),
                    ],
                  );
                }
                final rows = (snapshot.data!['results'] as List).cast<Json>();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      '${snapshot.data!['count']} professionals',
                      subtitle: 'Compare their work, experience and customer reviews.',
                    ),
                    if (rows.isEmpty)
                      const EmptyState(
                        'No matches yet',
                        'Try another service or area, or broaden your filters.',
                      ),
                    if (map && rows.isNotEmpty) ...[
                      SizedBox(
                        height: 360,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: ProfessionalMap(
                            profiles: rows,
                            onTap: open,
                            offline: widget.api.demoMode,
                          ),
                        ),
                      ),
                      const Gap(),
                    ],
                    LayoutBuilder(
                      builder: (context, c) => Wrap(
                        spacing: 16,
                        children: [
                          for (final pro in rows)
                            SizedBox(
                              width: c.maxWidth > 700
                                  ? (c.maxWidth - 16) / 2
                                  : c.maxWidth,
                              child: ProfessionalCard(
                                profile: pro,
                                onTap: () => open(pro),
                                trailing: Checkbox(
                                  value: compare.containsKey(pro['id']),
                                  semanticLabel:
                                      'Compare ${pro['business_name']}',
                                  onChanged: (v) => setState(() {
                                    if (v == false) {
                                      compare.remove(pro['id']);
                                    } else if (compare.length < 3) {
                                      compare[pro['id']] = pro;
                                    } else {
                                      showMessage(
                                        context,
                                        'Compare up to three professionals at a time.',
                                      );
                                    }
                                  }),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (snapshot.data!['previous'] != null ||
                        snapshot.data!['next'] != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: snapshot.data!['previous'] == null
                                ? null
                                : () => setState(() => find(newPage: page - 1)),
                            child: const Text('Previous'),
                          ),
                          Text('Page $page'),
                          TextButton(
                            onPressed: snapshot.data!['next'] == null
                                ? null
                                : () => setState(() => find(newPage: page + 1)),
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
        ],
      );
    },
  );
}

class _ConnectionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ConnectionTile({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: .25)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class ProfessionalMap extends StatelessWidget {
  final List<Json> profiles;
  final void Function(Json) onTap;
  final bool offline;
  const ProfessionalMap({
    super.key,
    required this.profiles,
    required this.onTap,
    this.offline = false,
  });
  @override
  Widget build(BuildContext context) {
    final located = profiles
        .where((p) => p['latitude'] != null && p['longitude'] != null)
        .toList();
    if (located.isEmpty) {
      return const EmptyState(
        'No locations to display',
        'These professionals have not added a map location.',
      );
    }
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(
          (located.first['latitude'] as num).toDouble(),
          (located.first['longitude'] as num).toDouble(),
        ),
        initialZoom: 12,
      ),
      children: [
        if (offline)
          GridPaper(
            color: blue.withValues(alpha: .12),
            interval: 80,
            divisions: 1,
            subdivisions: 1,
            child: const ColoredBox(color: mist, child: SizedBox.expand()),
          ),
        if (!offline)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.skillconnect.mobile',
          ),
        MarkerLayer(
          markers: [
            for (final p in located)
              Marker(
                point: LatLng(
                  (p['latitude'] as num).toDouble(),
                  (p['longitude'] as num).toDouble(),
                ),
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: p['business_name'],
                  onPressed: () => onTap(p),
                  icon: const Icon(Icons.location_on, color: blue, size: 40),
                ),
              ),
          ],
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              offline
                  ? 'Demo locations (offline)'
                  : 'OpenStreetMap contributors',
              onTap: offline
                  ? null
                  : () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final Api api;
  final int id;
  const ProfileScreen({super.key, required this.api, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Professional profile')),
    body: LoadView<List<dynamic>>(
      load: () => Future.wait([
        api.get('professionals/$id/'),
        api.list('professionals/$id/reviews/'),
      ]),
      builder: (data, reload) {
        final p = data[0] as Json;
        final categories = p['categories'] as List;
        return PageBody(
          width: 800,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    serviceIcon(
                      categories.isEmpty ? null : categories.first['icon'],
                    ),
                    size: 42,
                    color: const Color(0xFF92D9F7),
                  ),
                  const Gap(),
                  Text(
                    p['business_name'],
                    style: Theme.of(context).textTheme.headlineMedium!
                        .copyWith(color: Colors.white),
                  ),
                  const Gap(8),
                  Text(
                    '${p['name']} · ${p['experience_years']} years of experience',
                    style: const TextStyle(color: Color(0xFFC9D9EB)),
                  ),
                  const Gap(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (p['verified'] == true)
                        const Tag(
                          'Verified professional',
                          color: Color(0xFFB4DECE),
                          icon: Icons.verified,
                        ),
                      Tag(
                        p['available'] == true
                            ? 'Available for requests'
                            : 'Currently unavailable',
                        color: const Color(0xFF92D9F7),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: p['available'] == true
                      ? () async {
                          if (await requireLogin(context, api) &&
                              context.mounted) {
                            if (api.isProfessional) {
                              showMessage(
                                context,
                                'Use a customer account to book a service.',
                              );
                              return;
                            }
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServiceRequestScreen(
                                  api: api,
                                  profile: p,
                                  isQuote: false,
                                ),
                              ),
                            );
                            reload();
                          }
                        }
                      : null,
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Book service'),
                ),
                OutlinedButton.icon(
                  onPressed: p['available'] == true
                      ? () async {
                          if (await requireLogin(context, api) &&
                              context.mounted) {
                            if (api.isProfessional) {
                              showMessage(
                                context,
                                'Use a customer account to request a quote.',
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServiceRequestScreen(
                                  api: api,
                                  profile: p,
                                  isQuote: true,
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.request_quote_outlined),
                  label: const Text('Request quote'),
                ),
                OutlinedButton.icon(
                  onPressed: '${p['phone']}'.isEmpty
                      ? null
                      : () async {
                          if (api.demoMode) {
                            showMessage(
                              context,
                              'Demo contact for ${p['business_name']}. No phone call is placed.',
                            );
                            return;
                          }
                          final phone = Uri(scheme: 'tel', path: p['phone']);
                          if (!await launchUrl(phone) && context.mounted) {
                            showMessage(context, 'Call ${p['phone']}');
                          }
                        },
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call'),
                ),
              ],
            ),
            const Gap(24),
            const SectionTitle('About this business'),
            Text(p['bio']),
            const Gap(),
            Text(
              'Starting at ${money(p['starting_price'])}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'The final price depends on the work. Request a quote for an estimate.',
            ),
            const SectionTitle('Skills & service areas'),
            Text('${p['skills']}'),
            const Gap(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in p['areas'])
                  Tag(a['name'], color: blue, icon: Icons.location_on_outlined),
              ],
            ),
            const SectionTitle('Previous work'),
            if ((p['portfolio'] as List).isEmpty)
              const Text(
                'This professional has not added portfolio projects yet.',
              ),
            for (final work in p['portfolio'])
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (work['image'] != null && work['image'] != '') ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: PortfolioImage(
                            work['image'],
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                              height: 100,
                              child: Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                        const Gap(),
                      ],
                      Text(
                        work['title'],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Gap(6),
                      Text(work['description']),
                    ],
                  ),
                ),
              ),
            if (p['latitude'] != null && p['longitude'] != null) ...[
              const SectionTitle('Business location'),
              SizedBox(
                height: 250,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ProfessionalMap(
                    profiles: [p],
                    onTap: (_) {},
                    offline: api.demoMode,
                  ),
                ),
              ),
            ],
            SectionTitle(
              'Customer reviews',
              subtitle:
                  '${(p['rating'] as num?)?.toStringAsFixed(1) ?? 'No rating yet'} · ${p['review_count']} reviews',
            ),
            if ((data[1] as List).isEmpty)
              const Text('No customer reviews yet.'),
            for (final r in data[1])
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r['customer_name'],
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Tag('${r['rating']}/5', icon: Icons.star, color: ink),
                        ],
                      ),
                      const Gap(10),
                      Text(r['comment']),
                    ],
                  ),
                ),
              ),
            const Gap(20),
            TextButton.icon(
              onPressed: () async {
                if (await requireLogin(context, api) && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportScreen(api: api, profile: p),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Report this professional'),
            ),
          ],
        );
      },
    ),
  );
}

class CompareScreen extends StatelessWidget {
  final List<Json> profiles;
  final Api api;
  const CompareScreen({super.key, required this.profiles, required this.api});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Compare professionals')),
    body: PageBody(
      children: [
        const SectionTitle('Choose who fits your job'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Details')),
              for (final p in profiles)
                DataColumn(
                  label: SizedBox(
                    width: 180,
                    child: Text(p['business_name'], maxLines: 2),
                  ),
                ),
            ],
            rows: [
              for (final field in [
                'Service',
                'Starting price',
                'Experience',
                'Rating',
                'Distance',
                'Verified',
                'Available',
                'Areas',
              ])
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        field,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    for (final p in profiles)
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Text(switch (field) {
                            'Service' =>
                              (p['categories'] as List)
                                  .map((c) => c['name'])
                                  .join(', '),
                            'Starting price' => money(p['starting_price']),
                            'Experience' => '${p['experience_years']} years',
                            'Rating' =>
                              '${(p['rating'] as num?)?.toStringAsFixed(1) ?? 'New'} (${p['review_count']} reviews)',
                            'Distance' =>
                              p['distance_km'] == null
                                  ? 'Not available'
                                  : '${p['distance_km']} km',
                            'Verified' =>
                              p['verified'] == true ? 'Yes' : 'Not yet',
                            'Available' =>
                              p['available'] == true ? 'Yes' : 'No',
                            _ =>
                              (p['areas'] as List)
                                  .map((a) => a['name'])
                                  .join(', '),
                          }),
                        ),
                      ),
                  ],
                ),
              DataRow(
                cells: [
                  const DataCell(Text('View work')),
                  for (final p in profiles)
                    DataCell(
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProfileScreen(api: api, id: p['id']),
                          ),
                        ),
                        child: const Text('Open profile'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ReportScreen extends StatefulWidget {
  final Api api;
  final Json profile;
  const ReportScreen({super.key, required this.api, required this.profile});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final reason = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Report a concern')),
    body: PageBody(
      width: 600,
      children: [
        SectionTitle(
          widget.profile['business_name'],
          subtitle: 'Explain the concern so our team can investigate.',
        ),
        Form(
          key: form,
          child: TextFormField(
            controller: reason,
            maxLines: 5,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'What happened?'),
            validator: requiredText,
          ),
        ),
        const Gap(),
        ActionButton(
          label: 'Send report',
          icon: Icons.flag_outlined,
          action: () async {
            if (!form.currentState!.validate()) return;
            await widget.api.post('reports/', {
              'professional': widget.profile['id'],
              'reason': reason.text.trim(),
            });
            if (context.mounted) {
              showMessage(context, 'Report sent for review.');
              Navigator.pop(context);
            }
          },
        ),
      ],
    ),
  );
}
