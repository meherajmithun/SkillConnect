import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';
import 'account.dart';

class ServiceRequestScreen extends StatefulWidget {
  final Api api;
  final Json profile;
  final bool isQuote;
  const ServiceRequestScreen({
    super.key,
    required this.api,
    required this.profile,
    required this.isQuote,
  });
  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final form = GlobalKey<FormState>();
  final address = TextEditingController();
  final details = TextEditingController();
  late int? category, area;
  DateTime? scheduled;
  @override
  void initState() {
    super.initState();
    category = (widget.profile['categories'] as List).firstOrNull?['id'];
    area = (widget.profile['areas'] as List).firstOrNull?['id'];
  }

  @override
  void dispose() {
    address.dispose();
    details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.isQuote ? 'Request a quote' : 'Book a service'),
    ),
    body: PageBody(
      width: 600,
      children: [
        SectionTitle(
          widget.profile['business_name'],
          subtitle: widget.isQuote
              ? 'Describe the work to get an estimate.'
              : 'Your booking is confirmed after the professional accepts it.',
        ),
        Form(
          key: form,
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Service'),
                items: [
                  for (final c in widget.profile['categories'])
                    DropdownMenuItem(
                      value: c['id'] as int,
                      child: Text(c['name']),
                    ),
                ],
                onChanged: (v) => category = v,
                validator: (v) => v == null ? 'Choose a service.' : null,
              ),
              const Gap(),
              DropdownButtonFormField<int>(
                initialValue: area,
                decoration: const InputDecoration(labelText: 'Service area'),
                items: [
                  for (final a in widget.profile['areas'])
                    DropdownMenuItem(
                      value: a['id'] as int,
                      child: Text(a['name']),
                    ),
                ],
                onChanged: (v) => area = v,
                validator: (v) => v == null ? 'Choose an area.' : null,
              ),
              const Gap(),
              if (!widget.isQuote) ...[
                TextFormField(
                  controller: address,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Service address',
                  ),
                  validator: requiredText,
                ),
                const Gap(),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      scheduled == null
                          ? 'Choose date & time'
                          : dateLabel(scheduled!.toIso8601String()),
                    ),
                    onPressed: () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: context,
                        initialDate: now.add(const Duration(days: 1)),
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (date == null || !context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 10, minute: 0),
                      );
                      if (time != null) {
                        setState(
                          () => scheduled = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          ),
                        );
                      }
                    },
                  ),
                ),
                const Gap(),
              ],
              TextFormField(
                controller: details,
                maxLines: 5,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Describe the work',
                  hintText: 'What needs doing? Include anything the professional should know.',
                ),
                validator: requiredText,
              ),
              const Gap(24),
              ActionButton(
                label: widget.isQuote
                    ? 'Send quote request'
                    : 'Send booking request',
                action: () async {
                  if (!form.currentState!.validate()) return;
                  if (!widget.isQuote &&
                      (scheduled == null ||
                          scheduled!.isBefore(DateTime.now()))) {
                    showMessage(context, 'Choose a future date and time.');
                    return;
                  }
                  await widget.api.post(
                    widget.isQuote ? 'quotes/' : 'bookings/',
                    {
                      'professional': widget.profile['id'],
                      'category': category,
                      'area': area,
                      'details': details.text.trim(),
                      if (!widget.isQuote) ...{
                        'address': address.text.trim(),
                        'scheduled_at': scheduled!.toUtc().toIso8601String(),
                      },
                    },
                  );
                  if (context.mounted) {
                    showMessage(
                      context,
                      widget.isQuote
                          ? 'Quote request sent. Track it in Activity.'
                          : 'Booking request sent. Track it in Activity.',
                    );
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

class ActivityScreen extends StatefulWidget {
  final Api api;
  const ActivityScreen({super.key, required this.api});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    if (!api.signedIn) {
      return PageBody(
        children: [
          const EmptyState(
            'Keep your requests in one place',
            'Sign in to track bookings and quotations.',
            icon: Icons.event_note_outlined,
          ),
          Center(
            child: FilledButton(
              onPressed: () => requireLogin(context, api),
              child: const Text('Sign in'),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Bookings'),
                icon: Icon(Icons.event_note_outlined),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Quotes'),
                icon: Icon(Icons.request_quote_outlined),
              ),
              ButtonSegment(
                value: 2,
                label: Text('Reports'),
                icon: Icon(Icons.flag_outlined),
              ),
            ],
            selected: {tab},
            onSelectionChanged: (v) => setState(() => tab = v.first),
          ),
        ),
        Expanded(
          child: LoadView<Json>(
            key: ValueKey('$tab-${api.user!['id']}'),
            load: () async =>
                await api.get(['bookings/', 'quotes/', 'reports/'][tab]),
            builder: (data, reload) =>
                ActivityList(api: api, data: data, tab: tab, reload: reload),
          ),
        ),
      ],
    );
  }
}

class ActivityList extends StatefulWidget {
  final Api api;
  final Json data;
  final int tab;
  final VoidCallback reload;
  const ActivityList({
    super.key,
    required this.api,
    required this.data,
    required this.tab,
    required this.reload,
  });
  @override
  State<ActivityList> createState() => _ActivityListState();
}

class _ActivityListState extends State<ActivityList> {
  Json? pageData;
  bool loading = false;
  @override
  void didUpdateWidget(covariant ActivityList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) pageData = null;
  }

  Future<void> nextPage(String url) async {
    setState(() => loading = true);
    try {
      final query = Uri.parse(url).queryParameters;
      final result = await widget.api.get(
        ['bookings/', 'quotes/', 'reports/'][widget.tab],
        query: query,
      );
      if (mounted) setState(() => pageData = result);
    } catch (e) {
      if (mounted) showMessage(context, '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = pageData ?? widget.data;
    final rows = (data['results'] as List).cast<Json>();
    final api = widget.api;
    return PageBody(
      width: 800,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionTitle(
                [
                  'Your bookings',
                  'Your quotations',
                  'Your reports',
                ][widget.tab],
                subtitle: api.isProfessional && widget.tab != 2
                    ? 'Respond to customers and keep your work moving.'
                    : 'Follow the progress of your requests.',
              ),
            ),
            IconButton(
              tooltip: 'Refresh activity',
              onPressed: widget.reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (rows.isEmpty)
          EmptyState(
            ['No bookings yet', 'No quotes yet', 'No reports yet'][widget.tab],
            widget.tab == 2
                ? 'Any reports you send will appear here.'
                : api.isProfessional
                ? 'Requests from customers will appear here.'
                : 'Find a professional in Discover to send your first request.',
          ),
        for (final row in rows)
          widget.tab == 0
              ? BookingCard(api: api, booking: row, reload: widget.reload)
              : widget.tab == 1
              ? QuoteCard(api: api, quote: row, reload: widget.reload)
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tag(
                          row['resolved'] == true ? 'Resolved' : 'Under review',
                        ),
                        const Gap(),
                        Text(row['reason']),
                        if ('${row['resolution']}'.isNotEmpty) ...[
                          const Gap(),
                          Text(row['resolution']),
                        ],
                      ],
                    ),
                  ),
                ),
        if (data['previous'] != null || data['next'] != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: loading || data['previous'] == null
                    ? null
                    : () => nextPage(data['previous']),
                child: const Text('Previous'),
              ),
              TextButton(
                onPressed: loading || data['next'] == null
                    ? null
                    : () => nextPage(data['next']),
                child: const Text('Next'),
              ),
            ],
          ),
      ],
    );
  }
}

