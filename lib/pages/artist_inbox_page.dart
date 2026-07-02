// lib/pages/artist_inbox_page.dart
import 'package:flutter/material.dart';
import '../models/client_profile_models.dart';
import '../theme/app_colors.dart';
import 'client_artist_profile_page.dart';
import 'notifications_page.dart';
import '../widgets/artist_profile_avatar_icon.dart';
import '../widgets/jnt_standard_app_bar.dart';
import '../widgets/notification_bell_button.dart';

class ArtistInboxPage extends StatefulWidget {
  const ArtistInboxPage({
    super.key,
    this.onOpenNotifications,
    this.onManageProfile,
    this.onSignOut,
  });

  final VoidCallback? onOpenNotifications;
  final VoidCallback? onManageProfile;
  final VoidCallback? onSignOut;

  @override
  State<ArtistInboxPage> createState() => _ArtistInboxPageState();
}

class _ArtistInboxPageState extends State<ArtistInboxPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openChat(_ChatThread t) {
    // Hook your real chat screen here later.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Open chat with ${t.name}')));
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _samplePinned();
    final fresh = _sampleNew();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),

      // ✅ Header matches your other pages: logo + notifications + avatar dropdown
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(JntHeaderMetrics.toolbarHeight),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/jnt_logo_1.png',
                  height: JntHeaderMetrics.logoHeight,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(width: 40, height: 40),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Inbox',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.blackCat.withValues(alpha: 0.90),
                      ),
                    ),
                  ),
                ),
                NotificationBellButton(
                  onTap:
                      widget.onOpenNotifications ??
                      () {
                        NotificationsPage.showAsModal(context);
                      },
                  iconSize: JntHeaderMetrics.notificationIconSize,
                ),
                const SizedBox(width: 6),
                _AvatarMenu(
                  onManageProfile:
                      widget.onManageProfile ??
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientArtistProfilePage(
                              initialProfile: ClientProfileDraft(
                                basic: const BasicInfo(
                                  name: '',
                                  email: '',
                                  phone: '',
                                ),
                                address: const AddressInfo(
                                  street: '',
                                  city: '',
                                  state: '',
                                  zip: '',
                                  country: 'United States',
                                ),
                                payment: const PaymentInfo(
                                  method: PaymentMethod.applePay,
                                  saveForFuture: false,
                                ),
                                nail: NailPreferences.empty(),
                              ),
                            ),
                          ),
                        );
                      },
                  onSignOut:
                      widget.onSignOut ??
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Sign out tapped (hook auth sign out)',
                            ),
                          ),
                        );
                      },
                ),
              ],
            ),
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        children: [
          _SearchBar(controller: _searchCtrl),

          const SizedBox(height: 12),

          _TopTabs(controller: _tabCtrl),

          const SizedBox(height: 12),

          // Content for both tabs (same style, different data filter later)
          TabBarView(
            controller: _tabCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _InboxList(
                pinned: pinned,
                newThreads: fresh,
                onTapThread: _openChat,
              ),
              _InboxList(
                pinned: pinned.take(1).toList(),
                newThreads: fresh.take(3).toList(),
                onTapThread: _openChat,
                showRecentRequestsLabel: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_ChatThread> _samplePinned() => const [
    _ChatThread(
      name: 'Mary',
      message: 'Perfect! See you then.',
      time: 'Thu 2:30 PM',
      avatarAsset: 'assets/images/profile_placeholder.png',
      pinned: true,
    ),
    _ChatThread(
      name: 'Natalie',
      message: "Got it, I’ll mark it down for 5...",
      time: 'Wed 9:12 AM',
      avatarAsset: 'assets/images/profile_placeholder.png',
      pinned: true,
    ),
  ];

  List<_ChatThread> _sampleNew() => const [
    _ChatThread(
      name: 'Esther',
      message: 'Sounds good, Jules! 😊',
      time: 'Thu 6:32 PM',
      avatarAsset: 'assets/images/profile_placeholder.png',
      unread: true,
    ),
    _ChatThread(
      name: 'Mia',
      message: 'Omg, I love it! 😍😍',
      time: 'Thu 5:50 PM',
      avatarAsset: 'assets/images/profile_placeholder.png',
      unread: true,
    ),
    _ChatThread(
      name: 'Hannah',
      message: 'Sent a photo',
      time: 'Thu 1:10 PM',
      avatarAsset: 'assets/images/profile_placeholder.png',
      hasPhoto: true,
    ),
    _ChatThread(
      name: 'Leah',
      message: "Wow, can't wait to see!",
      time: 'Thu 10:02 AM',
      avatarAsset: 'assets/images/profile_placeholder.png',
    ),
    _ChatThread(
      name: 'Booking Alert',
      message: 'Your 1PM appointment with Nat...',
      time: 'Wed 6:35 PM',
      system: true,
      systemIcon: Icons.calendar_month_rounded,
      expandedChevron: true,
    ),
    _ChatThread(
      name: 'Esther',
      message: 'Thu 5:50 PM, to ending *3421',
      time: 'Thu 6:32 PM',
      avatarAsset: 'assets/images/profile_placeholder.png',
      unread: true,
    ),
    _ChatThread(
      name: 'Hannah',
      message: 'Sent a photo',
      time: 'Thu 1:10 PM',
      avatarAsset: 'assets/images/profile_placeholder.png',
      hasPhoto: true,
    ),
    _ChatThread(
      name: 'Leah',
      message: 'Wed, Apr 3',
      time: 'Thu 10:02 AM',
      avatarAsset: 'assets/images/profile_placeholder.png',
    ),
  ];
}

// ======================
// Top search bar
// ======================
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.blackCat.withValues(alpha: 0.35)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search or start a new message...',
                hintStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================
// Tabs row like screenshot
// ======================
class _TopTabs extends StatelessWidget {
  const _TopTabs({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: TabBar(
        controller: controller,
        indicatorColor: AppColors.blackCat,
        indicatorWeight: 3,
        labelColor: AppColors.blackCat.withValues(alpha: 0.88),
        unselectedLabelColor: AppColors.blackCat.withValues(alpha: 0.45),
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Recent requests'),
        ],
      ),
    );
  }
}

// ======================
// Inbox list sections
// ======================
class _InboxList extends StatelessWidget {
  const _InboxList({
    required this.pinned,
    required this.newThreads,
    required this.onTapThread,
    this.showRecentRequestsLabel = false,
  });

  final List<_ChatThread> pinned;
  final List<_ChatThread> newThreads;
  final void Function(_ChatThread t) onTapThread;
  final bool showRecentRequestsLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),

        Text(
          'Pinned conversations',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.blackCat.withValues(alpha: 0.45),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        _CardList(
          children: pinned
              .map((t) => _ThreadRow(thread: t, onTap: () => onTapThread(t)))
              .toList(),
        ),

        const SizedBox(height: 16),

        Text(
          showRecentRequestsLabel ? 'Recent requests' : 'New',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.blackCat.withValues(alpha: 0.45),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        _CardList(
          children: newThreads
              .map((t) => _ThreadRow(thread: t, onTap: () => onTapThread(t)))
              .toList(),
        ),
      ],
    );
  }
}

