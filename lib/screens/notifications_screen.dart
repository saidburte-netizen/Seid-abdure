import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../widgets/common.dart';
import '../widgets/module_scaffold.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = const [];
  Set<String> _readIds = const {};
  bool _loading = true;
  String? _error;
  int _tab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_notifications.isEmpty && _loading) _load();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    final userId = session.userId;
    if (branch == null || userId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await session.client
          .from('notifications')
          .select()
          .eq('branch_id', branch.branchId)
          .order('created_at', ascending: false)
          .limit(150);
      final notifications = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final reads = await session.client
          .from('notification_reads')
          .select('notification_id')
          .eq('user_id', userId);
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _readIds = {
          for (final row in (reads as List)) row['notification_id'] as String,
        };
      });
    } catch (error) {
      if (mounted) setState(() => _error = readableError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> notification) async {
    final session = SessionScope.of(context);
    if (session.userId == null) return;
    try {
      await session.client.from('notification_reads').upsert({
        'notification_id': notification['id'],
        'user_id': session.userId,
      }, onConflict: 'notification_id,user_id');
      if (mounted) {
        setState(() => _readIds = {..._readIds, notification['id'] as String});
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  Future<void> _markAllRead() async {
    final session = SessionScope.of(context);
    if (session.userId == null) return;
    final unread = _notifications
        .where((row) => !_readIds.contains(row['id']))
        .map((row) => {'notification_id': row['id'], 'user_id': session.userId})
        .toList();
    if (unread.isEmpty) return;
    try {
      await session.client
          .from('notification_reads')
          .upsert(unread, onConflict: 'notification_id,user_id');
      if (mounted) {
        setState(
          () => _readIds = {
            ..._readIds,
            for (final row in _notifications) row['id'] as String,
          },
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  Future<void> _refreshAlerts() async {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    if (branch == null) return;
    try {
      final response = await session.client.rpc(
        'refresh_branch_alerts',
        params: {'target_branch': branch.branchId},
      );
      if (mounted) {
        await showInfoDialog(
          context,
          title: 'Alerts refreshed',
          content: response,
        );
        await _load();
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => ModuleScaffold(
    title: 'Notifications',
    body: DefaultTabController(
      length: 2,
      initialIndex: _tab,
      child: Column(
        children: [
          TabBar(
            onTap: (value) => _tab = value,
            tabs: const [
              Tab(text: 'Inbox'),
              Tab(text: 'Preferences'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [_inbox(context), const _NotificationPreferences()],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _inbox(BuildContext context) {
    final session = SessionScope.of(context);
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
                label: const Text('Refresh alerts'),
              ),
              OutlinedButton.icon(
                onPressed: _markAllRead,
                icon: const Icon(Icons.done_all),
                label: const Text('Mark all read'),
              ),
              IconButton(
                tooltip: 'Reload',
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                )
              : _notifications.isEmpty
              ? const EmptyView(
                  message:
                      'No notifications yet. Refresh alerts to generate them.',
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
                      final read = _readIds.contains(notification['id']);
                      return _NotificationTile(
                        notification: notification,
                        read: read,
                        onTap: read ? null : () => _markRead(notification),
                      );
                    },
                  ),
                ),
        ),
        if (session.selectedBranch != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Showing alerts for ${session.selectedBranch!.branchName}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.read,
    this.onTap,
  });

  final Map<String, dynamic> notification;
  final bool read;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final severity = asText(notification['severity'], fallback: 'info');
    final color = switch (severity) {
      'critical' => scheme.error,
      'warning' => scheme.tertiary,
      _ => scheme.primary,
    };
    final icon = switch (asText(notification['category'])) {
      'stock' => Icons.inventory_2_outlined,
      'sales' => Icons.point_of_sale_outlined,
      'cash' => Icons.account_balance_wallet_outlined,
      'payables' => Icons.request_quote_outlined,
      'rentals' => Icons.apartment_outlined,
      'people' => Icons.groups_outlined,
      _ => Icons.notifications_outlined,
    };
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                asText(notification['title'], fallback: 'Notification'),
                style: TextStyle(
                  fontWeight: read ? FontWeight.w400 : FontWeight.w700,
                ),
              ),
            ),
            if (!read)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: scheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (asText(notification['body']).isNotEmpty)
              Text(asText(notification['body'])),
            const SizedBox(height: 4),
            Text(
              '${prettyLabel(asText(notification['category']))} • '
              '${formatDateTime(notification['created_at'])}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: read
            ? const Icon(Icons.mark_email_read_outlined)
            : const Icon(Icons.mark_email_unread_outlined),
      ),
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
  Map<String, dynamic>? _preferences;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _keys = {
    'in_app': 'In-app notifications',
    'email_digest': 'Email digest',
    'stock_alerts': 'Stock alerts',
    'payable_alerts': 'Payable alerts',
    'rent_alerts': 'Rent alerts',
    'approval_alerts': 'Approval alerts',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _preferences == null) _load();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    final userId = session.userId;
    if (userId == null) return;
    try {
      final row = await session.client
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) {
        final created = await session.client
            .from('notification_preferences')
            .insert({'user_id': userId})
            .select()
            .single();
        if (mounted) {
          setState(() => _preferences = Map<String, dynamic>.from(created));
        }
      } else {
        if (mounted) {
          setState(() => _preferences = Map<String, dynamic>.from(row));
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = readableError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final session = SessionScope.of(context);
    final userId = session.userId;
    final preferences = _preferences;
    if (userId == null || preferences == null) return;
    setState(() => _saving = true);
    try {
      await session.client.from('notification_preferences').upsert({
        'user_id': userId,
        for (final key in _keys.keys) key: preferences[key] ?? true,
      }, onConflict: 'user_id');
      if (mounted) showSnack(context, 'Notification preferences saved.');
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    final preferences = _preferences ?? {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Notification preferences',
          child: Column(
            children: [
              for (final entry in _keys.entries)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  value: asBool(preferences[entry.key], fallback: true),
                  onChanged: (value) => setState(() {
                    _preferences = {...preferences, entry.key: value};
                  }),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save preferences'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
