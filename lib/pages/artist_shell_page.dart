import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';

import 'artist_requests_page_redesign.dart';
import 'artist_calendar_page.dart';
import 'artist_earnings_page.dart';
import 'artist_profile_page.dart';
import 'artist_inbox_page.dart';
import 'artist_history_page.dart';
import 'notifications_page.dart';
// ✅ use your existing history page (currently ArtistOrdersPage)

// ✅ reuse your existing model
import '../models/artist_request_legacy_models.dart'
    show ClientRequest, NailDimensions, RequestStatus;

class ArtistShellPage extends StatefulWidget {
  const ArtistShellPage({super.key});

  @override
  State<ArtistShellPage> createState() => _ArtistShellPageState();
}

class _ArtistShellPageState extends State<ArtistShellPage> {
  int _index = 0; // Default: Requests
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
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final sampleRequests = <ClientRequest>[
      ClientRequest(
        id: 'REQ-1001',
        clientName: 'Mia',
        title: 'Chrome French',
        subtitle: 'White tips + chrome',
        neededBy: DateTime.now().add(const Duration(days: 2)),
        budgetMin: 80,
        budgetMax: 110,
        nailShape: 'Square',
        nailLength: 'Short',
        bio: 'Clean and minimal.',
        leftHand: const NailDimensions(
          thumb: "17mm",
          index: "13mm",
          middle: "14mm",
          ring: "13mm",
          pinky: "9mm",
        ),
        rightHand: const NailDimensions(
          thumb: "17mm",
          index: "13mm",
          middle: "14mm",
          ring: "13mm",
          pinky: "9mm",
        ),
        images: const [],
        status: RequestStatus.accepted,
        isDirectRequest: false,
        estimatedShipDays: 2,
      ),
      ClientRequest(
        id: 'REQ-1002',
        clientName: 'Alex',
        title: 'Hailey Bieber & Rihanna',
        subtitle: 'Inspo Nails',
        neededBy: DateTime.now().add(const Duration(days: 6)),
        budgetMin: 120,
        budgetMax: 140,
        nailShape: 'Almond',
        nailLength: 'Medium',
        bio: 'Soft glam, pearl accents, prefer neutral tones.',
        leftHand: const NailDimensions(
          thumb: "18mm",
          index: "14mm",
          middle: "15mm",
          ring: "14mm",
          pinky: "10mm",
        ),
        rightHand: const NailDimensions(
          thumb: "18mm",
          index: "14mm",
          middle: "15mm",
          ring: "14mm",
          pinky: "10mm",
        ),
        images: const [
          'assets/images/nail_design_1.png',
          'assets/images/nail_design_2.png',
          'assets/images/nail_design_3.png',
        ],
        status: RequestStatus.newRequest,
        isDirectRequest: true,
        estimatedShipDays: 3,
      ),
    ];

    final pages = <Widget>[
      ArtistRequestsPageRedesign(
        initialBudgetMin: 80,
        initialBudgetMax: 150,
        artistLocation: 'Los Angeles, CA',
        onOpenNotifications: _openNotifications,
        onManageProfile: _openProfilePage,
        onOpenInbox: _openInbox,
        onSignOut: () => _signOut(),
      ),

      ArtistCalendarPage(
        requests: sampleRequests,
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

      // ✅ Earnings tab
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
        selectedItemColor: AppColors.deepPlum,
        unselectedItemColor: Colors.black.withOpacity(0.55),
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
