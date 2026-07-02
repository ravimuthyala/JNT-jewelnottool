import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NotificationsPopup extends StatefulWidget {
  const NotificationsPopup({super.key});

  @override
  State<NotificationsPopup> createState() => _NotificationsPopupState();
}

class _NotificationsPopupState extends State<NotificationsPopup> {
  static const Color _focusRing = Color(0xFFFFBF47);

  final FocusNode _markAllFocusNode = FocusNode(debugLabel: 'markAllRead');
  final FocusNode _firstNotificationFocusNode = FocusNode(
    debugLabel: 'firstNotificationTile',
  );
  final FocusNode _closeFocusNode = FocusNode(debugLabel: 'closeNotifications');

  bool _didSetInitialFocus = false;
  bool _markAllFocused = false;
  bool _closeFocused = false;
  bool _firstTileFocused = false;

  final List<_PopupNotifItem> _items = const <_PopupNotifItem>[
    _PopupNotifItem(
      title: 'Order shipped',
      body: 'Your kit is on the way.',
      time: '2m',
      unread: true,
    ),
    _PopupNotifItem(
      title: 'Design approved',
      body: 'Artist approved your design.',
      time: '1h',
      unread: true,
    ),
    _PopupNotifItem(
      title: 'Trending designs',
      body: 'Fresh picks added today.',
      time: '3h',
      unread: false,
    ),
  ];

  @override
  void dispose() {
    _markAllFocusNode.dispose();
    _firstNotificationFocusNode.dispose();
    _closeFocusNode.dispose();
    super.dispose();
  }

  void _scheduleInitialFocus() {
    if (_didSetInitialFocus) return;
    _didSetInitialFocus = true;
    final unreadCount = _items.where((e) => e.unread).length;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      if (unreadCount > 0) {
        _markAllFocusNode.requestFocus();
      } else if (_items.isNotEmpty) {
        _firstNotificationFocusNode.requestFocus();
      } else {
        _closeFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleInitialFocus();
    final unreadCount = _items.where((e) => e.unread).length;
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
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.topRight,
          child: Container(
            margin: const EdgeInsets.only(top: 86, right: 12),
            width: 340,
            constraints: const BoxConstraints(maxHeight: 420),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.zero,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 30,
                  offset: const Offset(-280, 44),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(
                  unreadCount: unreadCount,
                  markAllFocusNode: _markAllFocusNode,
                  closeFocusNode: _closeFocusNode,
                  onMarkAllFocusChange: (v) =>
                      setState(() => _markAllFocused = v),
                  onCloseFocusChange: (v) => setState(() => _closeFocused = v),
                  markAllFocused: _markAllFocused,
                  closeFocused: _closeFocused,
                  focusRing: _focusRing,
                  showAdaFocusRing: showAdaFocusRing,
                  onMarkAll: () {},
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: _items
                        .asMap()
                        .entries
                        .map((entry) {
                          final i = entry.key;
                          final item = entry.value;
                          final isFirst = i == 0;
                          return _NotifTile(
                            title: item.title,
                            body: item.body,
                            time: item.time,
                            unread: item.unread,
                            focusNode: isFirst
                                ? _firstNotificationFocusNode
                                : null,
                            focused: isFirst ? _firstTileFocused : false,
                            onFocusChange: isFirst
                                ? (v) => setState(() => _firstTileFocused = v)
                                : null,
                            focusRing: _focusRing,
                            showAdaFocusRing: showAdaFocusRing,
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PopupNotifItem {
  const _PopupNotifItem({
    required this.title,
    required this.body,
    required this.time,
    required this.unread,
  });

  final String title;
  final String body;
  final String time;
  final bool unread;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.unreadCount,
    required this.markAllFocusNode,
    required this.closeFocusNode,
    required this.onMarkAllFocusChange,
    required this.onCloseFocusChange,
    required this.markAllFocused,
    required this.closeFocused,
    required this.focusRing,
    required this.showAdaFocusRing,
    required this.onMarkAll,
  });

  final int unreadCount;
  final FocusNode markAllFocusNode;
  final FocusNode closeFocusNode;
  final ValueChanged<bool> onMarkAllFocusChange;
  final ValueChanged<bool> onCloseFocusChange;
  final bool markAllFocused;
  final bool closeFocused;
  final Color focusRing;
  final bool showAdaFocusRing;
  final VoidCallback onMarkAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Row(
        children: [
          const ExcludeSemantics(
            child: Text(
              'Notifications',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
          const Spacer(),
          if (unreadCount > 0)
            Focus(
              focusNode: markAllFocusNode,
              onFocusChange: onMarkAllFocusChange,
              child: Container(
                decoration: BoxDecoration(
                  border: (showAdaFocusRing && markAllFocused)
                      ? Border.all(color: focusRing, width: 2)
                      : null,
                ),
                child: TextButton(
                  onPressed: onMarkAll,
                  child: const Text(
                    'Mark as read',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepPlum,
                    ),
                  ),
                ),
              ),
            ),
          Focus(
            focusNode: closeFocusNode,
            onFocusChange: onCloseFocusChange,
            child: Container(
              decoration: BoxDecoration(
                border: (showAdaFocusRing && closeFocused)
                    ? Border.all(color: focusRing, width: 2)
                    : null,
              ),
              child: IconButton(
                tooltip: 'Close notifications',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({
    required this.title,
    required this.body,
    required this.time,
    required this.unread,
    required this.focusRing,
    required this.showAdaFocusRing,
    this.focusNode,
    this.focused = false,
    this.onFocusChange,
  });

  final String title;
  final String body;
  final String time;
  final bool unread;
  final bool showAdaFocusRing;
  final FocusNode? focusNode;
  final bool focused;
  final ValueChanged<bool>? onFocusChange;
  final Color focusRing;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = unread
        ? 'Unread notification. $title. $body. $time ago.'
        : 'Read notification. $title. $body. $time ago.';

    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: () => Navigator.pop(context),
      child: ExcludeSemantics(
        child: Focus(
          focusNode: focusNode,
          onFocusChange: onFocusChange,
          child: Container(
            decoration: BoxDecoration(
              border: (showAdaFocusRing && focused)
                  ? Border.all(color: focusRing, width: 2)
                  : null,
            ),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (unread)
                      ExcludeSemantics(
                        child: Container(
                          margin: const EdgeInsets.only(top: 6),
                          height: 8,
                          width: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.deepPlum,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            body,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.black.withValues(alpha: 0.6),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
