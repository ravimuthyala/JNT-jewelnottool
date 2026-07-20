// lib/pages/artist_orders_page.dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'artist_order_details_pages.dart'; // ✅ new artist-specific details
// NOTE: No TrackOrderPage for artist (artist updates shipping + delivered here)

class ArtistOrdersPage extends StatefulWidget {
  const ArtistOrdersPage({super.key, this.onBackHome});

  final VoidCallback? onBackHome;

  @override
  State<ArtistOrdersPage> createState() => _ArtistOrdersPageState();
}

class _ArtistOrdersPageState extends State<ArtistOrdersPage> {
  ArtistOrdersFilter _filter = ArtistOrdersFilter.all;

  final List<ArtistOrder> _orders = [
    const ArtistOrder(
      id: 'a1',
      clientName: 'Sarah Johnson',
      title: 'Sparkle Floral Tips',
      subtitle: 'New order request',
      status: ArtistOrderStatus.newOrder,
      statusText: 'New • Needs your approval',
      progress: null,
      imageAsset: 'assets/images/order_thumb_1.png',
      clientNotes: 'Short almond • pink base • sparkle florals',
    ),
    const ArtistOrder(
      id: 'a2',
      clientName: 'Studio Bliss',
      title: 'Chrome French Tips',
      subtitle: 'In Progress',
      status: ArtistOrderStatus.inProgress,
      statusText: 'Due by May 12',
      progress: 0.45,
      imageAsset: 'assets/images/order_thumb_2.png',
      clientNotes: 'Medium square • chrome silver tips',
    ),
    const ArtistOrder(
      id: 'a3',
      clientName: 'Glamour Nails Studio',
      title: 'Spring Floral Designs',
      subtitle: 'Completed',
      status: ArtistOrderStatus.completed,
      statusText: 'Ready to ship',
      progress: 1.0,
      imageAsset: 'assets/images/order_thumb_3.png',
      clientNotes: 'Pastel floral set • include 2 accent nails',
    ),
    const ArtistOrder(
      id: 'a4',
      clientName: 'Nail Elegance',
      title: 'Purple Marble + Glitter',
      subtitle: 'Shipped',
      status: ArtistOrderStatus.shipped,
      statusText: 'Shipped May 6',
      imageAsset: 'assets/images/order_thumb_4.png',
      trackingNumber: '9400 1000 0000 0000 0000 00',
      carrier: 'USPS',
    ),
    const ArtistOrder(
      id: 'a5',
      clientName: 'Ava Client',
      title: 'Matte Black + Stars',
      subtitle: 'Delivered',
      status: ArtistOrderStatus.delivered,
      statusText: 'Delivered Apr 08',
      imageAsset: 'assets/images/order_thumb_1.png',
    ),
    const ArtistOrder(
      id: 'a6',
      clientName: 'Emma Client',
      title: 'Nude Ombre',
      subtitle: 'Expired',
      status: ArtistOrderStatus.expired,
      statusText: 'Expired Mar 20',
      imageAsset: 'assets/images/order_thumb_2.png',
    ),
  ];

  List<ArtistOrder> get _filteredOrders {
    switch (_filter) {
      case ArtistOrdersFilter.all:
        return _orders;
      case ArtistOrdersFilter.newOrders:
        return _orders
            .where((o) => o.status == ArtistOrderStatus.newOrder)
            .toList();
      case ArtistOrdersFilter.inProgress:
        return _orders
            .where((o) => o.status == ArtistOrderStatus.inProgress)
            .toList();
      case ArtistOrdersFilter.completed:
        return _orders
            .where((o) => o.status == ArtistOrderStatus.completed)
            .toList();
      case ArtistOrdersFilter.shipped:
        return _orders
            .where((o) => o.status == ArtistOrderStatus.shipped)
            .toList();
      case ArtistOrdersFilter.delivered:
        return _orders
            .where((o) => o.status == ArtistOrderStatus.delivered)
            .toList();
      case ArtistOrdersFilter.expired:
        return _orders
            .where((o) => o.status == ArtistOrderStatus.expired)
            .toList();
      case ArtistOrdersFilter.cancelled:
        return _orders
            .where((o) => o.status == ArtistOrderStatus.cancelled)
            .toList();
    }
  }

