import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../services/notifications_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  static Future<void> showAsModal(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Notifications',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: const Material(
                  color: AppColors.snow,
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: NotificationsPage(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const double _inputFs = 12;
  static const double _smallFs = 11.5;
  static const Color _focusRing = Color(0xFFFFBF47);

  final FocusNode _closeFocusNode = FocusNode(debugLabel: 'closeNotifications');
  final FocusNode _markAllFocusNode = FocusNode(debugLabel: 'markAllRead');
  final FocusNode _firstNotificationFocusNode = FocusNode(
    debugLabel: 'firstNotificationCard',
  );
  bool _didSetInitialFocus = false;
  bool _closeFocused = false;
  bool _markAllFocused = false;

  String get _email =>
      (Supabase.instance.client.auth.currentUser?.email ?? '').trim().toLowerCase();

  Stream<List<_NotificationItem>> _notificationsStream() {
    final email = _email;
    if (email.isEmpty) return Stream.value(const <_NotificationItem>[]);

    final controller = StreamController<List<_NotificationItem>>();

    Future<void> emit() async {
      try {
        final rows = await Supabase.instance.client
            .from('user_notifications')
            .select()
            .eq('receiver_email', email)
            .order('created_at_millis', ascending: false)
            .limit(100);

        final items = (rows as List<dynamic>)
            .whereType<Map>()
            .map((row) => _NotificationItem.fromSupabaseRow(
                  Map<String, dynamic>.from(row),
                ))
            .toList(growable: true);

        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (!controller.isClosed) {
          controller.add(items);
        }
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
        }
      }
    }

    unawaited(emit());

    final channel = Supabase.instance.client
        .channel('user_notifications_$email')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_email',
            value: email,
          ),
          callback: (_) => unawaited(emit()),
        )
        .subscribe();

    controller.onCancel = () async {
      await Supabase.instance.client.removeChannel(channel);
    };

    return controller.stream;
  }

  Future<void> _markAllRead(List<_NotificationItem> items) async {
    final unreadIds = items
        .where((e) => e.unread && e.id.isNotEmpty)
        .map((e) => e.id)
        .toList(growable: false);
    if (unreadIds.isEmpty) return;

    await Supabase.instance.client
        .from('user_notifications')
        .update({'read': true})
        .inFilter('id', unreadIds);

    await NotificationsService.trimUserNotifications(
      receiverEmail: _email,
      maxKeep: 25,
    );
  }

  Future<void> _markRead(_NotificationItem item) async {
    if (item.id.isEmpty) return;

    if (!item.unread) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Notification already read',
        Directionality.of(context),
      );
      return;
    }

    await Supabase.instance.client
        .from('user_notifications')
        .update({'read': true})
        .eq('id', item.id);
    await NotificationsService.trimUserNotifications(
      receiverEmail: _email,
      maxKeep: 25,
    );

    if (!mounted) return;

    SemanticsService.sendAnnouncement(
      View.of(context),
      'Notification marked as read',
      Directionality.of(context),
    );
  }

  @override
  void dispose() {
    _closeFocusNode.dispose();
    _markAllFocusNode.dispose();
    _firstNotificationFocusNode.dispose();
    super.dispose();
  }

  void _scheduleInitialFocus({
    required int unreadCount,
    required bool hasItems,
  }) {
    if (_didSetInitialFocus) return;
    _didSetInitialFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      if (unreadCount > 0) {
        _markAllFocusNode.requestFocus();
      } else if (hasItems) {
        _firstNotificationFocusNode.requestFocus();
      } else {
        _closeFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showAdaFocusRing =
        (MediaQuery.maybeOf(context)?.accessibleNavigation ?? false) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .accessibleNavigation;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: 'Notifications',
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: AppColors.snow,
        appBar: AppBar(
          backgroundColor: AppColors.alabaster,
          surfaceTintColor: AppColors.alabaster,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: ExcludeSemantics(
            child: Image.asset(
              'assets/images/jnt_logo_black.png',
              height: 50,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          centerTitle: true,
          actions: [
            StreamBuilder<List<_NotificationItem>>(
              stream: _notificationsStream(),
              builder: (context, snap) {
                final items = snap.data ?? const <_NotificationItem>[];
                final unreadCount = items.where((e) => e.unread).length;
                if (unreadCount <= 0) return const SizedBox.shrink();
                return Focus(
                  focusNode: _markAllFocusNode,
                  onFocusChange: (v) => setState(() => _markAllFocused = v),
                  child: Container(
                    decoration: BoxDecoration(
                      border: (showAdaFocusRing && _markAllFocused)
                          ? Border.all(color: _focusRing, width: 2)
                          : null,
                    ),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.blackCat,
                      ),
                      onPressed: () => _markAllRead(items),
                      child: const Text(
                        'Mark all as read',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.blackCat,
                          fontSize: _inputFs,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Focus(
              focusNode: _closeFocusNode,
              onFocusChange: (v) => setState(() => _closeFocused = v),
              child: Container(
                decoration: BoxDecoration(
                  border: (showAdaFocusRing && _closeFocused)
                      ? Border.all(color: _focusRing, width: 2)
                      : null,
                ),
                child: IconButton(
                  tooltip: 'Close notifications',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: StreamBuilder<List<_NotificationItem>>(
          stream: _notificationsStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return Semantics(
                label: 'Loading notifications',
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            final items = snap.data ?? const <_NotificationItem>[];
            final unreadCount = items.where((e) => e.unread).length;
            _scheduleInitialFocus(
              unreadCount: unreadCount,
              hasItems: items.isNotEmpty,
            );

            final now = DateTime.now();
            final today = items
                .where(
                  (e) =>
                      e.createdAt.year == now.year &&
                      e.createdAt.month == now.month &&
                      e.createdAt.day == now.day,
                )
                .toList(growable: false);
            final earlier = items
                .where(
                  (e) =>
                      !(e.createdAt.year == now.year &&
                          e.createdAt.month == now.month &&
                          e.createdAt.day == now.day),
                )
                .toList(growable: false);

            final _NotificationItem? firstItem = items.isEmpty
                ? null
                : items.first;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              children: [
                _TopSummaryPill(unreadCount: unreadCount, inputFs: _inputFs),
                const SizedBox(height: 12),
                if (today.isNotEmpty) ...[
                  const _SectionLabel(text: 'TODAY', semanticLabel: 'Today'),
                  const SizedBox(height: 10),
                  ...today.asMap().entries.map((entry) {
                    final item = entry.value;
                    final isFirst = identical(item, firstItem);
                    return _NotifCard(
                      item: item,
                      inputFs: _inputFs,
                      smallFs: _smallFs,
                      onTap: () => _markRead(item),
                      focusNode: isFirst ? _firstNotificationFocusNode : null,
                    );
                  }),
                ],
                if (earlier.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const _SectionLabel(
                    text: 'EARLIER',
                    semanticLabel: 'Earlier',
                  ),
                  const SizedBox(height: 10),
                  ...earlier.map((item) {
                    final isFirst = identical(item, firstItem);
                    return _NotifCard(
                      item: item,
                      inputFs: _inputFs,
                      smallFs: _smallFs,
                      onTap: () => _markRead(item),
                      focusNode: isFirst ? _firstNotificationFocusNode : null,
                    );
                  }),
                ],
                const SizedBox(height: 8),
                if (items.isEmpty)
                  Semantics(
                    label: 'No notifications yet',
                    child: const Center(child: Text('No notifications yet')),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopSummaryPill extends StatelessWidget {
  const _TopSummaryPill({required this.unreadCount, required this.inputFs});

  final int unreadCount;
  final double inputFs;

  @override
  Widget build(BuildContext context) {
    final text = unreadCount == 0
        ? 'You are all caught up'
        : '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}';

    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Column(
          children: [
            Row(
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 22,
                    color: AppColors.deepPlum,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: inputFs,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.blackCatBorderLight),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.semanticLabel});
  final String text;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Text(
          text,
          style: TextStyle(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w900,
            fontSize: 10.5,
            color: Colors.black.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({
    required this.item,
    required this.onTap,
    required this.inputFs,
    required this.smallFs,
    this.focusNode,
  });

  final _NotificationItem item;
  final VoidCallback onTap;
  final double inputFs;
  final double smallFs;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final iconData = _iconFor(item.type);
    final accent = _accentFor(item.type);
    final cleanBody = _cleanForSemantics(item.body);
    final readableTime = _readableTimeAgo(item.timeAgo);
    final semanticLabel = item.unread
        ? 'Unread notification. ${item.title}. $cleanBody. $readableTime.'
        : 'Read notification. ${item.title}. $cleanBody. $readableTime.';

    return Column(
      children: [
        Semantics(
          button: true,
          label: semanticLabel,
          onTap: onTap,
          child: ExcludeSemantics(
            child: InkWell(
              focusNode: focusNode,
              onTap: onTap,
              borderRadius: BorderRadius.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(iconData, color: accent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  softWrap: true,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: inputFs,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.timeAgo,
                                style: TextStyle(
                                  fontSize: smallFs,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black.withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              children: _bodySpans(item.body),
                              style: TextStyle(
                                fontSize: inputFs,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withValues(alpha: 0.60),
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (item.unread)
                      ExcludeSemantics(
                        child: Container(
                          margin: const EdgeInsets.only(top: 6),
                          height: 10,
                          width: 10,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const ExcludeSemantics(
          child: Divider(height: 1, color: AppColors.blackCatBorderLight),
        ),
      ],
    );
  }

  IconData _iconFor(_NotifType t) {
    switch (t) {
      case _NotifType.order:
        return Icons.local_shipping_outlined;
      case _NotifType.design:
        return Icons.palette_outlined;
      case _NotifType.promo:
        return Icons.local_fire_department_outlined;
    }
  }

  Color _accentFor(_NotifType t) {
    switch (t) {
      case _NotifType.order:
        return const Color(0xFF2E8B57);
      case _NotifType.design:
        return AppColors.deepPlum;
      case _NotifType.promo:
        return const Color(0xFFB65A1E);
    }
  }

  List<TextSpan> _bodySpans(String body) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    var start = 0;
    for (final match in regex.allMatches(body)) {
      if (match.start > start) {
        spans.add(TextSpan(text: body.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1) ?? '',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      );
      start = match.end;
    }
    if (start < body.length) {
      spans.add(TextSpan(text: body.substring(start)));
    }
    return spans;
  }

  String _cleanForSemantics(String value) {
    return value
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _readableTimeAgo(String value) {
    final v = value.trim();
    if (v == 'now') return 'now';
    if (v.endsWith('m')) {
      final n = v.substring(0, v.length - 1);
      return '$n minute${n == '1' ? '' : 's'} ago';
    }
    if (v.endsWith('h')) {
      final n = v.substring(0, v.length - 1);
      return '$n hour${n == '1' ? '' : 's'} ago';
    }
    if (v.endsWith('d')) {
      final n = v.substring(0, v.length - 1);
      return '$n day${n == '1' ? '' : 's'} ago';
    }
    return v;
  }
}

enum _NotifType { order, design, promo }

class _NotificationItem {
  final String id;
  final _NotifType type;
  final String title;
  final String body;
  final String timeAgo;
  final bool unread;
  final DateTime createdAt;

  const _NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timeAgo,
    required this.unread,
    required this.createdAt,
  });

  static _NotificationItem fromSupabaseRow(Map<String, dynamic> data) {
    final createdAt = _resolveCreatedAt(data);
    final typeRaw = ((data['type'] ?? '') as Object).toString().toLowerCase();
    _NotifType type;
    if (typeRaw.contains('payment')) {
      type = _NotifType.order;
    } else if (typeRaw.contains('request') || typeRaw.contains('design')) {
      type = _NotifType.design;
    } else {
      type = _NotifType.order;
    }

    return _NotificationItem(
      id: ((data['id'] ?? '') as Object).toString(),
      type: type,
      title: ((data['title'] ?? 'Notification') as Object).toString(),
      body: ((data['body'] ?? '') as Object).toString(),
      timeAgo: _timeAgo(createdAt),
      unread: data['read'] != true,
      createdAt: createdAt,
    );
  }

  static DateTime _resolveCreatedAt(Map<String, dynamic> data) {
    final createdAtMillis = data['created_at_millis'] ?? data['createdAtMillis'];
    if (createdAtMillis is num) {
      return DateTime.fromMillisecondsSinceEpoch(createdAtMillis.toInt());
    }

    final createdAt = data['created_at'] ?? data['createdAt'];
    if (createdAt is DateTime) return createdAt;
    if (createdAt != null) {
      final parsed = DateTime.tryParse(createdAt.toString());
      if (parsed != null) return parsed;
    }

    final createdAtClient = data['created_at_client'] ?? data['createdAtClient'];
    if (createdAtClient is DateTime) return createdAtClient;
    if (createdAtClient != null) {
      final parsed = DateTime.tryParse(createdAtClient.toString());
      if (parsed != null) return parsed;
    }

    return DateTime.now();
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
