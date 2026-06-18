import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'notifications_page.dart';
import '../widgets/notification_bell_button.dart';

// ✅ Use your existing page
import 'client_custom_request_page.dart';

// ✅ Needed to pass a profile object to ClientCustomRequestPage
import '../models/client_profile_models.dart';

class ClientArtistHomePageWithKitPurchase extends StatelessWidget {
  const ClientArtistHomePageWithKitPurchase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),

      // -----------------------
      // HEADER
      // -----------------------
      appBar: AppBar(
        backgroundColor: AppColors.alabaster,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        leading: NotificationBellButton(
          onTap: () => NotificationsPage.showAsModal(context),
          iconSize: 24,
        ),
        titleSpacing: 16,
        title: Row(
          children: [
            // JNT Logo placeholder
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: AppColors.blackCat.withValues(alpha: 0.12),
                borderRadius: BorderRadius.zero,
              ),
              alignment: Alignment.center,
              child: const Text(
                "JNT",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Welcome",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.zero,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.blackCat.withValues(alpha: 0.08),
                child: Icon(
                  Icons.person_outline,
                  color: AppColors.blackCat.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ],
      ),

      // -----------------------
      // BODY
      // -----------------------
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          children: [
            // -----------------------
            // Artist Overview
            // -----------------------
            _sectionTitle("Artist Overview"),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _miniStatCard(
                    title: "New Requests",
                    value: "3",
                    icon: Icons.mark_email_unread_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _miniStatCard(
                    title: "In Progress",
                    value: "2",
                    icon: Icons.timelapse_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniStatCard(
                    title: "Inbox",
                    value: "5",
                    icon: Icons.inbox_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _miniStatCard(
                    title: "Earnings",
                    value: "\$240",
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // -----------------------
            // Trending Designs
            // -----------------------
            _sectionTitle("Trending Designs"),
            const SizedBox(height: 10),

            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _designCard(
                  artistName: i == 0
                      ? "Artist Mia"
                      : i == 1
                      ? "Artist Zoe"
                      : i == 2
                      ? "Artist Lana"
                      : "Artist Ava",
                ),
              ),
            ),

            const SizedBox(height: 18),

            // -----------------------
            // Delivered Orders
            // -----------------------
            _sectionTitle("Delivered Orders"),
            const SizedBox(height: 10),

            _listTileCard(
              title: "Order #1042",
              subtitle: "Delivered • Feb 02",
              trailing: "\$85",
            ),
            const SizedBox(height: 10),
            _listTileCard(
              title: "Order #1039",
              subtitle: "Delivered • Jan 29",
              trailing: "\$60",
            ),

            const SizedBox(height: 18),

            // -----------------------
            // Recent Requests
            // -----------------------
            _sectionTitle("Recent Requests"),
            const SizedBox(height: 10),

            _listTileCard(
              title: "Custom Set Request",
              subtitle: "Requested • Feb 04",
              trailing: "View",
              trailingIsButton: true,
            ),
            const SizedBox(height: 10),
            _listTileCard(
              title: "Nail Art Request",
              subtitle: "Requested • Feb 01",
              trailing: "View",
              trailingIsButton: true,
            ),
          ],
        ),
      ),

      // -----------------------
      // FOOTER NAV (ALL ENABLED)
      // -----------------------
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.blackCat,
        unselectedItemColor: AppColors.blackCat.withValues(alpha: 0.35),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        currentIndex: 0,
        onTap: (i) {
          // ✅ Design tab -> ClientCustomRequestPage
          if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClientCustomRequestPage(
                  profile: ClientProfileDraft.mock(),
                  onBackHome: () => Navigator.pop(context),
                ),
              ),
            );
            return;
          }

          // Optional: placeholders for other tabs
          // if (i == 0) return; // already home
          // else if (i == 2) { ... }
          // else if (i == 3) { ... }
          // else if (i == 4) { ... }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: "Design",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            label: "Requests",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            label: "Calendar",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
    );
  }

  // -----------------------
  // Widgets
  // -----------------------

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
    );
  }

  Widget _miniStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppColors.blackCat.withValues(alpha: 0.10),
              borderRadius: BorderRadius.zero,
            ),
            child: Icon(icon, color: AppColors.deepPlum),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackCat.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _designCard({required String artistName}) {
    final fallbackLetter = artistName.trim().isEmpty
        ? 'A'
        : artistName.trim().substring(0, 1).toUpperCase();
    return Container(
      width: 170,
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Container(
              height: 150,
              width: double.infinity,
              color: AppColors.blackCat.withValues(alpha: 0.06),
              child: Icon(
                Icons.image,
                color: AppColors.blackCat.withValues(alpha: 0.25),
                size: 40,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              children: [
                Container(
                  height: 22,
                  width: 22,
                  decoration: BoxDecoration(
                    color: AppColors.balletSlippers,
                    borderRadius: BorderRadius.zero,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    fallbackLetter,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.blackCat,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listTileCard({
    required String title,
    required String subtitle,
    required String trailing,
    bool trailingIsButton = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.blackCat.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          if (trailingIsButton)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.blackCat.withValues(alpha: 0.12),
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                trailing,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.blackCat,
                  fontSize: 12,
                ),
              ),
            )
          else
            Text(
              trailing,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: Color(0xFFF06C7A),
              ),
            ),
        ],
      ),
    );
  }
}