class BookingCard extends StatelessWidget {
  final Api api;
  final Json booking;
  final VoidCallback reload;
  const BookingCard({
    super.key,
    required this.api,
    required this.booking,
    required this.reload,
  });
  @override
  Widget build(BuildContext context) {
    final b = booking;
    final state = b['status'];
    final options = api.isProfessional
        ? state == 'pending'
              ? ['accepted', 'rejected']
              : state == 'accepted'
              ? ['completed']
              : <String>[]
        : ['pending', 'accepted'].contains(state)
        ? ['cancelled']
        : <String>[];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    api.isProfessional
                        ? b['customer_name']
                        : b['professional_name'],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Tag(
                  '$state',
                  color: state == 'completed'
                      ? teal
                      : ['cancelled', 'rejected'].contains(state)
                      ? Colors.grey
                      : blue,
                ),
              ],
            ),
            const Gap(8),
            Text('#${b['id']} · ${b['category_name']} · ${b['area_name']}'),
            const Gap(8),
            Text(dateLabel(b['scheduled_at'])),
            Text(b['address']),
            const Gap(12),
            Text(b['details']),
            const Gap(),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final target in options)
                  ActionButton(
                    label: {
                      'accepted': 'Accept booking',
                      'rejected': 'Reject booking',
                      'completed': 'Mark completed',
                      'cancelled': 'Cancel booking',
                    }[target]!,
                    action: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            {
                              'accepted': 'Accept this booking?',
                              'rejected': 'Reject this booking?',
                              'completed': 'Is the service complete?',
                              'cancelled': 'Cancel this booking?',
                            }[target]!,
                          ),
                          content: const Text(
                            'The other person will receive an update.',
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
                      if (confirmed != true) return;
                      await api.post('bookings/${b['id']}/status/', {
                        'status': target,
                      });
                      reload();
                    },
                  ),
                if (!api.isProfessional &&
                    state == 'completed' &&
                    b['review'] == null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReviewScreen(api: api, booking: b),
                        ),
                      );
                      reload();
                    },
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Write a review'),
                  ),
              ],
            ),
            if (b['review'] != null) ...[
              Tag('Your review: ${b['review']['rating']}/5', icon: Icons.star),
              const Gap(8),
              Text(b['review']['comment']),
            ],
          ],
        ),
      ),
    );
  }
}