  // Pending = New + In Progress + Completed + Shipped
  List<ArtistOrder> get _pending => _filteredOrders
      .where(
        (o) =>
            o.status == ArtistOrderStatus.newOrder ||
            o.status == ArtistOrderStatus.inProgress ||
            o.status == ArtistOrderStatus.completed ||
            o.status == ArtistOrderStatus.shipped,
      )
      .toList();

  // Past = Delivered + Expired + Cancelled
  List<ArtistOrder> get _past => _filteredOrders
      .where(
        (o) =>
            o.status == ArtistOrderStatus.delivered ||
            o.status == ArtistOrderStatus.expired ||
            o.status == ArtistOrderStatus.cancelled,
      )
      .toList();

  void _applyOrderUpdate(ArtistOrder updated) {
    setState(() {
      final idx = _orders.indexWhere((o) => o.id == updated.id);
      if (idx != -1) _orders[idx] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.alabaster,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => widget.onBackHome?.call(),
        ),
        title: const Text(
          'Orders',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
        children: [
          _ArtistFilterTabs(
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 16),

          if (_pending.isNotEmpty) ...[
            const Text(
              'Pending Orders',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ..._pending.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ArtistOrderCard(
                  order: o,
                  onDetails: () => _openOrderDetails(context, o),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (_past.isNotEmpty) ...[
            const Text(
              'Past Orders',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ..._past.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ArtistOrderCard(
                  order: o,
                  onDetails: () => _openOrderDetails(context, o),
                ),
              ),
            ),
          ],

          if (_pending.isEmpty && _past.isEmpty) ...[
            const SizedBox(height: 28),
            _Card(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 46,
                    color: AppColors.blackCat.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No orders found',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try changing filters.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.60),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openOrderDetails(BuildContext context, ArtistOrder order) {
    late final Widget page;

    switch (order.status) {
      case ArtistOrderStatus.newOrder:
        page = NewArtistOrderDetailsPage(
          order: order,
          onUpdate: _applyOrderUpdate,
        );
        break;
      case ArtistOrderStatus.inReview:
        page = InReviewArtistOrderDetailsPage(
          order: order,
          onUpdate: _applyOrderUpdate,
        );
        break;
      case ArtistOrderStatus.accepted:
        page = AcceptedArtistOrderDetailsPage(
          order: order,
          onUpdate: _applyOrderUpdate,
        );
        break;
      case ArtistOrderStatus.inProgress:
        page = InProgressArtistOrderDetailsPage(
          order: order,
          onUpdate: _applyOrderUpdate,
        );
        break;
      case ArtistOrderStatus.completed:
        page = CompletedArtistOrderDetailsPage(
          order: order,
          onUpdate: _applyOrderUpdate,
        );
        break;
      case ArtistOrderStatus.shipped:
        page = ShippedArtistOrderDetailsPage(
          order: order,
          onUpdate: _applyOrderUpdate,
        );
        break;
      case ArtistOrderStatus.delivered:
        page = DeliveredArtistOrderDetailsPage(
          order: order,
          onUpdate: _applyOrderUpdate,
        );
        break;
      case ArtistOrderStatus.expired:
        page = ExpiredArtistOrderDetailsPage(
          order: order,
          onUpdate: _applyOrderUpdate,
        );
        break;
      case ArtistOrderStatus.cancelled:
        page = CancelledArtistOrderDetailsPage(
          order: order,
          onUpdate: _applyOrderUpdate,
        );
        break;
      case ArtistOrderStatus.declined:
        page = DeclinedArtistOrderDetailsPage(
          order: order,
          onUpdate: _applyOrderUpdate,
        );
        break;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

/// ---------------------------
/// Filter Pills (Artist)
/// ---------------------------
enum ArtistOrdersFilter {
  all,
  newOrders,
  inProgress,
  completed,
  shipped,
  delivered,
  expired,
  cancelled,
}

class _ArtistFilterTabs extends StatelessWidget {
  const _ArtistFilterTabs({required this.selected, required this.onChanged});

  final ArtistOrdersFilter selected;
  final ValueChanged<ArtistOrdersFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tab('All', ArtistOrdersFilter.all),
            _tab('New', ArtistOrdersFilter.newOrders),
            _tab('In Progress', ArtistOrdersFilter.inProgress),
            _tab('Completed', ArtistOrdersFilter.completed),
            _tab('Shipped', ArtistOrdersFilter.shipped),
            _tab('Delivered', ArtistOrdersFilter.delivered),
            _tab('Expired', ArtistOrdersFilter.expired),
            _tab('Cancelled', ArtistOrdersFilter.cancelled),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, ArtistOrdersFilter value) {
    final bool isSelected = selected == value;

    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected
                    ? AppColors.blackCat
                    : AppColors.blackCat.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2.5,
              width: isSelected ? 24 : 0,
              decoration: BoxDecoration(
                color: AppColors.blackCat,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// ---------------------------
/// Order Card (Artist)
/// ---------------------------
class _ArtistOrderCard extends StatelessWidget {
  const _ArtistOrderCard({required this.order, required this.onDetails});

  final ArtistOrder order;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final isProgress = order.status == ArtistOrderStatus.inProgress;

    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumb(imageAsset: order.imageAsset),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ArtistStatusChip(status: order.status),
                  ],
                ),
                const SizedBox(height: 4),

                Text(
                  order.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 10),

                if (isProgress) ...[
                  _ProgressBar(value: (order.progress ?? 0.0).clamp(0.0, 1.0)),
                  const SizedBox(height: 10),
                ],

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.statusText,
                        style: TextStyle(
                          color: AppColors.blackCat.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      button: true,
                      child: InkWell(
                      onTap: onDetails,
                      borderRadius: BorderRadius.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Order details',
                              style: TextStyle(
                                color: AppColors.blackCat.withValues(alpha: 0.55),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.blackCat.withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                      ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.imageAsset});
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final asset = imageAsset ?? 'assets/images/order_thumb_1.png';
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: Image.asset(
        asset,
        height: 64,
        width: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: AppColors.blackCat.withValues(alpha: 0.06),
            borderRadius: BorderRadius.zero,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.blackCat.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class _ArtistStatusChip extends StatelessWidget {
  const _ArtistStatusChip({required this.status});
  final ArtistOrderStatus status;

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color bg;
    late final Color fg;

    switch (status) {
      case ArtistOrderStatus.newOrder:
        text = 'New';
        bg = const Color(0xFFF5F0FF);
        fg = AppColors.deepPlum;
        break;
      case ArtistOrderStatus.inReview:
        text = 'In Review';
        bg = const Color(0xFFEFF4FF);
        fg = const Color(0xFF2F5AA8);
        break;
      case ArtistOrderStatus.accepted:
        text = 'Accepted';
        bg = const Color(0xFFF5F0FF);
        fg = AppColors.deepPlum;
        break;
      case ArtistOrderStatus.inProgress:
        text = 'In Progress';
        bg = const Color(0xFFFBEAEC);
        fg = const Color(0xFFD36B77);
        break;
      case ArtistOrderStatus.completed:
        text = 'Completed';
        bg = const Color(0xFFEAF7F2);
        fg = const Color(0xFF2E8B57);
        break;
      case ArtistOrderStatus.shipped:
        text = 'Shipped';
        bg = const Color(0xFFEFF4FF);
        fg = const Color(0xFF2F5AA8);
        break;
      case ArtistOrderStatus.delivered:
        text = 'Delivered';
        bg = const Color(0xFFEAF7F2);
        fg = const Color(0xFF2E8B57);
        break;
      case ArtistOrderStatus.expired:
        text = 'Expired';
        bg = const Color(0xFFFFF2E8);
        fg = const Color(0xFFB65A1E);
        break;
      case ArtistOrderStatus.cancelled:
        text = 'Cancelled';
        bg = const Color(0xFFF1F1F5);
        fg = const Color(0xFF6B6B6B);
        break;
      case ArtistOrderStatus.declined:
        text = 'Declined';
        bg = const Color(0xFFFFEEF0);
        fg = const Color(0xFFB42318);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.04)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12.5,
          color: fg,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: Container(
        height: 8,
        color: AppColors.blackCat.withValues(alpha: 0.06),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF28B8B),
                    AppColors.blackCat.withValues(alpha: 0.60),
                    const Color(0xFF7BD9A5),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------
/// Shared Card Container
/// ---------------------------
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;
  final EdgeInsets? padding=null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
