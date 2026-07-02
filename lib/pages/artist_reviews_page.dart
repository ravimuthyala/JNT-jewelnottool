import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/jnt_standard_app_bar.dart';

enum ArtistReviewType { client, brand }

class ArtistReviewItem {
  const ArtistReviewItem({
    required this.reviewerName,
    required this.type,
    required this.date,
    required this.rating,
    required this.comment,
    required this.requestId,
    required this.tipAmount,
    required this.thankYouNote,
    this.avatarUrl = '',
  });

  final String reviewerName;
  final ArtistReviewType type;
  final DateTime date;
  final double rating;
  final String comment;
  final String requestId;
  final double tipAmount;
  final String thankYouNote;
  final String avatarUrl;
}

class ArtistReviewsPage extends StatefulWidget {
  const ArtistReviewsPage({
    super.key,
    this.clientArtistMenuStyle = false,
    this.showBottomNav = false,
    this.showCampaignsTab = false,
    this.bottomNavCurrentIndex = 0,
    this.onBottomNavTap,
    this.onManageProfile,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onOpenEarnings,
    this.onOpenReviews,
    this.onSignOut,
  });

  final bool clientArtistMenuStyle;
  final bool showBottomNav;
  final bool showCampaignsTab;
  final int bottomNavCurrentIndex;
  final ValueChanged<int>? onBottomNavTap;
  final VoidCallback? onManageProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final VoidCallback? onOpenEarnings;
  final VoidCallback? onOpenReviews;
  final VoidCallback? onSignOut;

  @override
  State<ArtistReviewsPage> createState() => _ArtistReviewsPageState();
}