class QuoteCard extends StatelessWidget {
  final Api api;
  final Json quote;
  final VoidCallback reload;
  const QuoteCard({
    super.key,
    required this.api,
    required this.quote,
    required this.reload,
  });
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  api.isProfessional
                      ? quote['customer_name']
                      : quote['professional_name'],
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Tag(
                quote['amount'] == null
                    ? 'Awaiting estimate'
                    : 'Quote received',
                color: quote['amount'] == null ? blue : teal,
              ),
            ],
          ),
          const Gap(8),
          Text('#${quote['id']} · ${quote['category_name']}'),
          const Gap(12),
          Text(quote['details']),
          if (quote['amount'] != null) ...[
            const Gap(),
            Text(
              money(quote['amount']),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(quote['response']),
          ],
          if (api.isProfessional) ...[
            const Gap(),
            OutlinedButton.icon(
              icon: const Icon(Icons.reply),
              label: Text(
                quote['amount'] == null ? 'Send estimate' : 'Update estimate',
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuoteReplyScreen(api: api, quote: quote),
                  ),
                );
                reload();
              },
            ),
          ],
          if (!api.isProfessional && quote['amount'] != null) ...[
            const Gap(),
            TextButton(
              onPressed: () async {
                final p = await api.get(
                  'professionals/${quote['professional']}/',
                );
                if (context.mounted) {
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
                }
                reload();
              },
              child: const Text('Book this professional'),
            ),
          ],
        ],
      ),
    ),
  );
}

class QuoteReplyScreen extends StatefulWidget {
  final Api api;
  final Json quote;
  const QuoteReplyScreen({super.key, required this.api, required this.quote});
  @override
  State<QuoteReplyScreen> createState() => _QuoteReplyScreenState();
}

class _QuoteReplyScreenState extends State<QuoteReplyScreen> {
  final form = GlobalKey<FormState>();
  late final amount = TextEditingController(
    text: '${widget.quote['amount'] ?? ''}',
  );
  late final response = TextEditingController(text: widget.quote['response']);
  @override
  void dispose() {
    amount.dispose();
    response.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Send an estimate')),
    body: PageBody(
      width: 600,
      children: [
        Text(widget.quote['details']),
        const Gap(24),
        Form(
          key: form,
          child: Column(
            children: [
              TextFormField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Estimated price (BDT)',
                ),
                validator: (v) => (num.tryParse(v ?? '') ?? 0) > 0
                    ? null
                    : 'Enter a positive price.',
              ),
              const Gap(),
              TextFormField(
                controller: response,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'What’s included?',
                ),
                validator: requiredText,
              ),
              const Gap(),
              ActionButton(
                label: 'Send estimate',
                action: () async {
                  if (!form.currentState!.validate()) return;
                  await widget.api.post('quotes/${widget.quote['id']}/reply/', {
                    'amount': amount.text.trim(),
                    'response': response.text.trim(),
                  });
                  if (context.mounted) {
                    showMessage(context, 'Estimate sent.');
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

class ReviewScreen extends StatefulWidget {
  final Api api;
  final Json booking;
  const ReviewScreen({super.key, required this.api, required this.booking});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int rating = 5;
  final comment = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Share your experience')),
    body: PageBody(
      width: 600,
      children: [
        SectionTitle(
          widget.booking['professional_name'],
          subtitle: 'Your review helps neighbors choose reliable help.',
        ),
        Wrap(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i stars',
                onPressed: () => setState(() => rating = i),
                icon: Icon(
                  i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: coral,
                  size: 36,
                ),
              ),
          ],
        ),
        const Gap(),
        Form(
          key: form,
          child: TextFormField(
            controller: comment,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'How did it go?'),
            validator: requiredText,
          ),
        ),
        const Gap(),
        ActionButton(
          label: 'Publish review',
          action: () async {
            if (!form.currentState!.validate()) return;
            await widget.api.post('reviews/', {
              'booking': widget.booking['id'],
              'rating': rating,
              'comment': comment.text.trim(),
            });
            if (context.mounted) {
              showMessage(context, 'Review published.');
              Navigator.pop(context);
            }
          },
        ),
      ],
    ),
  );
}
