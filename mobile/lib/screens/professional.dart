import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../ui.dart';
import 'account.dart';
import 'discover.dart';

class BusinessScreen extends StatelessWidget {
  final Api api;
  const BusinessScreen({super.key, required this.api});
  @override
  Widget build(BuildContext context) => LoadView<List<dynamic>>(
    load: () => Future.wait([api.get('profile/'), api.get('analytics/')]),
    builder: (data, reload) {
      final p = data[0] as Json;
      return PageBody(
        width: 800,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: teal,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Tag('YOUR LOCAL BUSINESS', color: Color(0xFFB4DECE)),
                const Gap(),
                Text(
                  p['business_name'],
                  style: Theme.of(context).textTheme.headlineMedium!
                      .copyWith(color: Colors.white),
                ),
                const Gap(8),
                const Text(
                  'Make your skills easier to find.',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const Gap(20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Available for new requests'),
            subtitle: const Text('Pause requests when your schedule is full.'),
            value: p['available'] == true,
            onChanged: (value) async {
              try {
                await api.patch('profile/', {'available': value});
                reload();
              } catch (e) {
                if (context.mounted) showMessage(context, '$e');
              }
            },
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit business profile'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(api: api, profile: p),
                    ),
                  );
                  reload();
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('View public profile'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(api: api, id: p['id']),
                  ),
                ),
              ),
            ],
          ),
          if ((p['categories'] as List).isEmpty ||
              (p['areas'] as List).isEmpty) ...[
            const Gap(),
            const Tag(
              'Add your services and areas to start receiving requests.',
              color: blue,
            ),
          ],
          const Gap(24),
          const SectionTitle('Business at a glance'),
          StatsGrid(data: data[1]),
          const Gap(24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.campaign_outlined, color: blue, size: 32),
                  const Gap(12),
                  Text(
                    'Get seen in your service area.',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Gap(8),
                  const Text(
                    'Promote a specific service in a specific area. Packages start at BDT 100 for one day.',
                  ),
                  const Gap(),
                  FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PromotionScreen(api: api, profile: p),
                      ),
                    ),
                    child: const Text('Explore promotions'),
                  ),
                ],
              ),
            ),
          ),
          const Gap(20),
          Row(
            children: [
              const Expanded(child: SectionTitle('Your portfolio')),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add project'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPortfolioScreen(api: api),
                    ),
                  );
                  reload();
                },
              ),
            ],
          ),
          if ((p['portfolio'] as List).isEmpty)
            const EmptyState(
              'Show what you can do',
              'Add a completed project so customers can see your work.',
              icon: Icons.photo_library_outlined,
            ),
          for (final work in p['portfolio'])
            Card(
              child: ListTile(
                title: Text(work['title']),
                subtitle: Text(work['description']),
                leading: work['image'] == null || work['image'] == ''
                    ? const Icon(Icons.work_outline)
                    : Image.network(
                        work['image'],
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                trailing: IconButton(
                  tooltip: 'Delete project',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete this project?'),
                        content: Text(work['title']),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Keep project'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await api.delete('portfolio/${work['id']}/');
                        reload();
                      } catch (e) {
                        if (context.mounted) showMessage(context, '$e');
                      }
                    }
                  },
                ),
              ),
            ),
        ],
      );
    },
  );
}

