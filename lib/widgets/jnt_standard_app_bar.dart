import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'notification_bell_button.dart';

class JntHeaderMetrics {
  const JntHeaderMetrics._();

  static const double toolbarHeight = 110;
  static const double leadingWidth = 56;
  static const double logoHeight = 70;
  static const double notificationIconSize = 28;
  static const double avatarSize = 55;
  static const double rightPadding = 12;
}

class JntStandardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const JntStandardAppBar({
    super.key,
    required this.onNotifications,
    this.notificationFocusNode,
    this.leading,
    this.trailing,
    this.title,
    this.backgroundColor = AppColors.alabaster,
  });

  final VoidCallback onNotifications;
  final FocusNode? notificationFocusNode;
  final Widget? leading;
  final Widget? trailing;
  final Widget? title;
  final Color backgroundColor;

  @override
  Size get preferredSize =>
      const Size.fromHeight(JntHeaderMetrics.toolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      surfaceTintColor: backgroundColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      titleSpacing: 0,
      toolbarHeight: JntHeaderMetrics.toolbarHeight,
      leadingWidth: JntHeaderMetrics.leadingWidth,
      leading:
          leading ??
          NotificationBellButton(
            onTap: onNotifications,
            focusNode: notificationFocusNode,
            iconSize: JntHeaderMetrics.notificationIconSize,
          ),
      title:
          title ??
          ExcludeSemantics(
            child: Image.asset(
              'assets/images/jnt_logo_black.png',
              height: JntHeaderMetrics.logoHeight,
              // Decode at display size, not the asset's native resolution --
              // without this a stray oversized source file (as happened
              // before) silently costs a multi-second decode on first paint
              // instead of a build-time-obvious error.
              cacheHeight:
                  (JntHeaderMetrics.logoHeight *
                          MediaQuery.of(context).devicePixelRatio)
                      .round(),
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
      actions: trailing == null
          ? null
          : [
              Padding(
                padding: const EdgeInsets.only(
                  right: JntHeaderMetrics.rightPadding,
                ),
                child: Center(child: trailing!),
              ),
            ],
    );
  }
}
