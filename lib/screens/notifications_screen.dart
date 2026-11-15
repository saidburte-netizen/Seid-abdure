import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../widgets/common.dart';
import '../widgets/module_scaffold.dart';
import '../l10n/ui_text.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = const [];
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = session.userId;
      if (uid == null) return;
      var query = session.client.from('notifications').select();
      final role = session.roleCode;
      if (role != null) {
        query = query.or('user_id.eq.$uid,role_code.eq.$role');
      } else {
        query = query.eq('user_id', uid);
      }
      final rows = await query.order('created_at', ascending: false).limit(200);
      if (!mounted) return;
      setState(() {
        _notifications = (rows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = readableError(context, error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> notification) async {
    final session = SessionScope.of(context);
    try {
      await session.client.from('notifications').update(
          {'is_read': true, 'read_at': nowIso()}).eq('id', notification['id']);
      await _load();
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    }
  }

  Future<void> _markAllRead() async {
    final session = SessionScope.of(context);
    try {
      final uid = session.userId;
      if (uid == null) return;
      var query = session.client
          .from('notifications')
          .update({'is_read': true, 'read_at': nowIso()}).eq('is_read', false);
      final role = session.roleCode;
      if (role != null) {
        query = query.or('user_id.eq.$uid,role_code.eq.$role');
      } else {
        query = query.eq('user_id', uid);
      }
      await query;
      await _load();
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    }
  }

  Future<void> _refreshAlerts() async {
    final session = SessionScope.of(context);
    try {
      await session.client.rpc('fn_generate_alerts');
      await _load();
      if (mounted) showSnack(context, 'Alerts generated.');
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => ModuleScaffold(
        title: uiText(context, 'Notifications'),
        body: DefaultTabController(
          length: 2,
          initialIndex: widget.initialTab.clamp(0, 1),
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Inbox'),
                  Tab(text: 'Preferences'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [_inbox(), const _NotificationPreferences()],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _inbox() {
    final unread = _notifications.where((row) => row['is_read'] != true).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _refreshAlerts,
                icon: const Icon(Icons.notifications_active_outlined),
                label: const LText('Generate alerts'),
              ),
              OutlinedButton.icon(
                onPressed: unread == 0 ? null : _markAllRead,
                icon: const Icon(Icons.done_all),
                label: Text('Mark all read ($unread)'),
              ),
              IconButton(
                tooltip: uiText(context, 'Reload'),
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : _notifications.isEmpty
                      ? EmptyView(
                          message: uiText(
                            context,
                            'No notifications yet. Generate alerts to refresh.',
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _notifications.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final notification = _notifications[index];
                              final read = notification['is_read'] == true;
                              return Card(
                                child: ListTile(
                                  leading: Icon(
                                    read
                                        ? Icons.notifications_none
                                        : Icons.notifications_active,
                                    color: read
                                        ? null
                                        : Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                  ),
                                  title: Text(asText(notification['title'])),
                                  subtitle: Text(
                                    '${asText(notification['body'])}\n${formatDateTime(notification['created_at'])}',
                                  ),
                                  isThreeLine: true,
                                  trailing: read
                                      ? null
                                      : IconButton(
                                          tooltip: uiText(context, 'Mark read'),
                                          onPressed: () =>
                                              _markRead(notification),
                                          icon: const Icon(Icons.done),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _NotificationPreferences extends StatefulWidget {
  const _NotificationPreferences();

  @override
  State<_NotificationPreferences> createState() =>
      _NotificationPreferencesState();
}

class _NotificationPreferencesState extends State<_NotificationPreferences> {
  static const _types = [
    'low_stock',
    'rent_due',
    'receivable_overdue',
    'payable_due',
    'payroll',
    'approval',
    'system',
  ];
  final _rows = <String, Map<String, dynamic>>{};
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await session.client
          .from('notification_settings')
          .select()
          .eq('user_id', session.userId ?? '');
      if (!mounted) return;
      setState(() {
        for (final raw in (rows as List)) {
          final row = Map<String, dynamic>.from(raw as Map);
          _rows[row['notification_type'] as String] = row;
        }
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyMessage(error);
        });
      }
    }
  }

  Future<void> _set(String type, String field, bool value) async {
    final session = SessionScope.of(context);
    final current = _rows[type] ??
        {
          'user_id': session.userId,
          'notification_type': type,
          'in_app': true,
          'push': false,
          'sms': false,
          'email': false,
        };
    current[field] = value;
    setState(() => _rows[type] = current);
    try {
      final id = current['id'];
      if (id == null) {
        await session.client.from('notification_settings').insert(current);
      } else {
        await session.client
            .from('notification_settings')
            .update(current)
            .eq('id', id);
      }
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Choose how you receive each notification type. In-app alerts are '
            'stored in the notifications inbox.',
          ),
          const SizedBox(height: 12),
          for (final type in _types)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uiText(context, prettyLabel(type)),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final field in ['in_app', 'push', 'sms', 'email'])
                          FilterChip(
                            label: Text(uiText(context, prettyLabel(field))),
                            selected: (_rows[type]?[field] as bool?) ??
                                field == 'in_app',
                            onSelected: (value) => _set(type, field, value),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
