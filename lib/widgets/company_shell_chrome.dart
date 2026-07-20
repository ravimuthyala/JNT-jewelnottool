import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../pages/notifications_page.dart';
import 'client_profile_avatar_icon.dart';
import 'jnt_standard_app_bar.dart';

class CompanyHeader extends StatelessWidget implements PreferredSizeWidget {
  const CompanyHeader({
    super.key,
    required this.companyName,
    this.imageUrl = '',
    this.onOpenProfile,
    this.onLogout,
    this.trailing,
  });

  final String companyName;
  final String imageUrl;
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
  Size get preferredSize =>
      const Size.fromHeight(JntHeaderMetrics.toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final GlobalKey profileKey = GlobalKey();

    return JntStandardAppBar(
      onNotifications: () => _openNotifications(context),
      trailing:
          trailing ??
          Semantics(
            button: true,
            label: 'Account menu for $companyName',
            onTap: () => _openProfileMenu(context, profileKey),
            child: ExcludeSemantics(
              child: InkWell(
                key: profileKey,
                borderRadius: BorderRadius.zero,
                onTap: () => _openProfileMenu(context, profileKey),
                child: SizedBox(
                  height: JntHeaderMetrics.avatarSize,
                  width: JntHeaderMetrics.avatarSize,
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: _CompanyAvatarIcon(
                      companyName: companyName,
                      imageUrl: imageUrl,
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

class _CompanyAvatarIcon extends StatefulWidget {
  const _CompanyAvatarIcon({
    required this.companyName,
    this.imageUrl = '',
  });

  final String companyName;
  final String imageUrl;

  @override
  State<_CompanyAvatarIcon> createState() => _CompanyAvatarIconState();
}

class _CompanyAvatarIconState extends State<_CompanyAvatarIcon> {
  String _avatarUrl = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _avatarUrl = _normalizeStorageUrl(widget.imageUrl);
    _loadCompanyAvatar();
  }

  @override
  void didUpdateWidget(covariant _CompanyAvatarIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.companyName != widget.companyName) {
      _avatarUrl = _normalizeStorageUrl(widget.imageUrl);
      _loading = true;
      _loadCompanyAvatar();
    }
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final raw in values) {
      final value = (raw ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _normalizeStorageUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    if (text.startsWith('http://') || text.startsWith('https://')) return text;
    if (text.startsWith('data:image/')) return text;

    final storage = Supabase.instance.client.storage.from('company-logos');
    if (text.startsWith('company-logos/')) {
      return storage
          .getPublicUrl(text.substring('company-logos/'.length))
          .trim();
    }
    if (text.startsWith('companies/')) {
      return storage.getPublicUrl(text).trim();
    }
    if (text.startsWith('company/')) {
      try {
        return storage.getPublicUrl(text).trim();
      } catch (_) {
        return '';
      }
    }
    return '';
  }

  Future<Map<String, dynamic>?> _readCompanyRow() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final uid = (user?.id ?? '').trim();
    final email = (user?.email ?? '').trim().toLowerCase();

    if (uid.isNotEmpty) {
      try {
        final rows = await supabase
            .from('company')
            .select()
            .eq('id', uid)
            .limit(1);
        if (rows.isNotEmpty) {
          return Map<String, dynamic>.from(rows.first as Map);
        }
      } catch (_) {}
    }

    if (email.isNotEmpty) {
      try {
        final rows = await supabase
            .from('company')
            .select()
            .eq('email', email)
            .limit(1);
        if (rows.isNotEmpty) {
          return Map<String, dynamic>.from(rows.first as Map);
        }
      } catch (_) {}
    }

    return null;
  }

  Future<String> _resolveCompanyStorageAvatar(String uid) async {
    final storage = Supabase.instance.client.storage.from('company-logos');
    try {
      final entries = await storage.list(path: 'companies/$uid/logo');
      final files = entries
          .map((file) => file.name.trim())
          .where((name) => name.isNotEmpty)
          .where(
            (name) =>
                name.toLowerCase().endsWith('.jpg') ||
                name.toLowerCase().endsWith('.jpeg') ||
                name.toLowerCase().endsWith('.png') ||
                name.toLowerCase().endsWith('.webp'),
          )
          .toList(growable: false);
      if (files.isEmpty) return '';
      files.sort((a, b) => b.compareTo(a));
      return storage.getPublicUrl('companies/$uid/logo/${files.first}').trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> _loadCompanyAvatar() async {
    try {
      final seededImageUrl = _normalizeStorageUrl(widget.imageUrl);
      if (seededImageUrl.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _avatarUrl = seededImageUrl;
          _loading = false;
        });
        return;
      }


      final row = await _readCompanyRow();
      final data = row ?? const <String, dynamic>{};
      final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
      final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};
      final company = (data['company'] as Map<String, dynamic>?) ?? const {};
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      final uid = (user?.id ?? '').trim();

      final imageUrl = _normalizeStorageUrl(
        _firstNonEmpty([
          data['panel_logoUrl'],
          data['companyLogoUrl'],
          data['brandLogoUrl'],
          data['logoUrl'],
          data['panel_profileImageUrl'],
          data['profileImageUrl'],
          data['photoUrl'],
          data['avatarUrl'],
          profile['logoUrl'],
          profile['profileImageUrl'],
          profile['photoUrl'],
          profile['avatarUrl'],
          basic['profileImageUrl'],
          basic['photoUrl'],
          basic['avatarUrl'],
          company['logoUrl'],
          company['profileImageUrl'],
          company['photoUrl'],
          company['avatarUrl'],
        ]),
      );

      final resolved = imageUrl.isNotEmpty
          ? imageUrl
          : uid.isNotEmpty
          ? await _resolveCompanyStorageAvatar(uid)
          : '';

      if (!mounted) return;
      setState(() {
        _avatarUrl = resolved;
        _loading = false;
      });
    } catch (e) {
      debugPrint('COMPANY AVATAR LOAD FAILED: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _avatarUrl.trim().isEmpty) {
      return ClientProfileAvatarIcon(
        displayName: widget.companyName,
        size: JntHeaderMetrics.avatarSize,
      );
    }

    return ClientProfileAvatarIcon(
      imageUrl: _avatarUrl,
      displayName: widget.companyName,
      size: JntHeaderMetrics.avatarSize,
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
