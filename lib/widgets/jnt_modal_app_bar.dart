import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class JntModalHeaderMetrics {
  const JntModalHeaderMetrics._();

  static const double toolbarHeight = 80;
  static const double logoHeight = 50;
  static const double leadingWidth = 56;
  static const double rightPadding = 12;
  static const double closeButtonSize = 48;
}

class JntModalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const JntModalAppBar({
    super.key,
    required this.onClose,
    this.closeTooltip = 'Close',
    this.backgroundColor = AppColors.alabaster,
    this.autofocusClose = false,
    this.closeIcon = const Icon(Icons.close_rounded),
    this.leading,
    this.leadingWidth,
    this.title,
  });

  final VoidCallback onClose;
  final String closeTooltip;
  final Color backgroundColor;
  final bool autofocusClose;
  final Widget closeIcon;
  final Widget? leading;
  final double? leadingWidth;
  final Widget? title;

  @override
  Size get preferredSize =>
      const Size.fromHeight(JntModalHeaderMetrics.toolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      surfaceTintColor: backgroundColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      titleSpacing: 0,
      toolbarHeight: JntModalHeaderMetrics.toolbarHeight,
      leadingWidth: leadingWidth ?? JntModalHeaderMetrics.leadingWidth,
      leading: leading ?? const SizedBox.shrink(),
      title:
          title ??
          ExcludeSemantics(
            child: Image.asset(
              'assets/images/jnt_logo_black.png',
              height: JntModalHeaderMetrics.logoHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(
            right: JntModalHeaderMetrics.rightPadding,
          ),
          child: IconButton(
            tooltip: closeTooltip,
            autofocus: autofocusClose,
            onPressed: onClose,
            icon: closeIcon,
            style: IconButton.styleFrom(
              foregroundColor: AppColors.blackCat,
              minimumSize: const Size(
                JntModalHeaderMetrics.closeButtonSize,
                JntModalHeaderMetrics.closeButtonSize,
              ),
              padding: const EdgeInsets.all(12),
              shape: const RoundedRectangleBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

class JntModalHeaderBar extends StatelessWidget {
  const JntModalHeaderBar({
    super.key,
    required this.onClose,
    this.closeTooltip = 'Close',
    this.backgroundColor = AppColors.alabaster,
    this.autofocusClose = false,
    this.closeIcon = const Icon(Icons.close_rounded),
  });

  final VoidCallback onClose;
  final String closeTooltip;
  final Color backgroundColor;
  final bool autofocusClose;
  final Widget closeIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: JntModalHeaderMetrics.toolbarHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Align(
              alignment: Alignment.center,
              child: ExcludeSemantics(
                child: Image(
                  image: AssetImage('assets/images/jnt_logo_black.png'),
                  height: JntModalHeaderMetrics.logoHeight,
                  fit: BoxFit.contain,
                  errorBuilder: _errorBuilder,
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: IconButton(
                tooltip: closeTooltip,
                autofocus: autofocusClose,
                onPressed: onClose,
                icon: closeIcon,
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.blackCat,
                  minimumSize: const Size(
                    JntModalHeaderMetrics.closeButtonSize,
                    JntModalHeaderMetrics.closeButtonSize,
                  ),
                  padding: const EdgeInsets.all(12),
                  shape: const RoundedRectangleBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _errorBuilder(
    BuildContext _,
    Object __,
    StackTrace? ___,
  ) => const SizedBox.shrink();
}
