import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../utils/date_format_utils.dart';

enum _TrackStep { preparing, labelReady, shipped, delivered }

class TrackOrderPage extends StatefulWidget {
  const TrackOrderPage({
    super.key,
    this.onBackHome,
    this.order,
    this.orderId,
    this.sourceCollection,
  });

  final VoidCallback? onBackHome;

  /// Whatever order object the caller already has on screen (ClientOrder,
  /// a brand order row, etc.). Only its `id`/`sourceCollection` are read,
  /// via dynamic access, so this page doesn't depend on any one model type.
  final dynamic order;

  /// Preferred over deriving from [order] when both are known to the caller.
  final String? orderId;
  final String? sourceCollection;

  @override
  State<TrackOrderPage> createState() => _TrackOrderPageState();
}

class _TrackOrderPageState extends State<TrackOrderPage> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _row;
  bool _loading = true;

  String? _dynamicString(String field) {
    final obj = widget.order;
    if (obj == null) return null;
    try {
      final dynamic value = switch (field) {
        'id' => obj.id,
        'sourceCollection' => obj.sourceCollection,
        _ => null,
      };
      final text = value?.toString().trim();
      return (text == null || text.isEmpty) ? null : text;
    } catch (_) {
      return null;
    }
  }

  String? get _orderId => widget.orderId ?? _dynamicString('id');
  String? get _sourceCollection =>
      widget.sourceCollection ?? _dynamicString('sourceCollection');
  String get _requestTable => _sourceCollection == 'Company_Custom_Requests'
      ? 'company_custom_requests'
      : 'client_custom_requests';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = _orderId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final row = await _supabase
          .from(_requestTable)
          .select()
          .eq('id', id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _row = row == null ? null : Map<String, dynamic>.from(row);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return const <String, dynamic>{};
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return const <String, dynamic>{};
  }

  String _firstNonEmpty(Iterable<Object?> values) {
    for (final raw in values) {
      final value = (raw ?? '').toString().trim();
      if (value.isNotEmpty && value != '-') return value;
    }
    return '';
  }

  DateTime? _asDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Track order',
      child: Scaffold(
        backgroundColor: AppColors.snow,
        appBar: AppBar(
          backgroundColor: AppColors.alabaster,
          surfaceTintColor: AppColors.alabaster,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () {
              widget.onBackHome?.call();
              Navigator.pop(context);
            },
          ),
          title: const Text(
            'Track Order',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
        ),
        body: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_orderId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No order selected.\nGo to Orders and choose an order to track.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final row = _row;
    if (row == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This order could not be found.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    final data = _asMap(row['data']);
    final payload = _asMap(row['payload']);
    final details = _asMap(row['details']);

    final shippingStatus = _firstNonEmpty([
      row['shipping_status'],
      data['shippingStatus'],
      payload['shippingStatus'],
      details['shippingStatus'],
    ]).toLowerCase();
    final topStatus = _firstNonEmpty([
      row['status'],
      data['status'],
      payload['status'],
      details['status'],
    ]).toLowerCase();
    final shippedAt = _asDate(
      _firstNonEmpty([row['shipped_at'], data['shippedAt']]).isEmpty
          ? null
          : _firstNonEmpty([row['shipped_at'], data['shippedAt']]),
    );
    final deliveredAt = _asDate(
      _firstNonEmpty([
        row['delivered_at'],
        data['deliveredAt'],
      ]).isEmpty
          ? null
          : _firstNonEmpty([row['delivered_at'], data['deliveredAt']]),
    );
    final estimatedDelivery = _asDate(row['estimated_delivery_at']);

    final carrier = _firstNonEmpty([
      row['shipping_label_carrier'],
      row['shipped_by_courier'],
      data['shippedByCourier'],
      payload['shippedByCourier'],
      details['shippedByCourier'],
    ]);
    final tracking = _firstNonEmpty([
      row['shipping_label_tracking_number'],
      row['tracking_number'],
      data['trackingNumber'],
      payload['trackingNumber'],
      details['trackingNumber'],
    ]);

    final step = _stepFor(
      shippingStatus: shippingStatus,
      topStatus: topStatus,
      hasShippedAt: shippedAt != null,
      hasDeliveredAt: deliveredAt != null,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _timeline(step),
        const SizedBox(height: 20),
        _softBox(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Carrier', carrier.isEmpty ? 'Not yet assigned' : carrier),
              _kv(
                'Tracking Number',
                tracking.isEmpty ? 'Not yet available' : tracking,
              ),
              _kv(
                'Estimated Delivery',
                estimatedDelivery == null
                    ? 'Not yet available'
                    : formatDateMdyOrDash(estimatedDelivery),
              ),
              if (deliveredAt != null)
                _kv('Delivered', formatDateMdyOrDash(deliveredAt)),
            ],
          ),
        ),
        if (carrier.isNotEmpty && tracking.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.blackCat,
                foregroundColor: AppColors.snow,
                side: const BorderSide(color: AppColors.blackCat),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: () => _openCarrierTracking(carrier, tracking),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text(
                'Track on Carrier Site',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  _TrackStep _stepFor({
    required String shippingStatus,
    required String topStatus,
    required bool hasShippedAt,
    required bool hasDeliveredAt,
  }) {
    if (topStatus == 'delivered' ||
        shippingStatus == 'delivered' ||
        hasDeliveredAt) {
      return _TrackStep.delivered;
    }
    if (topStatus == 'shipped' ||
        shippingStatus == 'in_transit' ||
        hasShippedAt) {
      return _TrackStep.shipped;
    }
    if (shippingStatus == 'label_ready') {
      return _TrackStep.labelReady;
    }
    return _TrackStep.preparing;
  }

  Widget _timeline(_TrackStep step) {
    const steps = [
      (_TrackStep.preparing, 'Preparing', Icons.brush_rounded),
      (_TrackStep.labelReady, 'Label Created', Icons.qr_code_2_rounded),
      (_TrackStep.shipped, 'Shipped', Icons.local_shipping_rounded),
      (_TrackStep.delivered, 'Delivered', Icons.check_circle_rounded),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in steps)
          _timelineRow(
            label: entry.$2,
            icon: entry.$3,
            done: entry.$1.index <= step.index,
            isLast: entry.$1 == _TrackStep.delivered,
          ),
      ],
    );
  }

  Widget _timelineRow({
    required String label,
    required IconData icon,
    required bool done,
    required bool isLast,
  }) {
    final color = done
        ? AppColors.blackCat
        : AppColors.blackCat.withValues(alpha: 0.3);
    return Semantics(
      label: '$label, ${done ? 'complete' : 'pending'}',
      child: ExcludeSemantics(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(icon, color: color, size: 22),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: color,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 20, top: 2),
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: done ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _softBox(Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.alabaster,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: child,
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: AppColors.blackCat.withValues(alpha: 0.65),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCarrierTracking(String carrier, String tracking) async {
    final encoded = Uri.encodeComponent(tracking);
    final url = switch (carrier.toUpperCase()) {
      'UPS' => 'https://www.ups.com/track?loc=en_US&tracknum=$encoded',
      'FEDEX' => 'https://www.fedex.com/fedextrack/?trknbr=$encoded',
      'DHL' =>
        'https://www.dhl.com/us-en/home/tracking.html?tracking-id=$encoded',
      _ => 'https://tools.usps.com/go/TrackConfirmAction?tLabels=$encoded',
    };
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
