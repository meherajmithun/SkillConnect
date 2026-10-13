import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';

class MessagesScreen extends StatefulWidget {
  final Api api;
  final String kind;
  final int requestId;
  final String title;
  const MessagesScreen({
    super.key,
    required this.api,
    required this.kind,
    required this.requestId,
    required this.title,
  });
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with WidgetsBindingObserver {
  final text = TextEditingController();
  Timer? timer;
  Json? data;
  String? error;
  int page = 1;
  bool fetching = false;
  bool active = true;
  String get path => '${widget.kind}/${widget.requestId}/messages/';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetch();
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (active && page == 1) fetch();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) fetch();
  }

  Future<void> fetch() async {
    if (fetching || !active) return;
    fetching = true;
    try {
      final result = await widget.api.get(path, query: {'page': page}) as Json;
      if (!mounted) return;
      setState(() {
        data = result;
        error = null;
      });
      final rows = result['results'] as List;
      if (rows.isNotEmpty) {
        await widget.api.post('${path}read/', {'through_id': rows.first['id']});
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      fetching = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = (data?['results'] as List? ?? []).cast<Json>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: fetching ? null : fetch,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${widget.kind == 'bookings' ? 'Booking' : 'Quotation'} #${widget.requestId} · Messages are shared only with the other participant.',
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            if (data == null && error == null) const LinearProgressIndicator(),
            if (data?['next'] != null || page > 1)
              Wrap(
                children: [
                  TextButton(
                    onPressed: fetching || page == 1
                        ? null
                        : () {
                            setState(() => page = 1);
                            fetch();
                          },
                    child: const Text('Latest messages'),
                  ),
                  TextButton(
                    onPressed: fetching || data?['next'] == null
                        ? null
                        : () {
                            setState(() => page++);
                            fetch();
                          },
                    child: const Text('Older messages'),
                  ),
                ],
              ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(
                      child: Text('Start a conversation about this request.'),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final mine = row['sender'] == widget.api.user?['id'];
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 500),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: mine
                                  ? blue.withValues(alpha: .08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE0E7F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mine ? 'You' : row['sender_name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Gap(6),
                                Text(row['body']),
                                const Gap(8),
                                Text(
                                  '${dateLabel(row['created_at'])}${mine
                                      ? row['read_at'] == null
                                            ? ' · Sent'
                                            : ' · Read'
                                      : ''}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: text,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Ask a question or discuss the work',
                    ),
                  ),
                  const Gap(8),
                  ActionButton(
                    label: 'Send message',
                    icon: Icons.send_outlined,
                    action: () async {
                      final body = text.text.trim();
                      if (body.isEmpty) {
                        showMessage(context, 'Write a message first.');
                        return;
                      }
                      await widget.api.post(path, {'body': body});
                      text.clear();
                      if (mounted) setState(() => page = 1);
                      await fetch();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
