// lib/pages/artist_order_details_pages.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import '../utils/image_cache_utils.dart';
import '../widgets/jnt_modal_app_bar.dart';

/// =======================================================
/// Artist Order Model (artist-facing statuses + actions)
/// =======================================================
enum ArtistOrderStatus {
  newOrder,
  inReview,
  accepted,
  inProgress,
  completed,
  shipped,
  delivered,
  declined, // ✅ add
  expired,
  cancelled,
}

@immutable
class ArtistOrder {
  final String id;

  /// Client name shown to artist
  final String clientName;

  /// Design / set name
  final String title;

  /// Optional short note (e.g., “Chrome French tips”)
  final String subtitle;

  final ArtistOrderStatus status;

  /// “Due by …” / “Shipped …” / etc.
  final String statusText;

  /// Progress 0..1 (inProgress only)
  final double? progress;

  /// Client request notes / design notes
  final String? clientNotes;

  /// Artist internal notes
  final String? artistNotes;

  /// Reference images / order thumb (asset or url)
  final String? imageAsset;

  /// Completed photos uploaded by artist (bytes)
  final List<Uint8List> completedPhotos;

  /// Shipping
  final String? trackingNumber;
  final String? carrier;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;

  const ArtistOrder({
    required this.id,
    required this.clientName,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusText,
    this.progress,
    this.clientNotes,
    this.artistNotes,
    this.imageAsset,
    this.completedPhotos = const [],
    this.trackingNumber,
    this.carrier,
    this.shippedAt,
    this.deliveredAt,
  });

  ArtistOrder copyWith({
    String? id,
    String? clientName,
    String? title,
    String? subtitle,
    ArtistOrderStatus? status,
    String? statusText,
    double? progress,
    String? clientNotes,
    String? artistNotes,
    String? imageAsset,
    List<Uint8List>? completedPhotos,
    String? trackingNumber,
    String? carrier,
    DateTime? shippedAt,
    DateTime? deliveredAt,
  }) {
    return ArtistOrder(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      status: status ?? this.status,
      statusText: statusText ?? this.statusText,
      progress: progress ?? this.progress,
      clientNotes: clientNotes ?? this.clientNotes,
      artistNotes: artistNotes ?? this.artistNotes,
      imageAsset: imageAsset ?? this.imageAsset,
      completedPhotos: completedPhotos ?? this.completedPhotos,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      carrier: carrier ?? this.carrier,
      shippedAt: shippedAt ?? this.shippedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }
}


class NewArtistOrderDetailsPage extends StatelessWidget {
  const NewArtistOrderDetailsPage({
    super.key,
    required this.order,
    required this.onUpdate,
  });