class EditProfileScreen extends StatefulWidget {
  final Api api;
  final Json profile;
  const EditProfileScreen({
    super.key,
    required this.api,
    required this.profile,
  });
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  late final Set<int> categoryIds, areaIds;
  late Future<List<List<Json>>> catalogs;
  @override
  void initState() {
    super.initState();
    fields = {
      for (final key in [
        'business_name',
        'bio',
        'skills',
        'experience_years',
        'starting_price',
        'latitude',
        'longitude',
      ])
        key: TextEditingController(text: '${widget.profile[key] ?? ''}'),
    };
    categoryIds = (widget.profile['categories'] as List)
        .map((e) => e['id'] as int)
        .toSet();
    areaIds = (widget.profile['areas'] as List)
        .map((e) => e['id'] as int)
        .toSet();
    catalogs = Future.wait([
      widget.api.list('categories/'),
      widget.api.list('areas/'),
    ]);
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
    appBar: AppBar(title: const Text('Edit business profile')),
    body: FutureBuilder<List<List<Json>>>(
      future: catalogs,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return PageBody(
            children: [
              EmptyState('Could not load services', '${snapshot.error}'),
              FilledButton(
                onPressed: () => setState(
                  () => catalogs = Future.wait([
                    widget.api.list('categories/'),
                    widget.api.list('areas/'),
                  ]),
                ),
                child: const Text('Try again'),
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return PageBody(
          width: 640,
          children: [
            Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: fields['business_name'],
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Business name',
                    ),
                    validator: requiredText,
                  ),
                  const Gap(),
                  TextFormField(
                    controller: fields['bio'],
                    maxLength: 2000,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'About your business',
                    ),
                    validator: requiredText,
                  ),
                  const Gap(),
                  TextFormField(
                    controller: fields['skills'],
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Skills',
                      hintText:
                          'For example: wiring, lighting, switchboard repairs',
                    ),
                    validator: requiredText,
                  ),
                  const Gap(),
                  TextFormField(
                    controller: fields['experience_years'],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Years of experience',
                    ),
                    validator: (v) =>
                        int.tryParse(v ?? '') != null &&
                            int.parse(v!) >= 0 &&
                            int.parse(v) <= 80
                        ? null
                        : 'Enter years from 0 to 80.',
                  ),
                  const Gap(),
                  TextFormField(
                    controller: fields['starting_price'],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Starting price (BDT)',
                    ),
                    validator: (v) =>
                        num.tryParse(v ?? '') != null && num.parse(v!) >= 0
                        ? null
                        : 'Enter a valid price.',
                  ),
                  const SectionTitle('Services you offer'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in snapshot.data![0])
                        FilterChip(
                          avatar: Icon(serviceIcon(c['icon']), size: 16),
                          label: Text(c['name']),
                          selected: categoryIds.contains(c['id']),
                          onSelected: (v) => setState(() {
                            v
                                ? categoryIds.add(c['id'])
                                : categoryIds.remove(c['id']);
                          }),
                        ),
                    ],
                  ),
                  const SectionTitle('Areas you serve'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in snapshot.data![1])
                        FilterChip(
                          label: Text(a['name']),
                          selected: areaIds.contains(a['id']),
                          onSelected: (v) => setState(() {
                            v ? areaIds.add(a['id']) : areaIds.remove(a['id']);
                          }),
                        ),
                    ],
                  ),
                  const SectionTitle(
                    'Business location',
                    subtitle: 'Optional coordinates for map visibility and distance filters.',
                  ),
                  TextFormField(
                    controller: fields['latitude'],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    validator: (v) => coordinateValidator(v, 90),
                  ),
                  const Gap(),
                  TextFormField(
                    controller: fields['longitude'],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    validator: (v) => coordinateValidator(v, 180),
                  ),
                  const Gap(24),
                  ActionButton(
                    label: 'Save business profile',
                    action: () async {
                      if (!form.currentState!.validate()) return;
                      if (categoryIds.isEmpty || areaIds.isEmpty) {
                        showMessage(
                          context,
                          'Select at least one service and area.',
                        );
                        return;
                      }
                      if (fields['latitude']!.text.isEmpty !=
                          fields['longitude']!.text.isEmpty) {
                        showMessage(
                          context,
                          'Add both coordinates or leave both empty.',
                        );
                        return;
                      }
                      await widget.api.patch('profile/', {
                        'business_name': fields['business_name']!.text.trim(),
                        'bio': fields['bio']!.text.trim(),
                        'skills': fields['skills']!.text.trim(),
                        'experience_years': int.parse(
                          fields['experience_years']!.text,
                        ),
                        'starting_price': fields['starting_price']!.text.trim(),
                        'latitude': double.tryParse(fields['latitude']!.text),
                        'longitude': double.tryParse(fields['longitude']!.text),
                        'category_ids': categoryIds.toList(),
                        'area_ids': areaIds.toList(),
                      });
                      if (context.mounted) {
                        showMessage(context, 'Business profile saved.');
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
  String? coordinateValidator(String? value, double bound) {
    if (value == null || value.isEmpty) return null;
    final n = double.tryParse(value);
    return n == null || !n.isFinite || n < -bound || n > bound
        ? 'Enter a coordinate from -$bound to $bound.'
        : null;
  }
}

class AddPortfolioScreen extends StatefulWidget {
  final Api api;
  const AddPortfolioScreen({super.key, required this.api});
  @override
  State<AddPortfolioScreen> createState() => _AddPortfolioScreenState();
}

class _AddPortfolioScreenState extends State<AddPortfolioScreen> {
  final title = TextEditingController();
  final description = TextEditingController();
  final form = GlobalKey<FormState>();
  XFile? image;
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add portfolio project')),
    body: PageBody(
      width: 640,
      children: [
        const SectionTitle(
          'Let your work speak for itself',
          subtitle:
              'Add a project title, a short description and an optional photo.',
        ),
        Form(
          key: form,
          child: Column(
            children: [
              TextFormField(
                controller: title,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Project title'),
                validator: requiredText,
              ),
              const Gap(),
              TextFormField(
                controller: description,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Project description',
                ),
                validator: requiredText,
              ),
              const Gap(),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(image == null ? 'Choose a photo' : image!.name),
                onPressed: () async {
                  try {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1600,
                      imageQuality: 85,
                    );
                    if (picked != null &&
                        await picked.length() > 5 * 1024 * 1024) {
                      if (context.mounted) {
                        showMessage(context, 'Use an image smaller than 5 MB.');
                      }
                      return;
                    }
                    if (mounted) setState(() => image = picked);
                  } catch (e) {
                    if (context.mounted) {
                      showMessage(
                        context,
                        'Could not open the photo picker: $e',
                      );
                    }
                  }
                },
              ),
              if (image != null)
                TextButton(
                  onPressed: () => setState(() => image = null),
                  child: const Text('Remove photo'),
                ),
              const Gap(24),
              ActionButton(
                label: 'Add project',
                action: () async {
                  if (!form.currentState!.validate()) return;
                  await widget.api.uploadPortfolio(
                    {
                      'title': title.text.trim(),
                      'description': description.text.trim(),
                    },
                    bytes: await image?.readAsBytes(),
                    filename: image?.name,
                  );
                  if (context.mounted) {
                    showMessage(context, 'Project added.');
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

class PromotionScreen extends StatefulWidget {
  final Api api;
  final Json profile;
  const PromotionScreen({super.key, required this.api, required this.profile});
  @override
  State<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends State<PromotionScreen> {
  int? category, area, package;
  @override
  void initState() {
    super.initState();
    category = (widget.profile['categories'] as List).firstOrNull?['id'];
    area = (widget.profile['areas'] as List).firstOrNull?['id'];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Promote your business')),
    body: LoadView<List<dynamic>>(
      load: () => Future.wait([
        widget.api.list('packages/'),
        widget.api.list('promotions/'),
        widget.api.get('health/'),
      ]),
      builder: (data, reload) {
        final packages = (data[0] as List).cast<Json>();
        final demo = data[2]['demo_payments'] == true;
        if (category == null || area == null) {
          return PageBody(
            children: [
              const EmptyState(
                'Set up your service areas first',
                'Add services and areas in your business profile before purchasing a promotion.',
                icon: Icons.campaign_outlined,
              ),
            ],
          );
        }
        return PageBody(
          width: 800,
          children: [
            Text(
              'Be easier to find.\nRight where you work.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Gap(),
            const Text(
              'Choose a service, an area and how long to promote your profile. Sponsored results still consider customer ratings, distance and profile quality.',
            ),
            const Gap(24),
            DropdownButtonFormField<int>(
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'Service to promote',
              ),
              items: [
                for (final c in widget.profile['categories'])
                  DropdownMenuItem(
                    value: c['id'] as int,
                    child: Text(c['name']),
                  ),
              ],
              onChanged: (v) => setState(() => category = v),
            ),
            const Gap(),
            DropdownButtonFormField<int>(
              initialValue: area,
              decoration: const InputDecoration(labelText: 'Promotion area'),
              items: [
                for (final a in widget.profile['areas'])
                  DropdownMenuItem(
                    value: a['id'] as int,
                    child: Text(a['name']),
                  ),
              ],
              onChanged: (v) => setState(() => area = v),
            ),
            const SectionTitle('Choose your duration'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final p in packages)
                  SizedBox(
                    width: 175,
                    child: Card(
                      color: package == p['id']
                          ? const Color(0xFFE8F0FF)
                          : Colors.white,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setState(() => package = p['id']),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p['name'],
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  if (package == p['id'])
                                    const Icon(
                                      Icons.check_circle,
                                      color: blue,
                                      size: 18,
                                    ),
                                ],
                              ),
                              const Gap(),
                              Text(
                                money(p['price']),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Gap(8),
                              Text(
                                '${p['days']} ${p['days'] == 1 ? 'day' : 'days'}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const Gap(24),
            Text(
              demo
                  ? 'Demo checkout is enabled. No money is charged; the promotion activates immediately for testing.'
                  : 'Your purchase stays pending until payment is received and confirmed by the administrator. No card details are collected in this app.',
            ),
            const Gap(),
            ActionButton(
              label: demo
                  ? 'Activate demo promotion'
                  : 'Request promotion purchase',
              icon: Icons.campaign_outlined,
              action: () async {
                final selected = packages
                    .where((p) => p['id'] == package)
                    .firstOrNull;
                if (selected == null) {
                  showMessage(context, 'Choose a promotion package.');
                  return;
                }
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm promotion'),
                    content: Text(
                      '${selected['name']} · ${selected['days']} days · ${money(selected['price'])}\n${demo ? 'Demo purchase — no charge.' : 'Activation begins after payment confirmation.'}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Go back'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                await widget.api.post('promotions/', {
                  'package': package,
                  'category': category,
                  'area': area,
                });
                reload();
                if (context.mounted) {
                  showMessage(
                    context,
                    demo
                        ? 'Demo promotion activated.'
                        : 'Purchase requested. Awaiting payment confirmation.',
                  );
                }
              },
            ),
            const Gap(24),
            const SectionTitle('Your promotions'),
            if ((data[1] as List).isEmpty)
              const Text('You haven’t purchased a promotion yet.'),
            for (final p in data[1])
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
                              '${p['package_name']} · ${p['category_name']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Tag(
                            p['active'] == true
                                ? 'Active'
                                : p['status'] == 'paid'
                                ? 'Expired'
                                : p['status'],
                          ),
                        ],
                      ),
                      const Gap(8),
                      Text('${p['area_name']} · ${money(p['price_paid'])}'),
                      if (p['expires_at'] != null)
                        Text('Expires ${dateLabel(p['expires_at'])}'),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
