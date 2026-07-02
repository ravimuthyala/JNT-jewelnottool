import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ambassador_role_service.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/jnt_standard_app_bar.dart';
import '../models/client_profile_models.dart';
import '../theme/app_colors.dart';
import 'client_artist_earnings_page.dart';
import 'client_artist_artist_page.dart';
import 'client_artist_calendar_page.dart';
import 'client_artist_home_page.dart';
import 'client_artist_profile_page.dart';

class ClientArtistHistoryPage extends StatefulWidget {
  const ClientArtistHistoryPage({
    super.key,
    required this.profile,
    required this.showContinueProfileCard,
    required this.enableAllTabs,
    this.onOpenProfile,
    this.onLogout,
  });

  final ClientProfileDraft profile;
  final bool showContinueProfileCard;
  final bool enableAllTabs;
  final VoidCallback? onOpenProfile;
  final Future<void> Function()? onLogout;

  @override
  State<ClientArtistHistoryPage> createState() => _ClientArtistHistoryPageState();
}

class _ClientArtistHistoryPageState extends State<ClientArtistHistoryPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _loading = true;
  List<_HistoryItem> _brandRequests = const <_HistoryItem>[];
  List<_HistoryItem> _clientRequests = const <_HistoryItem>[];
  String _filter = 'all';
  bool _showCampaignsTab = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCampaignVisibility());
    unawaited(_loadHistory());
  }

  Future<void> _loadCampaignVisibility() async {
    final show = await AmbassadorRoleService.currentUserIsAmbassador(
      fallbackEmail: widget.profile.basic.email,
    );
    if (!mounted) return;
    setState(() => _showCampaignsTab = show);
  }

  String get _viewerEmail => (_supabase.auth.currentUser?.email ?? widget.profile.basic.email).trim().toLowerCase();
  String get _viewerId => (_supabase.auth.currentUser?.id ?? '').trim();

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return value.map((key, value) => MapEntry(key.toString(), value));
    return const <String, dynamic>{};
  }

  String _firstNonEmpty(List<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.tryParse((value ?? '').toString());
  }

  Future<List<Map<String, dynamic>>> _safeQuery(String table) async {
    try {
      final rows = await _supabase.from(table).select();
      return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  bool _matchesCurrentUser(Map<String, dynamic> data) {
    final details = _asMap(data['details']);
    final summary = _asMap(data['summary']);
    final requestDetails = _asMap(details['requestDetails']);
    final payload = _asMap(details['payload']);

    final clientEmails = <String>{
      _firstNonEmpty([data['client_email'], data['clientEmail']]).toLowerCase(),
      _firstNonEmpty([data['accepted_by_client_email'], data['acceptedByClientEmail']]).toLowerCase(),
      _firstNonEmpty([summary['clientEmail']]).toLowerCase(),
      _firstNonEmpty([requestDetails['clientEmail']]).toLowerCase(),
      _firstNonEmpty([payload['clientEmail']]).toLowerCase(),
    }..remove('');

    final artistOwnerEmails = <String>{
      _firstNonEmpty([data['accepted_by_artist_email'], data['acceptedByArtistEmail']]).toLowerCase(),
      _firstNonEmpty([summary['acceptedByArtistEmail']]).toLowerCase(),
      _firstNonEmpty([requestDetails['acceptedByArtistEmail']]).toLowerCase(),
      _firstNonEmpty([payload['acceptedByArtistEmail']]).toLowerCase(),
    }..remove('');

    final clientIds = <String>{
      _firstNonEmpty([data['client_id'], data['clientId']]),
      _firstNonEmpty([data['created_by_uid'], data['createdByUid']]),
      _firstNonEmpty([summary['clientId']]),
      _firstNonEmpty([requestDetails['clientId']]),
      _firstNonEmpty([payload['clientId']]),
    }..remove('');

    final artistOwnerIds = <String>{
      _firstNonEmpty([data['accepted_by_artist_id'], data['acceptedByArtistId']]),
      _firstNonEmpty([summary['acceptedByArtistId']]),
      _firstNonEmpty([requestDetails['acceptedByArtistId']]),
      _firstNonEmpty([payload['acceptedByArtistId']]),
    }..remove('');

    return (_viewerEmail.isNotEmpty &&
            (clientEmails.contains(_viewerEmail) || artistOwnerEmails.contains(_viewerEmail))) ||
        (_viewerId.isNotEmpty &&
            (clientIds.contains(_viewerId) || artistOwnerIds.contains(_viewerId)));
  }

  _HistoryItem _mapItem(Map<String, dynamic> data, {required bool brand}) {
    final details = _asMap(data['details']);
    final payload = _asMap(details['payload']);
    final summary = _asMap(data['summary']);
    final status = _firstNonEmpty([
      data['status'],
      payload['status'],
      summary['status'],
    ], fallback: 'pending').toLowerCase();
    final date = _parseDate(_firstNonEmpty([
      data['declined_at'], data['declinedAt'], data['cancelled_at'], data['cancelledAt'], data['updated_at'], data['created_at'], data['createdAt']
    ]));
    final name = brand
        ? _firstNonEmpty([data['company_name'], data['companyName'], data['brandName'], payload['companyName']], fallback: 'Brand Request')
        : _firstNonEmpty([data['client_name'], data['clientName'], payload['clientName'], summary['clientName']], fallback: 'Client Request');
    final title = _firstNonEmpty([data['campaign_name'], data['campaignName'], data['title'], payload['campaignName']], fallback: name);
    final image = _firstNonEmpty([
      data['preview_image'], data['previewImage'], data['clientProfileImage'], data['artistProfileImage'],
      payload['previewImage'], payload['inspirationPhotoUrl']
    ]);
    return _HistoryItem(title: title, subtitle: _statusSubtitle(status), status: _statusLabel(status), date: date, imageUrl: image);
  }

  String _statusLabel(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('declin') || v.contains('reject')) return 'Declined';
    if (v.contains('cancel')) return 'Cancelled';
    if (v.contains('expire')) return 'Expired';
    if (v.contains('deliver') || v.contains('ship')) return 'Delivered';
    return 'Active';
  }

  String _statusSubtitle(String raw) {
    final label = _statusLabel(raw);
    if (label == 'Declined') return 'Declined by artist';
    if (label == 'Cancelled') return 'Cancelled';
    if (label == 'Expired') return 'Expired';
    if (label == 'Delivered') return 'Delivered';
    return 'Active request';
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final clientRows = await _safeQuery('client_custom_requests');
    final brandRows = await _safeQuery('company_custom_requests');
    final matchedClient = clientRows.where(_matchesCurrentUser).map((e) => _mapItem(e, brand: false)).toList();
    final matchedBrand = brandRows.where(_matchesCurrentUser).map((e) => _mapItem(e, brand: true)).toList();
    int byDate(_HistoryItem a, _HistoryItem b) => (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970));
    matchedClient.sort(byDate);
    matchedBrand.sort(byDate);
    if (!mounted) return;
    setState(() {
      _clientRequests = matchedClient;
      _brandRequests = matchedBrand;
      _loading = false;
    });
  }

  List<_HistoryItem> _filtered(List<_HistoryItem> source) {
    if (_filter == 'all') return source;
    return source.where((e) => e.status.toLowerCase() == _filter).toList(growable: false);
  }

  int _count(String filter) {
    final all = <_HistoryItem>[..._brandRequests, ..._clientRequests];
    if (filter == 'all') return all.length;
    return all.where((e) => e.status.toLowerCase() == filter).length;
  }

  Future<void> _openProfile(BuildContext context) async {
    if (widget.onOpenProfile != null) {
      widget.onOpenProfile!.call();
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ClientArtistProfilePage(initialProfile: widget.profile)));
  }

  Future<void> _logout(BuildContext context) async {
    if (widget.onLogout != null) {
      await widget.onLogout!.call();
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _openHomeTab(BuildContext context, int index) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistHomePage(
          showContinueProfileCard: widget.showContinueProfileCard,
          enableAllTabs: widget.enableAllTabs,
          profile: widget.profile,
          initialTabIndex: index,
          onOpenProfile: widget.onOpenProfile,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  Future<void> _openCalendar(BuildContext context) async {
    await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ClientArtistCalendarPage(profile: widget.profile, showContinueProfileCard: widget.showContinueProfileCard, enableAllTabs: widget.enableAllTabs, onOpenProfile: widget.onOpenProfile, onLogout: widget.onLogout)));
  }

  Future<void> _openArtist(BuildContext context) async {
    await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ClientArtistArtistPage(profile: widget.profile, showContinueProfileCard: widget.showContinueProfileCard, enableAllTabs: widget.enableAllTabs, showCampaignsTab: _showCampaignsTab, onOpenProfile: widget.onOpenProfile, onOpenHistory: () {}, onOpenCalendar: () { _openCalendar(context); }, onLogout: widget.onLogout)));
  }

  Future<void> _openEarnings(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistEarningsPage(
          profile: widget.profile,
          showContinueProfileCard: widget.showContinueProfileCard,
          enableAllTabs: widget.enableAllTabs,
          showCampaignsTab: _showCampaignsTab,
          onOpenProfile: () => _openProfile(context),
          onLogout: () async {
            await _logout(context);
          },
        ),
      ),
    );
  }

  Future<void> _openReviews(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistReviewsPage(
          profile: widget.profile,
          showContinueProfileCard: widget.showContinueProfileCard,
          enableAllTabs: widget.enableAllTabs,
          showCampaignsTab: _showCampaignsTab,
          onOpenProfile: () => _openProfile(context),
          onLogout: () async {
            await _logout(context);
          },
        ),
      ),
    );
  }

  void _showAvatarMenu(BuildContext context) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(overlay.size.width - 270, 90, 20, 0),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      items: [
        const PopupMenuItem(value: 'profile', child: _MenuRow(icon: Icons.person_outline, label: 'Profile')),
        if (_showCampaignsTab)
          const PopupMenuItem(value: 'earnings', child: _MenuRow(icon: Icons.attach_money_outlined, label: 'Earnings')),
        const PopupMenuItem(value: 'history', child: _MenuRow(icon: Icons.history, label: 'History')),
        const PopupMenuItem(value: 'calendar', child: _MenuRow(icon: Icons.calendar_month_outlined, label: 'Calendar')),
        const PopupMenuItem(value: 'artist', child: _MenuRow(icon: Icons.brush_outlined, label: 'Artist')),
        const PopupMenuItem(value: 'reviews', child: _MenuRow(icon: Icons.star_border, label: 'Reviews')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'logout', child: _MenuRow(icon: Icons.logout, label: 'Logout')),
      ],
    ).then((value) {
      if (!mounted || value == null) return;
      if (value == 'profile') _openProfile(context);
      if (value == 'earnings') _openEarnings(context);
      if (value == 'calendar') _openCalendar(context);
      if (value == 'artist') _openArtist(context);
      if (value == 'reviews') _openReviews(context);
      if (value == 'logout') _logout(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = _filtered(_brandRequests);
    final client = _filtered(_clientRequests);
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: JntStandardAppBar(
        onNotifications: () {},
        trailing: InkWell(
          onTap: () => _showAvatarMenu(context),
          child: ClientProfileAvatarIcon(
            displayName: widget.profile.basic.name,
            imageUrl: widget.profile.basic.profileImageUrl,
            size: JntHeaderMetrics.avatarSize,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _tab('all', 'All ${_count('all')}'),
                    _tab('delivered', 'Delivered ${_count('delivered')}'),
                    _tab('declined', 'Declined ${_count('declined')}'),
                    _tab('expired', 'Expired ${_count('expired')}'),
                    _tab('cancelled', 'Cancelled ${_count('cancelled')}'),
                  ]),
                ),
                const SizedBox(height: 24),
                _section('Brand Requests', brand),
                const SizedBox(height: 24),
                _section('Client Requests', client),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.balletSlippers,
        currentIndex: 0,
        onTap: (i) => _openHomeTab(context, i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.deepPlum,
        unselectedItemColor: Colors.black.withValues(alpha: 0.55),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), activeIcon: Icon(Icons.add_circle), label: 'Design'),
          const BottomNavigationBarItem(icon: Icon(Icons.inbox_outlined), activeIcon: Icon(Icons.inbox), label: 'Requests'),
          if (_showCampaignsTab)
            const BottomNavigationBarItem(icon: Icon(Icons.campaign_outlined), activeIcon: Icon(Icons.campaign), label: 'Campaigns'),
          const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Orders'),
          if (!_showCampaignsTab)
            const BottomNavigationBarItem(icon: Icon(Icons.attach_money_outlined), activeIcon: Icon(Icons.attach_money), label: 'Earnings'),
        ],
      ),
    );
  }

  Widget _tab(String value, String label) {
    final selected = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      child: Padding(
        padding: const EdgeInsets.only(right: 34),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: selected ? AppColors.blackCat : AppColors.blackCat.withValues(alpha: 0.55))),
          const SizedBox(height: 8),
          Container(height: 3, width: 48, color: selected ? AppColors.blackCat : Colors.transparent),
        ]),
      ),
    );
  }

  Widget _section(String title, List<_HistoryItem> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$title (${items.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.blackCat)),
      const SizedBox(height: 16),
      if (items.isEmpty)
        Text('No $title found.', style: TextStyle(fontSize: 16, color: AppColors.blackCat.withValues(alpha: 0.55)))
      else
        ...items.map(_card),
    ]);
  }

  Widget _card(_HistoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.snow, border: Border.all(color: AppColors.blackCatBorderLight)),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.zero, child: SizedBox(width: 82, height: 82, child: item.imageUrl.isEmpty ? Container(color: Colors.black.withValues(alpha: 0.06)) : Image.network(item.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.black.withValues(alpha: 0.06))))),
        const SizedBox(width: 18),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.blackCat)),
          const SizedBox(height: 8),
          Text(item.subtitle, style: const TextStyle(fontSize: 15, color: AppColors.blackCat)),
          const SizedBox(height: 12),
          Text(item.date == null ? '' : '${item.status} ${_month(item.date!.month)} ${item.date!.day}', style: TextStyle(fontSize: 15, color: AppColors.blackCat.withValues(alpha: 0.60))),
        ])),
        Text(item.status, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.blackCat)),
      ]),
    );
  }

  String _month(int month) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][month - 1];
}

class _HistoryItem {
  const _HistoryItem({required this.title, required this.subtitle, required this.status, required this.date, required this.imageUrl});
  final String title;
  final String subtitle;
  final String status;
  final DateTime? date;
  final String imageUrl;
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 24, color: AppColors.blackCat),
      const SizedBox(width: 18),
      Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.blackCat)),
    ]);
  }
}