  final ArtistOrder order;
  final ValueChanged<ArtistOrder> onUpdate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'New order details',
      child: _OrderDetailsShell(
      title: 'New Order',
      order: order,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopSummary(order: order),
          const SizedBox(height: 12),
          _Card(child: _NotesBlock(order: order)),
          const SizedBox(height: 12),

          Row(
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      side: BorderSide(color: AppColors.blackCat.withValues(alpha: 0.15)),
                    ),
                    onPressed: () {
                      onUpdate(
                        order.copyWith(
                          status: ArtistOrderStatus.declined,
                          statusText: 'Declined',
                        ),
                      );
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Decline',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                fit: FlexFit.loose,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepPlum,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: () {
                      onUpdate(
                        order.copyWith(
                          status: ArtistOrderStatus.accepted,
                          statusText: 'Accepted',
                        ),
                      );
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Accept',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class InReviewArtistOrderDetailsPage extends StatelessWidget {
  const InReviewArtistOrderDetailsPage({
    super.key,
    required this.order,
    required this.onUpdate,
  });

  final ArtistOrder order;
  final ValueChanged<ArtistOrder> onUpdate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'In review order details',
      child: _OrderDetailsShell(
      title: 'In Review',
      order: order,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopSummary(order: order),
          const SizedBox(height: 12),
          _Card(child: _NotesBlock(order: order)),
          const SizedBox(height: 12),
          _Card(
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.blackCat.withValues(alpha: 0.55)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Review the client’s details. Accept when you’re ready.',
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.60),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      side: BorderSide(color: AppColors.blackCat.withValues(alpha: 0.15)),
                    ),
                    onPressed: () {
                      onUpdate(
                        order.copyWith(
                          status: ArtistOrderStatus.cancelled,
                          statusText: 'Cancelled',
                        ),
                      );
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Decline',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                fit: FlexFit.loose,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blackCat,
                      foregroundColor: AppColors.snow,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: () {
                      onUpdate(
                        order.copyWith(
                          status: ArtistOrderStatus.accepted,
                          statusText: 'Accepted',
                        ),
                      );
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Accept',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class AcceptedArtistOrderDetailsPage extends StatelessWidget {
  const AcceptedArtistOrderDetailsPage({
    super.key,
    required this.order,
    required this.onUpdate,
  });

  final ArtistOrder order;
  final ValueChanged<ArtistOrder> onUpdate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Accepted order details',
      child: _OrderDetailsShell(
      title: 'Accepted',
      order: order,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopSummary(order: order),
          const SizedBox(height: 12),
          _Card(child: _NotesBlock(order: order)),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F6FED),
                foregroundColor: AppColors.snow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: () {
                onUpdate(
                  order.copyWith(
                    status: ArtistOrderStatus.inProgress,
                    statusText: 'In Progress',
                    progress: 0.15,
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text(
                'Start Order (Mark In Progress)',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class InProgressArtistOrderDetailsPage extends StatelessWidget {
  const InProgressArtistOrderDetailsPage({
    super.key,
    required this.order,
    required this.onUpdate,
  });

  final ArtistOrder order;
  final ValueChanged<ArtistOrder> onUpdate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'In progress order details',
      child: _InProgressScaffold(order: order, onUpdate: onUpdate),
    );
  }
}

class CompletedArtistOrderDetailsPage extends StatelessWidget {
  const CompletedArtistOrderDetailsPage({
    super.key,
    required this.order,
    required this.onUpdate,
  });

  final ArtistOrder order;
  final ValueChanged<ArtistOrder> onUpdate;

  @override
  Widget build(BuildContext context) {
    return _CompletedScaffold(order: order, onUpdate: onUpdate);
  }
}

class ShippedArtistOrderDetailsPage extends StatelessWidget {
  const ShippedArtistOrderDetailsPage({
    super.key,
    required this.order,
    required this.onUpdate,
  });

  final ArtistOrder order;
  final ValueChanged<ArtistOrder> onUpdate;

  @override
  Widget build(BuildContext context) {
    return _ShippedScaffold(order: order, onUpdate: onUpdate);
  }
}

class DeclinedArtistOrderDetailsPage extends StatelessWidget {
  const DeclinedArtistOrderDetailsPage({
    super.key,
    required this.order,
    required this.onUpdate,
  });

  final ArtistOrder order;
  final ValueChanged<ArtistOrder> onUpdate;

  @override
  Widget build(BuildContext context) {
    return _OrderDetailsShell(
      title: 'Declined',
      order: order,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopSummary(order: order),
          const SizedBox(height: 12),
          _Card(
            child: Row(
              children: [
                Icon(
                  Icons.close_rounded,
                  color: AppColors.blackCat.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This request was declined.',
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.60),
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
}

class DeliveredArtistOrderDetailsPage extends StatelessWidget {
  const DeliveredArtistOrderDetailsPage({
    super.key,
    required this.order,
    required this.onUpdate,
  });

  final ArtistOrder order;
  final ValueChanged<ArtistOrder> onUpdate;

  @override
  Widget build(BuildContext context) {
    return _OrderDetailsShell(
      title: 'Delivered',
      order: order,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopSummary(order: order),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Confirmed',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  order.deliveredAt == null
                      ? 'Delivered'
                      : 'Delivered on ${_fmtDate(order.deliveredAt!)}',
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                if (order.trackingNumber != null &&
                    order.trackingNumber!.trim().isNotEmpty) ...[
                  _kv('Tracking #', order.trackingNumber!.trim()),
                  if ((order.carrier ?? '').trim().isNotEmpty)
                    _kv('Carrier', order.carrier!.trim()),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (order.completedPhotos.isNotEmpty) ...[
            const Text(
              'Completed Photos',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _PhotoGrid(bytes: order.completedPhotos),
          ],
        ],
      ),
    );
  }
}

class ExpiredArtistOrderDetailsPage extends StatelessWidget {
  const ExpiredArtistOrderDetailsPage({
    super.key,
    required this.order,
    required this.onUpdate,
  });

  final ArtistOrder order;
  final ValueChanged<ArtistOrder> onUpdate;

  @override
  Widget build(BuildContext context) {
    return _OrderDetailsShell(
      title: 'Expired',
      order: order,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopSummary(order: order),
          const SizedBox(height: 12),
          _Card(
            child: Row(
              children: [
                Icon(
                  Icons.timer_off_outlined,
                  color: AppColors.blackCat.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This order is marked as expired. If you need to re-open it, handle via admin tools / backend.',
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.60),
                      fontWeight: FontWeight.w600,
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
}

class CancelledArtistOrderDetailsPage extends StatelessWidget {
  const CancelledArtistOrderDetailsPage({
    super.key,
    required this.order,
    required this.onUpdate,
  });

  final ArtistOrder order;
  final ValueChanged<ArtistOrder> onUpdate;

  @override
  Widget build(BuildContext context) {
    return _OrderDetailsShell(
      title: 'Cancelled',
      order: order,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopSummary(order: order),
          const SizedBox(height: 12),
          _Card(
            child: Row(
              children: [
                Icon(
                  Icons.block_flipped,
                  color: AppColors.blackCat.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This order is cancelled.',
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.60),
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
}

/// =======================================================
/// In Progress (artist actions: upload completed photos + mark completed)
/// =======================================================
class _InProgressScaffold extends StatefulWidget {
  const _InProgressScaffold({required this.order, required this.onUpdate});

  final ArtistOrder order;
  final ValueChanged<ArtistOrder> onUpdate;

  @override
  State<_InProgressScaffold> createState() => _InProgressScaffoldState();
}

class _InProgressScaffoldState extends State<_InProgressScaffold> {
  final ImagePicker _picker = ImagePicker();
  static const int _maxCompletedPhotos = 10;
  late ArtistOrder _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  void _pushUpdate(ArtistOrder updated) {
    setState(() => _order = updated);
    widget.onUpdate(updated);
  }

  Future<void> _uploadCompletedPhotos() async {
    if (_order.completedPhotos.length >= _maxCompletedPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can upload up to 10 completed photos.'),
        ),
      );
      return;
    }

    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;

    final remainingSlots = _maxCompletedPhotos - _order.completedPhotos.length;
    final selected = files.take(remainingSlots).toList(growable: false);
    final added = <Uint8List>[];
    for (final f in selected) {
      added.add(await f.readAsBytes());
    }

    _pushUpdate(
      _order.copyWith(completedPhotos: [..._order.completedPhotos, ...added]),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Uploaded ${added.length} photo(s) ✅')),
    );
    if (files.length > remainingSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Extra photos were skipped. Maximum is 10.'),
        ),
      );
    }
  }

  Future<void> _takeCompletedPhoto() async {
    if (_order.completedPhotos.length >= _maxCompletedPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can upload up to 10 completed photos.'),
        ),
      );
      return;
    }

    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    _pushUpdate(
      _order.copyWith(completedPhotos: [..._order.completedPhotos, bytes]),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Photo added ✅')));
  }

  void _deleteCompletedPhoto(int index) {
    final updated = [..._order.completedPhotos]..removeAt(index);
    _pushUpdate(_order.copyWith(completedPhotos: updated));
  }

  void _markCompleted() {
    if (_order.completedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload at least 1 completed photo first.'),
        ),
      );
      return;
    }

    _pushUpdate(
      _order.copyWith(
        status: ArtistOrderStatus.completed,
        statusText: 'Completed',
        progress: 1.0,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _OrderDetailsShell(
      title: 'In Progress',
      order: _order,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopSummary(order: _order),
          const SizedBox(height: 12),

          _Card(child: _NotesBlock(order: _order)),
          const SizedBox(height: 12),

          const Text(
            'Completed Photos',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),

          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_order.completedPhotos.isEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.image_outlined,
                        color: AppColors.blackCat.withValues(alpha: 0.50),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No completed photos yet.',
                          style: TextStyle(
                            color: AppColors.blackCat.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  _PhotoGrid(
                    bytes: _order.completedPhotos,
                    onDelete: _deleteCompletedPhoto,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            side: BorderSide(
                              color: AppColors.blackCat.withValues(alpha: 0.12),
                            ),
                          ),
                          onPressed: _uploadCompletedPhotos,
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text(
                            'Upload Photo',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      fit: FlexFit.loose,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blackCat,
                            foregroundColor: AppColors.snow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            elevation: 0,
                          ),
                          onPressed: _takeCompletedPhoto,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text(
                            'Take Photo',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F6FED),
                foregroundColor: AppColors.snow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: _markCompleted,
              child: const Text(
                'Mark Completed',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================================================
/// Completed (artist actions: enter tracking + mark shipped)
/// =======================================================
class _CompletedScaffold extends StatefulWidget {
  const _CompletedScaffold({required this.order, required this.onUpdate});

  final ArtistOrder order;
  final ValueChanged<ArtistOrder> onUpdate;

  @override
  State<_CompletedScaffold> createState() => _CompletedScaffoldState();
}

class _CompletedScaffoldState extends State<_CompletedScaffold> {
  late ArtistOrder _order;
  final _trackingCtrl = TextEditingController();
  final _carrierCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _trackingCtrl.text = widget.order.trackingNumber ?? '';
    _carrierCtrl.text = widget.order.carrier ?? '';
  }

  @override
  void dispose() {
    _trackingCtrl.dispose();
    _carrierCtrl.dispose();
    super.dispose();
  }

  void _pushUpdate(ArtistOrder updated) {
    setState(() => _order = updated);
    widget.onUpdate(updated);
  }

  void _markShipped() {
    final tracking = _trackingCtrl.text.trim();
    if (tracking.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter tracking #')));
      return;
    }

    _pushUpdate(
      _order.copyWith(
        status: ArtistOrderStatus.shipped,
        statusText: 'Shipped',
        trackingNumber: tracking,
        carrier: _carrierCtrl.text.trim(),
        shippedAt: DateTime.now(),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _OrderDetailsShell(
      title: 'Completed',
      order: _order,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopSummary(order: _order),
          const SizedBox(height: 12),

          if (_order.completedPhotos.isNotEmpty) ...[
            const Text(
              'Completed Photos',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _PhotoGrid(bytes: _order.completedPhotos),
            const SizedBox(height: 12),
          ],

          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mark as Shipped',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _carrierCtrl,
                  decoration: _dec('Carrier (optional)', 'USPS / UPS / FedEx'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _trackingCtrl,
                  decoration: _dec('Tracking # *', 'Enter tracking number'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blackCat,
                      foregroundColor: AppColors.snow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      elevation: 0,
                    ),
                    onPressed: _markShipped,
                    child: const Text(
                      'Mark Shipped',
                      style: TextStyle(fontWeight: FontWeight.w900),
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
}

/// =======================================================
/// Shipped (artist actions: mark delivered)
/// =======================================================
class _ShippedScaffold extends StatelessWidget {
  const _ShippedScaffold({required this.order, required this.onUpdate});

  final ArtistOrder order;
  final ValueChanged<ArtistOrder> onUpdate;

  void _markDelivered(BuildContext context) {
    onUpdate(
      order.copyWith(
        status: ArtistOrderStatus.delivered,
        statusText: 'Delivered',
        deliveredAt: DateTime.now(),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _OrderDetailsShell(
      title: 'Shipped',
      order: order,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopSummary(order: order),
          const SizedBox(height: 12),

          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shipping Details',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                _kv(
                  'Tracking #',
                  order.trackingNumber?.trim().isEmpty ?? true
                      ? '—'
                      : order.trackingNumber!.trim(),
                ),
                _kv(
                  'Carrier',
                  (order.carrier ?? '').trim().isEmpty
                      ? '—'
                      : order.carrier!.trim(),
                ),
                _kv(
                  'Shipped',
                  order.shippedAt == null ? '—' : _fmtDate(order.shippedAt!),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E8B57),
                foregroundColor: AppColors.snow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: () => _markDelivered(context),
              child: const Text(
                'Mark Delivered',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (order.completedPhotos.isNotEmpty) ...[
            const Text(
              'Completed Photos',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _PhotoGrid(bytes: order.completedPhotos),
          ],
        ],
      ),
    );
  }
}

/// =======================================================
/// Shared UI
/// =======================================================
class _OrderDetailsShell extends StatelessWidget {
  const _OrderDetailsShell({
    required this.title,
    required this.order,
    required this.body,
  });

  final String title;
  final ArtistOrder order;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: JntModalAppBar(
        onClose: () => Navigator.of(context).pop(),
        closeTooltip: 'Close artist order details',
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        children: [body],
      ),
    );
  }
}

class _TopSummary extends StatelessWidget {
  const _TopSummary({required this.order});
  final ArtistOrder order;

  @override
  Widget build(BuildContext context) {
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
                    _StatusChip(status: order.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  order.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
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
                if (order.status == ArtistOrderStatus.inProgress) ...[
                  _ProgressBar(value: (order.progress ?? 0.0).clamp(0.0, 1.0)),
                  const SizedBox(height: 10),
                ],
                Text(
                  order.statusText,
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesBlock extends StatelessWidget {
  const _NotesBlock({required this.order});
  final ArtistOrder order;

  @override
  Widget build(BuildContext context) {
    final clientNotes = (order.clientNotes ?? '').trim();
    final artistNotes = (order.artistNotes ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Notes', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        _miniSection(
          title: 'Client Notes',
          text: clientNotes.isEmpty ? '—' : clientNotes,
        ),
        const SizedBox(height: 10),
        _miniSection(
          title: 'Artist Notes',
          text: artistNotes.isEmpty ? '—' : artistNotes,
        ),
      ],
    );
  }

  Widget _miniSection({required String title, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blackCat.withValues(alpha: 0.03),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
              height: 1.25,
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

  String _normalizeImagePath(String raw) {
    var p = raw.trim();
    if (p.isEmpty) return '';
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      final decodedRest = Uri.decodeFull(rest);
      if (rest.startsWith('data:') ||
          rest.startsWith('blob:') ||
          decodedRest.startsWith('data:') ||
          decodedRest.startsWith('blob:') ||
          decodedRest.startsWith('http://') ||
          decodedRest.startsWith('https://')) {
        p = decodedRest;
      }
    }
    if (p.startsWith('data%3A') ||
        p.startsWith('blob%3A') ||
        p.startsWith('http%3A') ||
        p.startsWith('https%3A')) {
      p = Uri.decodeFull(p);
    }
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final raw = imageAsset ?? 'assets/images/order_thumb_1.png';
    final path = _normalizeImagePath(raw);
    final isNetwork =
        path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:') ||
        path.startsWith('data:') ||
        path.startsWith('content://');
    final isAsset = path.startsWith('assets/');
    final isFileUri = path.startsWith('file://');
    final isFilePath =
        !kIsWeb && (path.startsWith('/') || path.contains(':\\'));
    Widget image;
    if (isNetwork || (kIsWeb && !isAsset)) {
      image = Image.network(
        path,
        height: 64,
        width: 64,
        fit: BoxFit.cover,
        cacheWidth: 192,
        cacheHeight: 192,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    } else if (isAsset) {
      image = Image.asset(
        path,
        height: 64,
        width: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    } else if (isFileUri || isFilePath) {
      final localPath = isFileUri ? path.replaceFirst('file://', '') : path;
      image = Image.file(
        File(localPath),
        height: 64,
        width: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    } else {
      image = const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: image is SizedBox
          ? Container(
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
            )
          : image,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
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

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.bytes, this.onDelete});

  final List<Uint8List> bytes;

  /// If provided, show delete icon
  final void Function(int index)? onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: bytes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          return SizedBox(
            width: 112,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: Image.memory(
                      bytes[i],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      cacheWidth: kMaxImageDecodeDimension,
                    ),
                  ),
                ),
                if (onDelete != null)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Semantics(
                      button: true,
                      label: 'Remove photo ${i + 1}',
                      onTap: () => onDelete!(i),
                      child: ExcludeSemantics(
                        child: InkWell(
                      onTap: () => onDelete!(i),
                      borderRadius: BorderRadius.zero,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.blackCat.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppColors.snow,
                        ),
                      ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shared Card Container (matches your style)
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;
  final EdgeInsets? padding = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
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

InputDecoration _dec(String label, String hint) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: TextStyle(fontSize: 12, color: AppColors.blackCat.withValues(alpha: 0.35)),
    labelStyle: TextStyle(fontSize: 13, color: AppColors.blackCat.withValues(alpha: 0.7)),
    filled: true,
    fillColor: AppColors.snow,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(
        color: AppColors.blackCat.withValues(alpha: 0.55),
        width: 1.6,
      ),
    ),
  );
}

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.60),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

String _fmtDate(DateTime d) {
  const months = [
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
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
