import 'package:flutter/material.dart';
import '../services/notifications_service.dart';
import '../services/supabase_bootstrap.dart';
import '../theme/app_colors.dart';

class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({
    super.key,
    required this.onTap,
    this.focusNode,
    this.unreadCount,
    this.iconSize = 24,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.badgeRight = -3,
    this.badgeTop = -3,
  });

  final VoidCallback onTap;
  final FocusNode? focusNode;
  final int? unreadCount;
  final double iconSize;
  final EdgeInsets padding;
  final double badgeRight;
  final double badgeTop;

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  static const Color _focusRing = Color(0xFFFFBF47);
  static const Color _iconColor = AppColors.blackCat;
  bool _focused = false;

  String _notificationSemanticLabel(int count) {
    if (count <= 0) return 'Notifications, no unread notifications';
    if (count == 1) return 'Notifications, 1 unread notification';
    return 'Notifications, $count unread notifications';
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = (SupabaseBootstrap.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();

    if (widget.unreadCount != null) {
      return _buildSemanticButton((widget.unreadCount ?? 0).clamp(0, 999));
    }

    return StreamBuilder<int>(
      stream: NotificationsService.watchUnreadCount(receiverEmail: userEmail),
      initialData: 0,
      builder: (context, snapshot) {
        final unread = (snapshot.data ?? 0).clamp(0, 999);
        return _buildSemanticButton(unread);
      },
    );
  }

  Widget _buildSemanticButton(int unread) {
    final semanticLabel = _notificationSemanticLabel(unread);
    final hasUnread = unread > 0;
    final bellBox = widget.iconSize < 24 ? 24.0 : widget.iconSize;
    final showAdaFocusRing =
        (MediaQuery.maybeOf(context)?.accessibleNavigation ?? false) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .accessibleNavigation;

    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: widget.onTap,
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (value) => setState(() => _focused = value),
        child: Container(
          decoration: BoxDecoration(
            border: (showAdaFocusRing && _focused)
                ? Border.all(color: _focusRing, width: 2)
                : null,
          ),
          child: ExcludeSemantics(
            child: IconButton(
              tooltip: semanticLabel,
              onPressed: widget.onTap,
              color: _iconColor,
              icon: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  SizedBox(
                    width: bellBox,
                    height: bellBox,
                    child: Center(
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: widget.iconSize,
                        color: _iconColor,
                      ),
                    ),
                  ),
                  if (hasUnread)
                    Positioned(
                      right: widget.badgeRight,
                      top: widget.badgeTop,
                      child: ExcludeSemantics(
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 16),
                          height: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE85656),
                            borderRadius: BorderRadius.zero,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              padding: widget.padding,
              constraints: const BoxConstraints(),
            ),
          ),
        ),
      ),
    );
  }
}