class _CardList extends StatelessWidget {
  const _CardList({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(children: _withDividers(children)),
    );
  }

  List<Widget> _withDividers(List<Widget> items) {
    final out = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(Divider(height: 1, color: AppColors.blackCat.withValues(alpha: 0.06)));
      }
    }
    return out;
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.thread, required this.onTap});
  final _ChatThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nameStyle = TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: 16,
      color: AppColors.blackCat.withValues(alpha: 0.90),
    );

    final msgStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 14,
      color: AppColors.blackCat.withValues(alpha: 0.55),
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            _Avatar(thread: thread),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: nameStyle,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (thread.hasPhoto)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.photo_camera_rounded,
                            size: 16,
                            color: AppColors.blackCat.withValues(alpha: 0.55),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          thread.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: msgStyle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      thread.time,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.blackCat.withValues(alpha: 0.45),
                      ),
                    ),
                    if (thread.pinned) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: AppColors.blackCat.withValues(alpha: 0.45),
                      ),
                    ],
                    if (thread.expandedChevron) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.blackCat.withValues(alpha: 0.55),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _RightDot(thread: thread),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RightDot extends StatelessWidget {
  const _RightDot({required this.thread});
  final _ChatThread thread;

  @override
  Widget build(BuildContext context) {
    if (thread.system) return const SizedBox(height: 10);

    if (thread.unread) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.blackCat,
          shape: BoxShape.circle,
        ),
      );
    }

    // subtle hollow dot like screenshot rows
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.18)),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.thread});
  final _ChatThread thread;

  @override
  Widget build(BuildContext context) {
    if (thread.system) {
      return Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: AppColors.blackCat.withValues(alpha: 0.12),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.snow, width: 2),
        ),
        alignment: Alignment.center,
        child: Icon(
          thread.systemIcon ?? Icons.notifications_rounded,
          color: AppColors.blackCat.withValues(alpha: 0.75),
        ),
      );
    }

    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.blackCat.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.snow, width: 2),
      ),
      child: ClipOval(
        child: Image.asset(
          thread.avatarAsset ?? 'assets/images/profile_placeholder.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Center(
            child: Text(
              thread.name.isEmpty ? 'U' : thread.name[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================
// Avatar dropdown menu
// ======================
class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({required this.onManageProfile, required this.onSignOut});

  final VoidCallback onManageProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AvatarAction>(
      tooltip: '',
      position: PopupMenuPosition.under,
      elevation: 12,
      color: AppColors.snow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      onSelected: (v) {
        switch (v) {
          case _AvatarAction.manageProfile:
            onManageProfile();
            break;
          case _AvatarAction.inbox:
            break;
          case _AvatarAction.signOut:
            onSignOut();
            break;
        }
      },
      child: SizedBox(
        height: JntHeaderMetrics.avatarSize,
        width: JntHeaderMetrics.avatarSize,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: const ArtistProfileAvatarIcon(size: JntHeaderMetrics.avatarSize),
        ),
      ),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _AvatarAction.manageProfile,
          child: _MenuRow(
            icon: Icons.manage_accounts_outlined,
            label: 'Manage profile',
          ),
        ),
        PopupMenuItem(
          value: _AvatarAction.inbox,
          child: _MenuRow(icon: Icons.inbox_outlined, label: 'Inbox'),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _AvatarAction.signOut,
          child: _MenuRow(icon: Icons.logout_rounded, label: 'Logout'),
        ),
      ],
    );
  }
}

enum _AvatarAction { manageProfile, inbox, signOut }

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.blackCat.withValues(alpha: 0.70)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
    );
  }
}

// ======================
// Model
// ======================
class _ChatThread {
  final String name;
  final String message;
  final String time;

  final bool pinned;
  final bool unread;
  final bool hasPhoto;

  final bool system;
  final IconData? systemIcon;
  final bool expandedChevron;

  final String? avatarAsset;

  const _ChatThread({
    required this.name,
    required this.message,
    required this.time,
    this.avatarAsset,
    this.pinned = false,
    this.unread = false,
    this.hasPhoto = false,
    this.system = false,
    this.systemIcon,
    this.expandedChevron = false,
  });
}