class _ArtistReviewsPageState extends State<ArtistReviewsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  int _tab = 0; // 0 all, 1 client, 2 brand
  String _sort = 'Newest First';
  String _typeFilter = 'All';
  bool _loading = true;
  List<ArtistReviewItem> _reviews = const <ArtistReviewItem>[];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _s(Object? value) => (value ?? '').toString().trim();

  String _firstNonEmpty(List<Object?> values, {String fallback = ''}) {
    for (final value in values) {
      final text = _s(value);
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  String _normalizeImagePath(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('assets/')) return value;
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('data:') ||
        value.startsWith('blob:') ||
        value.startsWith('file://')) {
      return value;
    }

    value = Uri.decodeFull(value);
    value = value.replaceFirst(RegExp(r'^/+'), '');
    value = value.replaceFirst(RegExp(r'^public/'), '');

    final slash = value.indexOf('/');
    final knownBuckets = <String>{
      'avatars',
      'profile-images',
      'profile_images',
      'client-profile-images',
      'client_profile_images',
      'client-uploads',
      'client_uploads',
      'user-uploads',
      'user_uploads',
      'images',
      'public',
      'jnt-uploads',
      'jnt_uploads',
    };

    if (slash > 0) {
      final bucket = value.substring(0, slash);
      final path = value.substring(slash + 1);
      if (knownBuckets.contains(bucket) && path.isNotEmpty) {
        return _supabase.storage.from(bucket).getPublicUrl(path);
      }
    }

    // Most JNT profile uploads are stored under an avatars/profile bucket.
    // If the DB only saved the object path, build a public URL for it.
    return _supabase.storage.from('avatars').getPublicUrl(value);
  }

  String _avatarFromMaps(List<Map<String, dynamic>> maps) {
    const keys = <String>[
      'accepted_client_profile_image',
      'acceptedClientProfileImage',
      'accepted_client_avatar_url',
      'acceptedClientAvatarUrl',
      'client_profile_image',
      'clientProfileImage',
      'client_profile_image_url',
      'clientProfileImageUrl',
      'client_avatar_url',
      'clientAvatarUrl',
      'selected_client_profile_image',
      'selectedClientProfileImage',
      'selected_client_avatar_url',
      'selectedClientAvatarUrl',
      'profile_image',
      'profileImage',
      'profile_image_url',
      'profileImageUrl',
      'photo_url',
      'photoUrl',
      'avatar_url',
      'avatarUrl',
      'image_url',
      'imageUrl',
      'picture',
    ];

    for (final map in maps) {
      for (final key in keys) {
        final value = _s(map[key]);
        if (value.isNotEmpty) return _normalizeImagePath(value);
      }
      for (final nestedKey in const <String>[
        'profile',
        'basic',
        'client',
        'reviewer',
        'acceptedClient',
        'selectedClient',
      ]) {
        final nested = _asMap(map[nestedKey]);
        if (nested.isEmpty) continue;
        for (final key in keys) {
          final value = _s(nested[key]);
          if (value.isNotEmpty) return _normalizeImagePath(value);
        }
      }
    }
    return '';
  }

  Future<String> _findReviewerAvatarFromDb({
    required String email,
    required String name,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = name.trim();
    final tables = <String>[
      'client_profiles',
      'clients',
      'client',
      'profiles',
      'user_profiles',
      'users',
    ];

    Future<String> readTable(String table, String column, String value) async {
      if (value.trim().isEmpty) return '';
      try {
        final rows = await _supabase
            .from(table)
            .select()
            .eq(column, value)
            .limit(1);
        if (rows.isNotEmpty) {
          final row = Map<String, dynamic>.from(rows.first as Map);
          final avatar = _avatarFromMaps(<Map<String, dynamic>>[row]);
          if (avatar.isNotEmpty) return avatar;
        }
      } catch (_) {}
      return '';
    }

    for (final table in tables) {
      for (final column in const <String>[
        'email',
        'client_email',
        'clientEmail',
      ]) {
        final avatar = await readTable(table, column, normalizedEmail);
        if (avatar.isNotEmpty) return avatar;
      }
    }

    for (final table in tables) {
      for (final column in const <String>[
        'name',
        'display_name',
        'displayName',
        'client_name',
        'clientName',
        'full_name',
        'fullName',
      ]) {
        final avatar = await readTable(table, column, normalizedName);
        if (avatar.isNotEmpty) return avatar;
      }
    }

    return '';
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().trim());
  }

  DateTime? _asDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  Future<void> _loadReviews() async {
    final email = (_supabase.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (email.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    final out = <ArtistReviewItem>[];
    for (final entry in const <MapEntry<String, ArtistReviewType>>[
      MapEntry<String, ArtistReviewType>(
        'client_custom_requests',
        ArtistReviewType.client,
      ),
      MapEntry<String, ArtistReviewType>(
        'company_custom_requests',
        ArtistReviewType.brand,
      ),
    ]) {
      final rows = await _supabase
          .from(entry.key)
          .select()
          .ilike('accepted_by_artist_email', email);
      for (final raw in rows) {
        final data = Map<String, dynamic>.from(raw);
        final details = _asMap(data['details']);
        final payload = _asMap(data['payload']);
        final review = _asMap(data['client_review'])
          ..addAll(_asMap(data['clientReview']))
          ..addAll(_asMap(details['clientReview']))
          ..addAll(_asMap(payload['clientReview']));
        final tip = _asMap(data['client_tip'])
          ..addAll(_asMap(data['clientTip']))
          ..addAll(_asMap(details['clientTip']))
          ..addAll(_asMap(payload['clientTip']));

        final rating =
            _asDouble(data['client_rating']) ??
            _asDouble(data['clientRating']) ??
            _asDouble(review['rating']);
        if ((rating ?? 0) <= 0) continue;

        final submittedAt =
            _asDateTime(data['client_review_submitted_at']) ??
            _asDateTime(data['clientReviewSubmittedAt']) ??
            _asDateTime(details['clientReviewSubmittedAt']) ??
            _asDateTime(payload['clientReviewSubmittedAt']) ??
            _asDateTime(review['submittedAt']) ??
            DateTime.now();

        final tipAmount =
            _asDouble(data['client_tip_amount']) ??
            _asDouble(data['clientTipAmount']) ??
            _asDouble(details['clientTipAmount']) ??
            _asDouble(payload['clientTipAmount']) ??
            _asDouble(tip['amount']) ??
            0;

        final reviewerName = _firstNonEmpty(<Object?>[
          data['accepted_client_name'],
          data['acceptedClientName'],
          data['client_name'],
          data['clientName'],
          data['selected_client_name'],
          data['selectedClientName'],
          data['selectedClient'],
          details['acceptedClientName'],
          details['clientName'],
          payload['acceptedClientName'],
          payload['clientName'],
          review['reviewerName'],
          review['clientName'],
        ], fallback: 'Client');

        final reviewerEmail = _firstNonEmpty(<Object?>[
          data['accepted_client_email'],
          data['acceptedClientEmail'],
          data['client_email'],
          data['clientEmail'],
          data['selected_client_email'],
          data['selectedClientEmail'],
          details['acceptedClientEmail'],
          details['clientEmail'],
          payload['acceptedClientEmail'],
          payload['clientEmail'],
          review['reviewerEmail'],
          review['clientEmail'],
        ]).toLowerCase();

        var avatarUrl = _avatarFromMaps(<Map<String, dynamic>>[
          data,
          details,
          payload,
          review,
          tip,
        ]);
        if (avatarUrl.isEmpty) {
          avatarUrl = await _findReviewerAvatarFromDb(
            email: reviewerEmail,
            name: reviewerName,
          );
        }

        out.add(
          ArtistReviewItem(
            reviewerName: reviewerName.isEmpty ? 'Client' : reviewerName,
            type: entry.value,
            date: submittedAt,
            rating: rating ?? 0,
            comment: (data['client_review_text'] ??
                    data['clientReviewText'] ??
                    details['clientReviewText'] ??
                    payload['clientReviewText'] ??
                    review['comment'] ??
                    '')
                .toString()
                .trim(),
            requestId: (data['order_number'] ??
                    data['orderNumber'] ??
                    data['request_number'] ??
                    data['requestNumber'] ??
                    data['client_request_number'] ??
                    data['clientRequestNumber'] ??
                    data['brand_request_number'] ??
                    data['brandRequestNumber'] ??
                    data['id'] ??
                    '')
                .toString()
                .trim(),
            tipAmount: tipAmount,
            thankYouNote: '',
            avatarUrl: avatarUrl,
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _reviews = out;
      _loading = false;
    });
  }

  List<ArtistReviewItem> get _filtered {
    Iterable<ArtistReviewItem> out = _reviews;
    if (_tab == 1) out = out.where((e) => e.type == ArtistReviewType.client);
    if (_tab == 2) out = out.where((e) => e.type == ArtistReviewType.brand);
    if (_typeFilter == 'Client') {
      out = out.where((e) => e.type == ArtistReviewType.client);
    } else if (_typeFilter == 'Brand') {
      out = out.where((e) => e.type == ArtistReviewType.brand);
    }
    final list = out.toList(growable: false);
    list.sort(
      (a, b) => _sort == 'Newest First'
          ? b.date.compareTo(a.date)
          : a.date.compareTo(b.date),
    );
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _filtered;
    final totalTips = _reviews.fold<double>(0, (p, e) => p + e.tipAmount);
    final reviewCount = _reviews.length;
    final avg = reviewCount == 0
        ? 0.0
        : _reviews.fold<double>(0, (p, e) => p + e.rating) / reviewCount;

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: JntStandardAppBar(
        onNotifications: () {},
        trailing: widget.clientArtistMenuStyle
            ? _ReviewsAvatarMenu(
                onManageProfile: widget.onManageProfile,
                onOpenHistory: widget.onOpenHistory,
                onOpenCalendar: widget.onOpenCalendar,
                onOpenArtist: widget.onOpenArtist,
                onOpenEarnings: widget.onOpenEarnings,
                onOpenReviews: widget.onOpenReviews,
                onSignOut: widget.onSignOut,
              )
            : IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close reviews',
                icon: const Icon(Icons.close_rounded),
              ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? BottomNavigationBar(
              backgroundColor: AppColors.balletSlippers,
              currentIndex: widget.bottomNavCurrentIndex,
              onTap: widget.onBottomNavTap,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.blackCat,
              unselectedItemColor: Colors.black.withValues(alpha: 0.55),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline),
                  activeIcon: Icon(Icons.add_circle),
                  label: 'Design',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.inbox_outlined),
                  activeIcon: Icon(Icons.inbox),
                  label: 'Requests',
                ),
                if (widget.showCampaignsTab)
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.campaign_outlined),
                    activeIcon: Icon(Icons.campaign),
                    label: 'Campaigns',
                  ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined),
                  activeIcon: Icon(Icons.receipt_long),
                  label: 'Orders',
                ),
                if (!widget.showCampaignsTab)
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.attach_money_outlined),
                    activeIcon: Icon(Icons.attach_money),
                    label: 'Earnings',
                  ),
              ],
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: [
          const Text(
            'Reviews',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'Arialbold',
              color: AppColors.blackCat,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'See what clients and brands say about you',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.blackCat.withValues(alpha: 0.7),
              fontFamily: 'Arial',
            ),
          ),
          const SizedBox(height: 12),
          _summaryCard(avg: avg, count: reviewCount, tips: totalTips),
          const SizedBox(height: 12),
          _tabs(),
          const SizedBox(height: 10),
          _filters(),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (reviews.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.snow,
                border: Border.all(color: AppColors.blackCatBorderLight),
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                'No reviews yet.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.blackCat.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Arial',
                ),
              ),
            )
          else
            for (final r in reviews) ...[
              _reviewCard(r),
              const SizedBox(height: 10),
            ],
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.snow,
              borderRadius: BorderRadius.zero,
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.blackCat,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reviews and tips are shared by clients and brands after completed orders/requests. They help build trust in our community.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.blackCat,
                      fontFamily: 'Arialbold',
                      fontWeight: FontWeight.w700,
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

  Widget _summaryCard({
    required double avg,
    required int count,
    required double tips,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        border: Border.all(color: AppColors.blackCatBorderLight),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Rated Artist',
            style: TextStyle(color: AppColors.blackCat, fontWeight: FontWeight.w700, fontFamily: 'Arialbold'),
          ),
          const SizedBox(height: 8),
          Text(
            'Overall Rating ${avg.toStringAsFixed(0)}/5',
            style: const TextStyle(
              color: AppColors.blackCat,
              fontFamily: 'Arial',
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count reviews',
            style: const TextStyle(fontSize: 12, fontFamily: 'Arial',color: AppColors.blackCat),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${tips.toStringAsFixed(0)} Tips Earned',
            style: const TextStyle(
              color: AppColors.blackCat,
              fontWeight: FontWeight.w700,
              fontFamily: 'Arialbold',
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    Widget tab(int i, String label) {
      final active = _tab == i;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _tab = i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active
                      ? AppColors.balletSlippers
                      : Colors.transparent,
                  width: active ? 3 : 0,
                ),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                fontFamily: active ? 'Arialbold' : 'Arial',
                color: AppColors.blackCat,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(0, 'All Reviews'),
        tab(1, 'Client Reviews'),
        tab(2, 'Brand Reviews'),
      ],
    );
  }

  Widget _filters() {
    return Row(
      children: [
        Expanded(
          child: _dropdown(
            value: _sort,
            items: const ['Newest First', 'Oldest First'],
            onChanged: (v) => setState(() => _sort = v),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _dropdown(
            value: _typeFilter,
            items: const ['All', 'Client', 'Brand'],
            onChanged: (v) => setState(() => _typeFilter = v),
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.snow,
        border: Border.all(color: AppColors.blackCatBorderLight),
        borderRadius: BorderRadius.zero,
      ),
      child: Builder(
        builder: (fieldContext) => InkWell(
          onTap: () async {
            final box = fieldContext.findRenderObject() as RenderBox?;
            final overlay = Overlay.of(fieldContext).context.findRenderObject()
                as RenderBox?;
            if (box == null || overlay == null) return;
            final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
            final menuPosition = RelativeRect.fromRect(
              Rect.fromLTWH(
                topLeft.dx,
                topLeft.dy + box.size.height,
                box.size.width,
                0,
              ),
              Offset.zero & overlay.size,
            );
            final selected = await showMenu<String>(
              context: fieldContext,
              position: menuPosition,
              color: AppColors.snow,
              items: items
                  .map(
                    (e) => PopupMenuItem<String>(
                      value: e,
                      child: Text(
                        e,
                        style: const TextStyle(fontSize: 12.5, fontFamily: 'Arial',color: AppColors.blackCat),
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
            if (selected != null) {
              onChanged(selected);
            }
          },
          child: SizedBox(
            height: 46,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 12.5, fontFamily: 'Arial',color: AppColors.blackCat),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reviewCard(ArtistReviewItem r) {
    final badgeText = r.type == ArtistReviewType.client ? 'Client' : 'Brand';
    final badgeColor = AppColors.balletSlippers;
    final when = '${_month(r.date.month)} ${r.date.day}, ${r.date.year}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        border: Border.all(color: AppColors.blackCatBorderLight),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: AppColors.blackCatBorderLight),
                ),
                clipBehavior: Clip.hardEdge,
                child: ClientProfileAvatarIcon(
                  imageUrl: r.avatarUrl,
                  displayName: r.reviewerName,
                  size: 40,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.reviewerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        fontFamily: 'Arialbold',
                        color: AppColors.blackCat,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 16, color: AppColors.blackCat),
                        const SizedBox(width: 4),
                        Text(
                          r.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Arialbold',
                            color: AppColors.blackCat,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    color: badgeColor,
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'Arial',
                        color: AppColors.blackCat,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    when,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.blackCat.withValues(alpha: 0.7),
                      fontFamily: 'Arial',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            r.comment,
            style: const TextStyle(fontSize: 13, fontFamily: 'Arial',color: AppColors.blackCat),
          ),
          const SizedBox(height: 6),
          Text(
            'Order/Request ID: #${r.requestId}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.blackCat.withValues(alpha: 0.7),
              fontFamily: 'Arial',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.redeem_rounded,
                size: 16,
                color: AppColors.blackCat,
              ),
              const SizedBox(width: 6),
              const Text(
                'Tip Provided by Client',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Arialbold',
                  color: AppColors.blackCat,
                ),
              ),
              const Spacer(),
              Text(
                '\$${r.tipAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackCat,
                  fontFamily: 'Arialbold',
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  r.thankYouNote,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontFamily: 'Arial'),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.favorite_border_rounded,
                size: 16,
                color: AppColors.blackCat,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _month(int m) {
    const mm = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return mm[(m - 1).clamp(0, 11)];
  }
}

class _ReviewsAvatarMenu extends StatelessWidget {
  const _ReviewsAvatarMenu({
    this.onManageProfile,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onOpenEarnings,
    this.onOpenReviews,
    this.onSignOut,
  });

  final VoidCallback? onManageProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final VoidCallback? onOpenEarnings;
  final VoidCallback? onOpenReviews;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 55),
      elevation: 8,
      color: AppColors.snow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      onSelected: (value) {
        if (value == 'profile') onManageProfile?.call();
        if (value == 'earnings') onOpenEarnings?.call();
        if (value == 'history') onOpenHistory?.call();
        if (value == 'calendar') onOpenCalendar?.call();
        if (value == 'artist') onOpenArtist?.call();
        if (value == 'reviews') onOpenReviews?.call();
        if (value == 'logout') onSignOut?.call();
      },
      child: const ClientProfileAvatarIcon(size: 36),
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'profile',
          child: _AvatarMenuRow(icon: Icons.person_outline, label: 'Profile'),
        ),
        const PopupMenuItem<String>(
          value: 'earnings',
          child: _AvatarMenuRow(
            icon: Icons.attach_money_outlined,
            label: 'Earnings',
          ),
        ),
        const PopupMenuItem<String>(
          value: 'history',
          child: _AvatarMenuRow(icon: Icons.history, label: 'History'),
        ),
        const PopupMenuItem<String>(
          value: 'calendar',
          child: _AvatarMenuRow(
            icon: Icons.calendar_month_outlined,
            label: 'Calendar',
          ),
        ),
        const PopupMenuItem<String>(
          value: 'artist',
          child: _AvatarMenuRow(icon: Icons.brush_outlined, label: 'Artist'),
        ),
        const PopupMenuItem<String>(
          value: 'reviews',
          child: _AvatarMenuRow(icon: Icons.star_border, label: 'Reviews'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: _AvatarMenuRow(icon: Icons.logout, label: 'Logout'),
        ),
      ],
    );
  }
}

class _AvatarMenuRow extends StatelessWidget {
  const _AvatarMenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 14),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
