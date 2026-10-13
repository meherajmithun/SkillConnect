import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';

Future<Json?> chooseAppointment(
  BuildContext context,
  Api api,
  int professional,
) => Navigator.push<Json>(
  context,
  MaterialPageRoute(
    builder: (_) => AppointmentScreen(api: api, professional: professional),
  ),
);

class AppointmentScreen extends StatelessWidget {
  final Api api;
  final int professional;
  const AppointmentScreen({
    super.key,
    required this.api,
    required this.professional,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose an appointment')),
    body: LoadView<Json>(
      load: () async =>
          await api.get('professionals/$professional/availability/'),
      builder: (data, reload) => PageBody(
        width: 620,
        children: [
          const SectionTitle(
            'Available appointments',
            subtitle: 'Times are shown in your device’s local time. A booking request reserves the selected time.',
          ),
          OutlinedButton.icon(
            onPressed: reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh appointments'),
          ),
          const Gap(),
          for (final slot in data['slots'])
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.event_available_outlined,
                  color: teal,
                ),
                title: Text(dateLabel(slot['starts_at'])),
                subtitle: Text('Until ${dateLabel(slot['ends_at'])}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final start = DateTime.parse(slot['starts_at']);
                  final end = DateTime.parse(slot['ends_at']);
                  Navigator.pop(context, <String, dynamic>{
                    'slot': slot['id'],
                    'scheduled_at': start.toUtc().toIso8601String(),
                    'duration_minutes': end.difference(start).inMinutes,
                  });
                },
              ),
            ),
          if ((data['slots'] as List).isEmpty)
            const EmptyState(
              'No published appointments',
              'Try again later or ask the professional about their schedule.',
              icon: Icons.calendar_month_outlined,
            ),
          if (data['schedule_enabled'] != true) ...[
            const Gap(),
            const Text(
              'This professional also accepts requests at a time you choose.',
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: const Text('Request another time'),
              onPressed: () async {
                final selection = await Navigator.push<Json>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddAppointmentScreen(),
                  ),
                );
                if (context.mounted && selection != null) {
                  Navigator.pop(context, selection);
                }
              },
            ),
          ],
        ],
      ),
    ),
  );
}

class AddAppointmentScreen extends StatefulWidget {
  final bool publishing;
  const AddAppointmentScreen({super.key, this.publishing = false});
  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  DateTime? date;
  int duration = 60;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.publishing ? 'Publish appointment' : 'Request a time'),
    ),
    body: PageBody(
      width: 520,
      children: [
        const Text(
          'Choose a future date and time. Times follow your device’s time zone.',
        ),
        const Gap(),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(
            date == null
                ? 'Choose date and time'
                : dateLabel(date!.toIso8601String()),
          ),
          onPressed: () async {
            final now = DateTime.now();
            final day = await showDatePicker(
              context: context,
              initialDate: now.add(const Duration(days: 1)),
              firstDate: now,
              lastDate: now.add(const Duration(days: 90)),
            );
            if (day == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 10, minute: 0),
            );
            if (time != null && mounted) {
              setState(
                () => date = DateTime(
                  day.year,
                  day.month,
                  day.day,
                  time.hour,
                  time.minute,
                ),
              );
            }
          },
        ),
        const Gap(),
        DropdownButtonFormField<int>(
          initialValue: duration,
          decoration: const InputDecoration(labelText: 'Appointment duration'),
          items: [
            for (final minutes in [30, 60, 90, 120, 180, 240, 480])
              DropdownMenuItem(value: minutes, child: Text('$minutes minutes')),
          ],
          onChanged: (value) => setState(() => duration = value!),
        ),
        const Gap(24),
        FilledButton(
          onPressed: () {
            if (date == null || !date!.isAfter(DateTime.now())) {
              showMessage(context, 'Choose a future appointment.');
              return;
            }
            Navigator.pop(context, <String, dynamic>{
              'scheduled_at': date!.toUtc().toIso8601String(),
              'duration_minutes': duration,
            });
          },
          child: Text(
            widget.publishing ? 'Use this appointment' : 'Choose this time',
          ),
        ),
      ],
    ),
  );
}

class ManageCalendarScreen extends StatefulWidget {
  final Api api;
  const ManageCalendarScreen({super.key, required this.api});
  @override
  State<ManageCalendarScreen> createState() => _ManageCalendarScreenState();
}

class _ManageCalendarScreenState extends State<ManageCalendarScreen> {
  int page = 1;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Availability calendar')),
    body: LoadView<List<dynamic>>(
      key: ValueKey(page),
      load: () => Future.wait([
        widget.api.get('profile/'),
        widget.api.get('slots/', query: {'page': page}),
      ]),
      builder: (data, reload) => PageBody(
        width: 720,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Require a published appointment'),
            subtitle: const Text(
              'Customers must choose a slot from your calendar when enabled.',
            ),
            value: data[0]['schedule_enabled'] == true,
            onChanged: (value) async {
              try {
                await widget.api.patch('profile/', {'schedule_enabled': value});
                reload();
              } catch (e) {
                if (context.mounted) showMessage(context, '$e');
              }
            },
          ),
          ActionButton(
            label: 'Add available appointment',
            icon: Icons.add,
            action: () async {
              final selection = await Navigator.push<Json>(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddAppointmentScreen(publishing: true),
                ),
              );
              if (selection == null) return;
              final start = DateTime.parse(selection['scheduled_at']);
              await widget.api.post('slots/', {
                'starts_at': start.toIso8601String(),
                'ends_at': start
                    .add(Duration(minutes: selection['duration_minutes']))
                    .toIso8601String(),
              });
              reload();
            },
          ),
          const Gap(24),
          const SectionTitle(
            'Published appointments',
            subtitle: 'Reserved times disappear from the customer calendar. Manage bookings in Activity.',
          ),
          if ((data[1]['results'] as List).isEmpty)
            const Text('No appointments published yet.'),
          for (final slot in data[1]['results'])
            Card(
              child: ListTile(
                title: Text(dateLabel(slot['starts_at'])),
                subtitle: Text('Until ${dateLabel(slot['ends_at'])}'),
                trailing: IconButton(
                  tooltip: 'Remove appointment',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Remove this appointment?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Keep'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    try {
                      await widget.api.delete('slots/${slot['id']}/');
                      reload();
                    } catch (e) {
                      if (context.mounted) showMessage(context, '$e');
                    }
                  },
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: page > 1 ? () => setState(() => page--) : null,
                child: const Text('Previous'),
              ),
              TextButton(
                onPressed: data[1]['next'] != null
                    ? () => setState(() => page++)
                    : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
