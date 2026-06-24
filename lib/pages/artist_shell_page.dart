import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_auth_service.dart';
import '../theme/app_colors.dart';

import 'artist_requests_page_redesign.dart';
import 'artist_calendar_page.dart';
import 'artist_earnings_page.dart';
import 'artist_profile_page.dart';
import 'artist_inbox_page.dart';
import 'artist_history_page.dart';
import 'notifications_page.dart';

import '../models/artist_request_legacy_models.dart'
    show ClientRequest;

class ArtistShellPage extends StatefulWidget {
  const ArtistShellPage({super.key});

  @override
  State<ArtistShellPage> createState() => _ArtistShellPageState();
}

class _ArtistShellPageState extends State<ArtistShellPage> {
  int _index = 0;

  String _artistLocation = '';
  int _budgetMin = 15;
  int _budgetMax = 5000;

  @override
  void initState() {
    super.initState();
    _loadArtistProfile();
  }

  Future<void> _loadArtistProfile() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await Supabase.instance.client
          .from('artist')
          .select('profile, pricing')
          .eq('id', uid)
          .maybeSingle();
      if (row == null || !mounted) return;
      final profile = (row['profile'] as Map<String, dynamic>?) ?? {};
      final pricing = (row['pricing'] as Map<String, dynamic>?) ?? {};
      final city = (profile['city'] as String? ?? '').trim();
      final state = (profile['state'] as String? ?? '').trim();
      final minPrice =
          int.tryParse(pricing['minPrice']?.toString() ?? '') ?? 15;
      final maxPrice =
          int.tryParse(pricing['maxPrice']?.toString() ?? '') ?? 5000;
      if (!mounted) return;
      setState(() {
        _artistLocation =
            [city, state].where((s) => s.isNotEmpty).join(', ');
        _budgetMin = minPrice;
        _budgetMax = maxPrice;
      });
    } catch (_) {
      // silently keep defaults
    }
  }

  void _goToTab(int i) => setState(() => _index = i);

  void _openNotifications() {
    NotificationsPage.showAsModal(context);
  }

  void _openProfilePage() => _goToTab(4);

  void _openInbox() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArtistInboxPage()),
    );
  }

  Future<void> _signOut() async {
    await SupabaseAuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ArtistRequestsPageRedesign(
        initialBudgetMin: _budgetMin,
        initialBudgetMax: _budgetMax,
        artistLocation: _artistLocation,
        onOpenNotifications: _openNotifications,
        onManageProfile: _openProfilePage,
        onOpenInbox: _openInbox,
        onSignOut: () => _signOut(),
      ),

      ArtistCalendarPage(
        requests: const <ClientRequest>[],
        onOpenNotifications: _openNotifications,
        onManageProfile: _openProfilePage,
        onOpenInbox: _openInbox,
        onSignOut: () => _signOut(),
      ),

      ArtistHistoryPage(
        onBackHome: () => setState(() => _index = 0),
        onOpenNotifications: _openNotifications,
        onManageProfile: _openProfilePage,
        onOpenInbox: _openInbox,
        onSignOut: () => _signOut(),
      ),

      ArtistEarningsPage(
        onOpenNotifications: _openNotifications,
        onManageProfile: _openProfilePage,
        onOpenInbox: _openInbox,
        onSignOut: () => _signOut(),
      ),

      ArtistProfilePage(
        showBottomNav: false,
        bottomNavIndex: 4,
        onNavTap: _goToTab,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.snow,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _goToTab,
        backgroundColor: AppColors.balletSlippers,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.blackCat,
        unselectedItemColor: AppColors.blackCat.withValues(alpha: 0.55),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            activeIcon: Icon(Icons.inbox),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money_outlined),
            activeIcon: Icon(Icons.attach_money),
            label: 'Earnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
