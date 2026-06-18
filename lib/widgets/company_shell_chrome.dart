import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../pages/notifications_page.dart';
import 'client_profile_avatar_icon.dart';
import 'notification_bell_button.dart';

class CompanyHeader extends StatelessWidget implements PreferredSizeWidget {
  const CompanyHeader({
    super.key,
    required this.companyName,
    this.onOpenProfile,
    this.onLogout,
    this.trailing,
  });

  final String companyName;
  final VoidCallback? onOpenProfile;
  final Future<void> Function()? onLogout;
  final Widget? trailing;

  void _openNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  Future<void> _openProfileMenu(
    BuildContext context,
    GlobalKey anchorKey,
  ) async {
    if (anchorKey.currentContext == null) return;

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox box =
        anchorKey.currentContext!.findRenderObject() as RenderBox;
    final Offset topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset bottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    const double verticalGap = 8;

    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTRB(
          topLeft.dx,
          bottomRight.dy + verticalGap,
          bottomRight.dx,
          bottomRight.dy + verticalGap,
        ),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      color: Colors.white,
      items: [
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 20, color: AppColors.blackCat),
              SizedBox(width: 10),
              Text(
                'Log out',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackCat,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (choice == 'logout') {
      await onLogout?.call();
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(85);

  @override
  Widget build(BuildContext context) {
    final GlobalKey profileKey = GlobalKey();

    return Container(
      color: AppColors.alabaster,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Stack(
            children: [
              Center(
                child: Image.asset(
                  'assets/images/jnt_logo_black.png',
                  height: 50,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(width: 40, height: 40),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 44,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: NotificationBellButton(
                      onTap: () => _openNotifications(context),
                      iconSize: 24,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 44,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child:
                        trailing ??
                        InkWell(
                          key: profileKey,
                          borderRadius: BorderRadius.zero,
                          onTap: () => _openProfileMenu(context, profileKey),
                          child: SizedBox(
                            height: 36,
                            width: 36,
                            child: ClipRRect(
                              borderRadius: BorderRadius.zero,
                              child: _CompanyAvatarIcon(
                                companyName: companyName,
                              ),
                            ),
                          ),
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanyAvatarIcon extends StatelessWidget {
  const _CompanyAvatarIcon({required this.companyName});

  final String companyName;

  String _firstNonEmpty(List<dynamic> values) {
    for (final raw in values) {
      final value = (raw ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Future<String> _resolveCompanyStorageAvatar(String uid) async {
    final candidates = <String>[
      'company/$uid/profile/avatar.jpg',
      'company/$uid/profile/avatar.jpeg',
      'company/$uid/profile/avatar.png',
      'company/$uid/profile/avatar.webp',
      'company/$uid/profile/logo.jpg',
      'company/$uid/profile/logo.jpeg',
      'company/$uid/profile/logo.png',
      'company/$uid/profile/logo.webp',
    ];
    for (final path in candidates) {
      try {
        await FirebaseStorage.instance.ref(path).getMetadata();
        return path;
      } catch (_) {}
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final uid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (uid.isEmpty) {
      return ClientProfileAvatarIcon(displayName: companyName, size: 36);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('company')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
        final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};
        final company = (data['company'] as Map<String, dynamic>?) ?? const {};
        final imageUrl = _firstNonEmpty([
          profile['logoUrl'],
          profile['profileImageUrl'],
          profile['photoUrl'],
          profile['avatarUrl'],
          basic['profileImageUrl'],
          basic['photoUrl'],
          basic['avatarUrl'],
          data['panel_logoUrl'],
          data['companyLogoUrl'],
          data['brandLogoUrl'],
          data['logoUrl'],
          data['panel_profileImageUrl'],
          data['profileImageUrl'],
          data['photoUrl'],
          data['avatarUrl'],
          company['logoUrl'],
          company['profileImageUrl'],
          company['photoUrl'],
          company['avatarUrl'],
        ]);
        final resolvedImageUrl = imageUrl.trim();
        if (resolvedImageUrl.isNotEmpty) {
          return ClientProfileAvatarIcon(
            imageUrl: resolvedImageUrl,
            displayName: companyName,
            size: 36,
          );
        }
        return FutureBuilder<String>(
          future: _resolveCompanyStorageAvatar(uid),
          builder: (context, storageSnap) {
            final storagePath = (storageSnap.data ?? '').trim();
            return ClientProfileAvatarIcon(
              imageUrl: storagePath,
              displayName: companyName,
              size: 36,
            );
          },
        );
      },
    );
  }
}

class CompanyBottomNav extends StatelessWidget {
  const CompanyBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: AppColors.balletSlippers,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.deepPlum,
      unselectedItemColor: Colors.black.withValues(alpha: 0.55),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          activeIcon: Icon(Icons.add_circle),
          label: 'Design',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.brush_outlined),
          activeIcon: Icon(Icons.brush),
          label: 'Artists',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
