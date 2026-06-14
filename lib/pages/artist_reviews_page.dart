import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/notification_bell_button.dart';

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
  const ArtistReviewsPage({super.key});

  @override
  State<ArtistReviewsPage> createState() => _ArtistReviewsPageState();
}

class _ArtistReviewsPageState extends State<ArtistReviewsPage> {
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

  Future<void> _loadReviews() async {
    final email = (FirebaseAuth.instance.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (email.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    final db = FirebaseFirestore.instance;
    final out = <ArtistReviewItem>[];
    for (final collection in const <String>[
      'Client_Custom_Requests',
      'Company_Custom_Requests',
    ]) {
      final snap = await db
          .collection(collection)
          .where('acceptedByArtistEmail', isEqualTo: email)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final ratingRaw =
            data['clientRating'] ??
            (data['clientReview'] as Map<String, dynamic>?)?['rating'];
        final rating = ratingRaw is num
            ? ratingRaw.toDouble()
            : double.tryParse((ratingRaw ?? '').toString());
        if ((rating ?? 0) <= 0) continue;
        final review =
            (data['clientReview'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        final tip =
            (data['clientTip'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        final ts = review['submittedAt'] ?? data['clientReviewSubmittedAt'];
        final submittedAt = ts is Timestamp ? ts.toDate() : DateTime.now();
        final tipAmountRaw = tip['amount'] ?? data['clientTipAmount'] ?? 0;
        final tipAmount = tipAmountRaw is num
            ? tipAmountRaw.toDouble()
            : double.tryParse((tipAmountRaw ?? '').toString()) ?? 0;
        final reviewerName =
            (data['acceptedClientName'] ??
                    data['clientName'] ??
                    data['selectedClient'] ??
                    'Client')
                .toString()
                .trim();
        final avatarUrl =
            (data['acceptedClientAvatarUrl'] ??
                    data['clientAvatarUrl'] ??
                    data['selectedClientAvatarUrl'] ??
                    '')
                .toString()
                .trim();
        out.add(
          ArtistReviewItem(
            reviewerName: reviewerName.isEmpty ? 'Client' : reviewerName,
            type: collection == 'Company_Custom_Requests'
                ? ArtistReviewType.brand
                : ArtistReviewType.client,
            date: submittedAt,
            rating: rating ?? 0,
            comment: (review['comment'] ?? data['clientReviewText'] ?? '')
                .toString()
                .trim(),
            requestId: (data['orderNumber'] ?? doc.id).toString().trim(),
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(85),
        child: Container(
          color: AppColors.alabaster,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: NotificationBellButton(onTap: () {}, iconSize: 24),
                  ),
                  Center(
                    child: Image.asset(
                      'assets/images/jnt_logo_black.png',
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close reviews',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
              color: AppColors.blackCat.withOpacity(0.7),
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
                  color: AppColors.blackCat.withOpacity(0.72),
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
              color: AppColors.deepPlum,
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
                      color: AppColors.blackCat.withOpacity(0.7),
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
              color: AppColors.blackCat.withOpacity(0.7),
              fontFamily: 'Arial',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.redeem_rounded,
                size: 16,
                color: AppColors.deepPlum,
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
                  color: AppColors.deepPlum,
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
                color: AppColors.deepPlum,
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
