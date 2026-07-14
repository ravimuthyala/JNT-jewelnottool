// artist_shipped_request_sheet.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_request_v2.dart';
import '../services/storage_url_resolver.dart';
import '../theme/app_colors.dart';
import '../widgets/group_client_measurements_tabs.dart';
import '../utils/request_nfc_details_loader.dart';

Future<void> showShippedRequestSheet({
  required BuildContext context,
  required ClientRequestV2 request,
  required VoidCallback onClose,
  required Future<void> Function() onMarkDelivered,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShippedRequestSheet(
      request: request,
      onClose: onClose,
      // Use caller-provided handler so status + notifications/emails stay in sync.
      onMarkDelivered: onMarkDelivered,
    ),
  );
}

class _ShippedRequestSheet extends StatefulWidget {
  const _ShippedRequestSheet({
    required this.request,
    required this.onClose,
    required this.onMarkDelivered,
  });

  final ClientRequestV2 request;
  final VoidCallback onClose;
  final Future<void> Function() onMarkDelivered;

  @override
  State<_ShippedRequestSheet> createState() => _ShippedRequestSheetState();
}

class _ShipmentInfo {
  const _ShipmentInfo({
    required this.courier,
    required this.tracking,
    required this.shippedAt,
  });

  final String courier;
  final String tracking;
  final DateTime? shippedAt;
}

class _ShippedRequestSheetState extends State<_ShippedRequestSheet> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isMarkingDelivered = false;
  int _selectedMeasurementTab = 0;
  String get _requestTable =>
      widget.request.sourceCollection == 'Company_Custom_Requests'
      ? 'company_custom_requests'
      : 'client_custom_requests';

  String get _requestDetailsTable =>
      widget.request.sourceCollection == 'Company_Custom_Requests'
      ? 'company_custom_requests_details'
      : 'client_custom_requests_details';

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return <String, dynamic>{};
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  List<Object?> _asList(Object? value) {
    if (value is Iterable) return value.toList(growable: false);
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return const <Object?>[];
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) return List<Object?>.from(decoded);
      } catch (_) {}
    }
    return const <Object?>[];
  }

  String _firstNonEmpty(List<Object?> values, {String fallback = ''}) {
    for (final raw in values) {
      final text = (raw ?? '').toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  DateTime? _asDateTime(Object? raw) {
    if (raw is DateTime) return raw;
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  double? _asAmount(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().trim().replaceAll(RegExp(r'[^0-9.]'), '');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  double? _amountFromMaps(Iterable<Map<String, dynamic>> maps) {
    for (final map in maps) {
      final direct = _asAmount(
        map['artist_final_amount'] ??
            map['final_amount_by_artist'] ??
            map['artistFinalAmount'] ??
            map['finalAmountByArtist'] ??
            map['payment_amount'] ??
            map['paid_amount'] ??
            map['amount'] ??
            map['total_amount'],
      );
      if (direct != null && direct > 0) return direct;

      final data = _asMap(map['data']);
      final payload = _asMap(map['payload']);
      final details = _asMap(map['details']);
      final payment = _asMap(map['payment']);
      final payments = _asMap(map['payments']);
      final artistQuote = _asMap(map['artistQuote'] ?? map['artist_quote']);
      final dataArtistQuote = _asMap(
        data['artistQuote'] ?? data['artist_quote'],
      );
      final payloadArtistQuote = _asMap(
        payload['artistQuote'] ?? payload['artist_quote'],
      );
      final detailsArtistQuote = _asMap(
        details['artistQuote'] ?? details['artist_quote'],
      );

      final nestedMaps = <Map<String, dynamic>>[
        data,
        payload,
        details,
        payment,
        payments,
        artistQuote,
        dataArtistQuote,
        payloadArtistQuote,
        detailsArtistQuote,
      ];

      for (final nested in nestedMaps) {
        final nestedAmount = _asAmount(
          nested['artistFinalAmount'] ??
              nested['finalAmountByArtist'] ??
              nested['artist_final_amount'] ??
              nested['final_amount_by_artist'] ??
              nested['total'] ??
              nested['amount'] ??
              nested['paymentAmount'] ??
              nested['payment_amount'],
        );
        if (nestedAmount != null && nestedAmount > 0) return nestedAmount;
      }
    }
    return null;
  }

  Future<double?> _loadAcceptedArtistAmount() async {
    final local = widget.request.artistFinalAmount;
    if (local != null && local > 0) return local;

    final maps = <Map<String, dynamic>>[];
    try {
      final root = await _supabase
          .from(_requestTable)
          .select()
          .eq('id', widget.request.id)
          .maybeSingle();
      if (root != null) maps.add(Map<String, dynamic>.from(root));

      final detailRows = await _supabase
          .from(_requestDetailsTable)
          .select()
          .eq('request_id', widget.request.id);
      for (final row in detailRows) {
        maps.add(_asMap(row));
      }
    } catch (_) {
      // Keep modal usable if lookup fails.
    }

    return _amountFromMaps(maps);
  }

  _ShipmentInfo _fallbackShipmentInfo() {
    return _ShipmentInfo(
      courier: (widget.request.shippedByCourier ?? '').trim(),
      tracking: (widget.request.trackingNumber ?? '').trim(),
      shippedAt: widget.request.shippedAt,
    );
  }

  Future<_ShipmentInfo> _loadShipmentInfo() async {
    final fallback = _fallbackShipmentInfo();
    try {
      final row = await _supabase
          .from(_requestTable)
          .select()
          .eq('id', widget.request.id)
          .maybeSingle();
      if (row == null) return fallback;
      final root = Map<String, dynamic>.from(row);
      final payload = _asMap(root['payload']);
      final details = _asMap(root['details']);
      final data = _asMap(root['data']);
      final shipping = _asMap(root['shipping']);
      final nested = <Map<String, dynamic>>[
        root,
        payload,
        details,
        data,
        shipping,
      ];

      String pick(List<String> keys) {
        final values = <Object?>[];
        for (final map in nested) {
          for (final key in keys) {
            values.add(map[key]);
          }
        }
        return _firstNonEmpty(values);
      }

      final courier = _firstNonEmpty(<Object?>[
        pick(const <String>[
          'shipped_by_courier',
          'shippedByCourier',
          'shipping_label_carrier',
          'shippingLabelCarrier',
          'carrier',
          'courier',
        ]),
        fallback.courier,
      ]);
      final tracking = _firstNonEmpty(<Object?>[
        pick(const <String>[
          'tracking_number',
          'trackingNumber',
          'shipping_label_tracking_number',
          'shippingLabelTrackingNumber',
          'tracking',
        ]),
        fallback.tracking,
      ]);
      DateTime? shippedAt;
      for (final raw in <Object?>[
        root['shipped_at'],
        root['artist_shipped_at'],
        root['order_shipped_at'],
        payload['shippedAt'],
        details['shippedAt'],
        data['shippedAt'],
        shipping['shippedAt'],
        shipping['shipped_at'],
      ]) {
        shippedAt = _asDateTime(raw);
        if (shippedAt != null) break;
      }
      return _ShipmentInfo(
        courier: courier,
        tracking: tracking,
        shippedAt: shippedAt ?? fallback.shippedAt,
      );
    } catch (_) {
      return fallback;
    }
  }

  List<String> _modalClientPhotos() {
    final out = <String>[];
    for (final raw in widget.request.clientImages) {
      final s = raw.trim();
      if (s.isNotEmpty && !out.contains(s)) out.add(s);
    }
    final preview = widget.request.previewImageAsset.trim();
    if (out.isEmpty && preview.isNotEmpty) out.add(preview);
    return out;
  }

  String _heroPhotoSource() {
    final acceptedProfile = _normalizeImagePath(
      widget.request.acceptedClientProfileImage.trim(),
    );
    if (acceptedProfile.isNotEmpty) return acceptedProfile;

    final clientProfile = _normalizeImagePath(
      widget.request.clientProfileImage.trim(),
    );
    if (clientProfile.isNotEmpty) return clientProfile;

    return '';
  }

  Future<String> _resolveShippedClientProfileImage() async {
    final accepted = _normalizeImagePath(
      widget.request.acceptedClientProfileImage.trim(),
    );
    if (accepted.isNotEmpty) return accepted;

    final existing = _normalizeImagePath(
      widget.request.clientProfileImage.trim(),
    );
    if (existing.isNotEmpty) return existing;

    return _lookupShippedClientProfileImage(
      email: widget.request.clientEmail.trim(),
      name: widget.request.clientName.trim(),
    );
  }

  Future<String> _lookupShippedClientProfileImage({
    required String email,
    required String name,
  }) async {
    String firstNonEmpty(List<Object?> values) {
      for (final raw in values) {
        final text = (raw ?? '').toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
      return '';
    }

    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
      return const <String, dynamic>{};
    }

    String imageFromRow(Map<String, dynamic> row) {
      final profile = asMap(row['profile']);
      final basic = asMap(row['basic']);
      final client = asMap(row['client']);
      final clientProfile = asMap(client['profile']);
      final data = asMap(row['data']);
      return firstNonEmpty(<Object?>[
        row['client_profile_image'],
        row['clientProfileImage'],
        row['profileImageUrl'],
        row['profile_image_url'],
        row['profile_picture_url'],
        row['profilePhotoUrl'],
        row['profile_photo_url'],
        row['avatarUrl'],
        row['avatar_url'],
        row['photoUrl'],
        row['photo_url'],
        profile['profileImageUrl'],
        profile['profile_image_url'],
        profile['profile_picture_url'],
        profile['avatarUrl'],
        profile['avatar_url'],
        profile['photoUrl'],
        profile['photo_url'],
        basic['profileImageUrl'],
        basic['profile_image_url'],
        basic['profile_picture_url'],
        basic['avatarUrl'],
        basic['avatar_url'],
        basic['photoUrl'],
        basic['photo_url'],
        client['profileImageUrl'],
        client['profile_image_url'],
        client['profile_picture_url'],
        client['avatarUrl'],
        client['avatar_url'],
        client['photoUrl'],
        client['photo_url'],
        clientProfile['profileImageUrl'],
        clientProfile['profile_image_url'],
        clientProfile['profile_picture_url'],
        clientProfile['avatarUrl'],
        clientProfile['avatar_url'],
        clientProfile['photoUrl'],
        clientProfile['photo_url'],
        data['clientProfileImage'],
        data['client_profile_image'],
        data['profileImageUrl'],
        data['profile_image_url'],
        data['avatarUrl'],
        data['avatar_url'],
        data['photoUrl'],
        data['photo_url'],
      ]);
    }

    Future<String> lookupBy(String table, String column, String value) async {
      final needle = value.trim();
      if (needle.isEmpty) return '';
      try {
        final row = await Supabase.instance.client
            .from(table)
            .select()
            .eq(column, needle)
            .limit(1)
            .maybeSingle();
        if (row == null) return '';
        return imageFromRow((row as Map).cast<String, dynamic>());
      } catch (_) {
        return '';
      }
    }

    if (email.trim().isNotEmpty) {
      for (final table in const ['client', 'clients', 'client_artist']) {
        for (final column in const ['email', 'client_email']) {
          final found = await lookupBy(
            table,
            column,
            email.trim().toLowerCase(),
          );
          if (found.isNotEmpty) return found;
        }
      }
    }

    if (name.trim().isNotEmpty) {
      for (final table in const ['client', 'clients', 'client_artist']) {
        for (final column in const [
          'name',
          'full_name',
          'display_name',
          'client_name',
        ]) {
          final found = await lookupBy(table, column, name.trim());
          if (found.isNotEmpty) return found;
        }
      }
    }

    return '';
  }

  @override
  void didUpdateWidget(covariant _ShippedRequestSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild when request data changes to ensure images are synced
    if (oldWidget.request != widget.request) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;
    final sheetMediaQuery = MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(1.0));

    final modalClientPhotos = _modalClientPhotos();

    return MediaQuery(
      data: sheetMediaQuery,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(maxHeight: maxH),
          decoration: const BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                height: 5,
                width: 54,
                decoration: BoxDecoration(
                  color: AppColors.blackCat.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.zero,
                ),
              ),
              const SizedBox(height: 6),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _topHeroCentered(
                      request: widget.request,
                      onClose: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 12),

                    FutureBuilder<_ShipmentInfo>(
                      future: _loadShipmentInfo(),
                      builder: (context, snapshot) {
                        final info = snapshot.data ?? _fallbackShipmentInfo();
                        return _shipmentStatusCard(info);
                      },
                    ),

                    const SizedBox(height: 12),
                    if (_isBrandRequest(widget.request)) ...[
                      _acceptedClientDetailsSection(widget.request),
                      const SizedBox(height: 12),
                    ],
                    _measurementSection(),
                    const SizedBox(height: 12),
                    _paymentSection(),
                    const SizedBox(height: 12),
                    _clientPhotosSection(modalClientPhotos),
                    const SizedBox(height: 12),
                    _artistPhotosSection(widget.request.artistImages),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: _softBox(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            color: AppColors.blackCat.withValues(alpha: 0.65),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Delivery status updates automatically from courier tracking.',
                              style: TextStyle(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.72,
                                ),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _isMarkingDelivered
                              ? null
                              : _markDeliveredForTesting,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blackCat,
                            foregroundColor: AppColors.snow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          icon: _isMarkingDelivered
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.snow,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 18,
                                ),
                          label: Text(
                            _isMarkingDelivered
                                ? 'Updating...'
                                : 'Mark as Delivered (Test)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Temporary test action until courier integration is connected.',
                        style: TextStyle(
                          color: AppColors.blackCat.withValues(alpha: 0.58),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shipmentStatusCard(_ShipmentInfo info) {
    final courier = info.courier.trim();
    final tracking = info.tracking.trim();
    final shippedAt = info.shippedAt;
    return _softBox(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            size: 22,
            color: AppColors.blackCat,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shippedAt == null
                      ? 'Shipped'
                      : 'Shipped on ${_fmtDate(shippedAt)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                _shippingInfoRow('Shipped by', courier.isEmpty ? '-' : courier),
                const SizedBox(height: 8),
_shippingInfoRow(                  'Tracking #',                  tracking.isEmpty ? '-' : tracking,                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _openTrackingPreview(info),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blackCat,
                      foregroundColor: AppColors.snow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(Icons.travel_explore_rounded, size: 16),
                    label: const Text(
                      'Track Shipment',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
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

  Widget _shippingInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 94,
          child: Text(
            '$label:',
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.60),
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '-' : value.trim(),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_sectionTitle(title), const SizedBox(height: 10), child],
      ),
    );
  }

  Widget _emptyPhotoBox(String message) {
    return _softBox(
      Row(
        children: [
          Icon(
            Icons.image_outlined,
            color: AppColors.blackCat.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.65),
              fontWeight: FontWeight.w400,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientPhotosSection(List<String> photos) {
    return _sectionCard(
      title: 'Uploaded Photos (Client)',
      child: photos.isEmpty
          ? _emptyPhotoBox('No images uploaded')
          : _photosGrid(photos),
    );
  }

  Widget _artistPhotosSection(List<String> photos) {
    return _sectionCard(
      title: 'Uploaded Photos (Artist)',
      child: photos.isEmpty
          ? _emptyPhotoBox('No artist photos uploaded')
          : _photosGrid(photos),
    );
  }

  Future<void> _markDeliveredForTesting() async {
    setState(() => _isMarkingDelivered = true);
    try {
      await widget.onMarkDelivered();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked as delivered.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update delivery status: $e')),
      );
    } finally {
      if (mounted) setState(() => _isMarkingDelivered = false);
    }
  }

  Widget _topHeroCentered({
    required ClientRequestV2 request,
    required VoidCallback onClose,
  }) {
    final isBrandRequest = _isBrandRequest(request);
    final headerName = isBrandRequest && request.brandName.trim().isNotEmpty
        ? request.brandName.trim()
        : request.clientName;
    final headerSubtitle = isBrandRequest ? request.title.trim() : '';
    final avatarLetter = headerName.isEmpty ? '' : headerName[0].toUpperCase();

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  height: 78,
                  width: 78,
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: FutureBuilder<String>(
                      future: _resolveShippedClientProfileImage(),
                      builder: (context, snapshot) {
                        final avatarPath = _normalizeImagePath(
                          (snapshot.data ?? '').trim(),
                        );
                        if (avatarPath.isNotEmpty) {
                          return _imageForPath(avatarPath);
                        }
                        return Container(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.zero,
                            color: AppColors.balletSlippers,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            avatarLetter,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                headerName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (headerSubtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  headerSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                    color: AppColors.blackCat.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 6),
                _outlinedChip('Brand Request'),
              ],
              const SizedBox(height: 4),
              Text(
                'Order # ${request.orderNumber.trim().isNotEmpty ? request.orderNumber.trim() : request.id}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                  color: AppColors.blackCat.withValues(alpha: 0.60),
                ),
              ),
              const SizedBox(height: 10),
              _requestTypeOrderRow(request),
              const SizedBox(height: 12),
              _needBudgetRow(),
            ],
          ),
        ),
        Positioned(
          right: 6,
          top: 6,
          child: InkWell(
            borderRadius: BorderRadius.zero,
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.close_rounded,
                size: 24,
                color: AppColors.blackCat.withValues(alpha: 0.70),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _isBrandRequest(ClientRequestV2 request) =>
      request.sourceCollection == 'Company_Custom_Requests' ||
      request.orderNumber.trim().toUpperCase().startsWith('BE-') ||
      request.orderNumber.trim().toUpperCase().startsWith('BR-');

  Widget _outlinedChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF9FC0E8)),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _acceptedClientDetailsSection(ClientRequestV2 request) {
    final name = request.acceptedClientName.trim().isNotEmpty
        ? request.acceptedClientName.trim()
        : (request.clientName.trim().isNotEmpty
              ? request.clientName.trim()
              : 'Client');
    final avatarPath = _safeAcceptedClientAvatarPath(request);
    final avatarLetter = name[0].toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Client Details'),
        const SizedBox(height: 10),
        _softBox(
          Row(
            children: [
              avatarPath.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: SizedBox(
                        height: 54,
                        width: 54,
                        child: _imageForPath(avatarPath),
                      ),
                    )
                  : Container(
                      height: 54,
                      width: 54,
                      color: AppColors.balletSlippers,
                      alignment: Alignment.center,
                      child: Text(
                        avatarLetter,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _safeAcceptedClientAvatarPath(ClientRequestV2 request) {
    final accepted = _normalizeImagePath(
      request.acceptedClientProfileImage.trim(),
    );
    if (accepted.isEmpty) return '';
    final blocked = <String>{
      _normalizeImagePath(_heroPhotoSource()),
      _normalizeImagePath(request.clientProfileImage),
      _normalizeImagePath(request.previewImageAsset),
    }..removeWhere((e) => e.trim().isEmpty);
    return blocked.contains(accepted) ? '' : accepted;
  }

  Widget _requestTypeOrderRow(ClientRequestV2 r) {
    final requestType = r.isDirectRequest
        ? 'Direct Request'
        : 'Standard Request';
    final orderType = r.orderType == RequestOrderTypeV2.group
        ? 'Group Order'
        : 'Single Order';
    return _summaryPairRow(
      left: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            r.isDirectRequest
                ? Icons.arrow_outward_rounded
                : Icons.arrow_forward_rounded,
            size: 15,
            color: AppColors.blackCat,
          ),
          const SizedBox(width: 5),
          Text(
            requestType,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ],
      ),
      right: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            r.orderType == RequestOrderTypeV2.group
                ? Icons.groups_2_outlined
                : Icons.person_outline_rounded,
            size: 15,
            color: AppColors.blackCat,
          ),
          const SizedBox(width: 5),
          Text(
            orderType,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  static Widget _summaryPairRow({required Widget left, required Widget right}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: left,
              ),
            ),
          ),
        ),
        Container(width: 1, height: 18, color: AppColors.blackCatBorderLight),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: right,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _needBudgetRow() {
    return _summaryPairRow(
      left: _chipInfo(
        icon: Icons.calendar_today_outlined,
        text: 'Need by: ${_needByLabel(widget.request.neededBy)}',
      ),
      right: _chipInfo(
        icon: Icons.attach_money_rounded,
        text:
            'Budget: \$${widget.request.budgetMin} to \$${widget.request.budgetMax}',
      ),
    );
  }

  static Widget _chipInfo({required IconData icon, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.blackCat),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  static String _needByLabel(DateTime d) {
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
    const wds = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wds[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  static String _prettyLength(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  static Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
  );

  Widget _measurementSection() {
    final isGroup = widget.request.orderType == RequestOrderTypeV2.group;
    final fallbackClients = _buildGroupMeasurementClients();
    final fallbackClient = fallbackClients.isNotEmpty
        ? fallbackClients.first
        : GroupClientMeasurementData(
            name: widget.request.clientName.trim().isEmpty
                ? 'Client'
                : widget.request.clientName.trim(),
            nailShape: widget.request.nailShape,
            nailLength: widget.request.nailLength,
            leftHand: _dimsMap(widget.request.leftHand),
            rightHand: _dimsMap(widget.request.rightHand),
          );
    return FutureBuilder<RequestNfcDetails>(
      future: loadRequestNfcDetails(
        sourceCollection: widget.request.sourceCollection,
        requestId: widget.request.id,
      ),
      builder: (context, nfcSnapshot) {
        final nfc = nfcSnapshot.data ?? RequestNfcDetails.emptyConst;
        final singleClient = GroupClientMeasurementData(
          name: fallbackClient.name,
          clientEmail: fallbackClient.clientEmail,
          nailShape: fallbackClient.nailShape,
          nailLength: fallbackClient.nailLength,
          leftHand: fallbackClient.leftHand,
          rightHand: fallbackClient.rightHand,
          leftNfc: nfc.main.left,
          rightNfc: nfc.main.right,
        );
        return _sectionCard(
          title: 'Nail Dimensions',
          child: isGroup
              ? FutureBuilder<List<GroupClientMeasurementData>>(
                  future: _loadGroupMeasurementClients(),
                  builder: (context, snapshot) {
                    final clients = snapshot.data ?? fallbackClients;
                    return _compactMeasurementTabs(clients);
                  },
                )
              : _measurementBody(singleClient),
        );
      },
    );
  }

  Widget _paymentSection() {
    final paymentStatus = widget.request.paymentStatus.trim().isEmpty
        ? 'Pending'
        : widget.request.paymentStatus.trim();

    return _sectionCard(
      title: 'Payment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<double?>(
            future: _loadAcceptedArtistAmount(),
            initialData: widget.request.artistFinalAmount,
            builder: (context, snapshot) {
              final amount = snapshot.data ?? widget.request.artistFinalAmount;
              final amountText = amount != null && amount > 0
                  ? '\$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}'
                  : '-';
              return _paymentDetailRow('Final Amount by Artist', amountText);
            },
          ),
          const SizedBox(height: 10),
          _paymentDetailRow('Status', paymentStatus),
        ],
      ),
    );
  }
  Widget _paymentDetailRow(
    String label,
    String value, {
    FontWeight valueWeight = FontWeight.w700,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 122,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.60),
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: valueWeight,
              fontSize: 13.5,
              color: AppColors.blackCat,
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactMeasurementTabs(List<GroupClientMeasurementData> clients) {
    if (clients.isEmpty) {
      return _softBox(
        Text(
          'No client measurements found for this order.',
          style: TextStyle(
            color: AppColors.blackCat.withValues(alpha: 0.65),
            fontWeight: FontWeight.w500,
            fontSize: 13.5,
          ),
        ),
      );
    }

    return GroupClientMeasurementsTabs(
      clients: clients,
      compactRequestDetailsLayout: true,
      tabViewHeight: 312,
    );
  }

  Widget _measurementBody(GroupClientMeasurementData client) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _handCardFromMap(
                  'Left Hand',
                  client.leftHand,
                  nfc: client.leftNfc,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.blackCatBorderLight,
                ),
              ),
              Expanded(
                child: _handCardFromMap(
                  'Right Hand',
                  client.rightHand,
                  nfc: client.rightNfc,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Divider(height: 1, thickness: 1, color: AppColors.blackCatBorderLight),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _measureField(
                'Shape',
                client.nailShape.trim().isEmpty ? '-' : client.nailShape,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                height: 24,
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.blackCatBorderLight,
                ),
              ),
            ),
            Expanded(
              child: _measureField(
                'Length',
                _prettyLength(client.nailLength).trim().isEmpty
                    ? '-'
                    : _prettyLength(client.nailLength),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _handCardFromMap(
    String title,
    Map<String, String> dims, {
    Map<String, bool> nfc = const <String, bool>{},
  }) {
    String pick(String key) => (dims[key] ?? '').trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        const SizedBox(height: 8),
        _dimRow('Thumb', pick('thumb'), nfcRequested: nfc['thumb'] == true),
        _dimRow('Index', pick('index'), nfcRequested: nfc['index'] == true),
        _dimRow('Middle', pick('middle'), nfcRequested: nfc['middle'] == true),
        _dimRow('Ring', pick('ring'), nfcRequested: nfc['ring'] == true),
        _dimRow('Pinky', pick('pinky'), nfcRequested: nfc['pinky'] == true),
      ],
    );
  }

  Widget _dimRow(String label, String raw, {bool nfcRequested = false}) {
    String formatMm(String value) {
      final v = value.trim();
      if (v.isEmpty || v == '-') return '-';
      final cleaned = v.replaceAll(RegExp(r'[^0-9.]'), '');
      final parsed = double.tryParse(cleaned);
      if (parsed == null) return v;
      return '${parsed.toStringAsFixed(2)} mm';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.blackCat.withValues(alpha: 0.60),
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (nfcRequested) ...[
                    _nfcDimensionChip(),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    formatMm(raw),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nfcDimensionChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      child: const Text(
        'NFC',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: AppColors.blackCat,
          height: 1.0,
        ),
      ),
    );
  }

  Future<List<GroupClientMeasurementData>>
  _loadGroupMeasurementClients() async {
    final merged = <GroupClientMeasurementData>[];
    final seen = <String>{};
    final nfcDetails = await loadRequestNfcDetails(
      sourceCollection: widget.request.sourceCollection,
      requestId: widget.request.id,
    );

    void addClient(
      GroupClientMeasurementData client, {
      String email = '',
      String id = '',
    }) {
      final name = client.name.trim();
      final keys = <String>{
        if (email.trim().isNotEmpty) 'email:${email.trim().toLowerCase()}',
        if (id.trim().isNotEmpty) 'id:${id.trim().toLowerCase()}',
        if (name.isNotEmpty) 'name:${name.toLowerCase()}',
      }..removeWhere((e) => e.isEmpty);
      if (keys.isEmpty) return;
      if (keys.any(seen.contains)) return;
      seen.addAll(keys);
      merged.add(client);
    }

    // Submitted/accepted client must always be first.
    addClient(
      GroupClientMeasurementData(
        name: widget.request.clientName.trim().isEmpty
            ? 'Client'
            : widget.request.clientName.trim(),
        clientEmail: widget.request.clientEmail,
        nailShape: widget.request.nailShape,
        nailLength: widget.request.nailLength,
        leftHand: _dimsMap(widget.request.leftHand),
        rightHand: _dimsMap(widget.request.rightHand),
        leftNfc: nfcDetails.main.left,
        rightNfc: nfcDetails.main.right,
      ),
      email: widget.request.clientEmail,
    );

    Map<String, String> dimsFrom(Object? source, {required bool left}) {
      final map = _asMap(source);
      if (map.isEmpty) return const <String, String>{};
      final nested = _asMap(map['dimensions']);
      final data = nested.isNotEmpty ? nested : map;

      String pick(String finger) {
        final upper = finger[0].toUpperCase() + finger.substring(1);
        final candidates = left
            ? <String>[finger, 'l$upper', 'left$upper', 'left_$finger']
            : <String>[finger, 'r$upper', 'right$upper', 'right_$finger'];
        for (final key in candidates) {
          final text = (data[key] ?? '').toString().trim();
          if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
        }
        return '';
      }

      return <String, String>{
        'thumb': pick('thumb'),
        'index': pick('index'),
        'middle': pick('middle'),
        'ring': pick('ring'),
        'pinky': pick('pinky'),
      };
    }

    Map<String, String> firstDims(List<Object?> sources, {required bool left}) {
      for (final source in sources) {
        final dims = dimsFrom(source, left: left);
        if (dims.values.any((v) => v.trim().isNotEmpty)) return dims;
      }
      return const <String, String>{};
    }

    void updateSubmittedClientFromSource(Map<String, dynamic> source) {
      if (merged.isEmpty || source.isEmpty) return;

      final payload = _asMap(source['payload']);
      final details = _asMap(source['details']);
      final data = _asMap(source['data']);
      final requestDetails = _asMap(
        source['requestDetails'] ?? source['request_details'],
      );
      final orderData = _asMap(
        source['order'] ?? source['orderData'] ?? source['order_data'],
      );
      final sources = <Map<String, dynamic>>[
        source,
        payload,
        details,
        data,
        requestDetails,
        orderData,
      ];

      final leftSources = <Object?>[];
      final rightSources = <Object?>[];
      for (final item in sources) {
        final nailPreferences = _asMap(
          item['nailPreferences'] ?? item['nail_preferences'],
        );
        final snapshotNailPreferences = _asMap(
          _asMap(
            item['clientProfileSnapshot'] ?? item['client_profile_snapshot'],
          )['nailPreferences'],
        );
        leftSources.addAll(<Object?>[
          item['leftHandDimensions'],
          item['left_hand_dimensions'],
          nailPreferences['leftHandDimensions'],
          nailPreferences['left_hand_dimensions'],
          nailPreferences['dimensions'],
          snapshotNailPreferences['dimensions'],
          item['dimensions'],
        ]);
        rightSources.addAll(<Object?>[
          item['rightHandDimensions'],
          item['right_hand_dimensions'],
          nailPreferences['rightHandDimensions'],
          nailPreferences['right_hand_dimensions'],
          nailPreferences['dimensions'],
          snapshotNailPreferences['dimensions'],
          item['dimensions'],
        ]);
      }

      final left = firstDims(leftSources, left: true);
      final right = firstDims(rightSources, left: false);
      if (left.values.every((v) => v.trim().isEmpty) &&
          right.values.every((v) => v.trim().isEmpty)) {
        return;
      }

      final current = merged.first;
      merged[0] = GroupClientMeasurementData(
        name: current.name,
        clientEmail: current.clientEmail,
        nailShape: current.nailShape,
        nailLength: current.nailLength,
        leftHand: left.values.any((v) => v.trim().isNotEmpty)
            ? left
            : current.leftHand,
        rightHand: right.values.any((v) => v.trim().isNotEmpty)
            ? right
            : current.rightHand,
        leftNfc: current.leftNfc,
        rightNfc: current.rightNfc,
      );
    }

    void addGroupClientFromMap(Map<String, dynamic> client, int index) {
      if (client.isEmpty) return;
      final email = _firstNonEmpty(<Object?>[
        client['clientEmail'],
        client['client_email'],
        client['email'],
      ]).toLowerCase();
      final id = _firstNonEmpty(<Object?>[
        client['clientId'],
        client['client_id'],
        client['id'],
        client['uid'],
      ]);
      final name = _firstNonEmpty(<Object?>[
        client['clientName'],
        client['client_name'],
        client['name'],
        client['displayName'],
        client['display_name'],
      ], fallback: 'Client $index');
      final savedNails = _asMap(client['savedNails'] ?? client['saved_nails']);
      final draftNails = _asMap(client['draftNails'] ?? client['draft_nails']);
      final nailPreferences = _asMap(
        client['nailPreferences'] ?? client['nail_preferences'],
      );
      final nailSource = savedNails.isNotEmpty
          ? savedNails
          : (draftNails.isNotEmpty ? draftNails : nailPreferences);
      final left = firstDims(<Object?>[
        client['leftHandDimensions'],
        client['left_hand_dimensions'],
        nailSource['leftHandDimensions'],
        nailSource['left_hand_dimensions'],
        nailSource['dimensions'],
        client['dimensions'],
      ], left: true);
      final right = firstDims(<Object?>[
        client['rightHandDimensions'],
        client['right_hand_dimensions'],
        nailSource['rightHandDimensions'],
        nailSource['right_hand_dimensions'],
        nailSource['dimensions'],
        client['dimensions'],
      ], left: false);
      addClient(
        GroupClientMeasurementData(
          name: name,
          clientEmail: email,
          nailShape: _firstNonEmpty(<Object?>[
            client['nailShape'],
            client['nail_shape'],
            nailSource['shape'],
            nailSource['nailShape'],
            nailSource['nail_shape'],
          ], fallback: widget.request.nailShape),
          nailLength: _firstNonEmpty(<Object?>[
            client['nailLength'],
            client['nail_length'],
            nailSource['length'],
            nailSource['nailLength'],
            nailSource['nail_length'],
          ], fallback: widget.request.nailLength),
          leftHand: left,
          rightHand: right,
          leftNfc:
              (nfcDetails.groupBySlotIndex[index] ??
                      RequestFingerNfcSelection.emptyConst)
                  .left,
          rightNfc:
              (nfcDetails.groupBySlotIndex[index] ??
                      RequestFingerNfcSelection.emptyConst)
                  .right,
        ),
        email: email,
        id: id,
      );
    }

    void addGroupClientsFromSource(Map<String, dynamic> source) {
      updateSubmittedClientFromSource(source);

      final payload = _asMap(source['payload']);
      final details = _asMap(source['details']);
      final data = _asMap(source['data']);
      final requestDetails = _asMap(
        source['requestDetails'] ?? source['request_details'],
      );
      final orderData = _asMap(
        source['order'] ?? source['orderData'] ?? source['order_data'],
      );
      final nestedSources = <Map<String, dynamic>>[
        source,
        payload,
        details,
        data,
        requestDetails,
        orderData,
      ];
      var index = 1;
      for (final nested in nestedSources) {
        final groupSources = <Object?>[
          _asMap(nested['groupOrder'] ?? nested['group_order'])['clients'],
          nested['groupClients'],
          nested['group_clients'],
          nested['selectedGroupClients'],
          nested['selected_group_clients'],
          nested['groupClientMeasurements'],
          nested['group_client_measurements'],
        ];
        for (final groupSource in groupSources) {
          for (final rawClient in _asList(groupSource)) {
            addGroupClientFromMap(_asMap(rawClient), index++);
          }
        }
      }
    }

    try {
      final root = await _supabase
          .from(_requestTable)
          .select()
          .eq('id', widget.request.id)
          .maybeSingle();
      if (root != null)
        addGroupClientsFromSource(Map<String, dynamic>.from(root));
      final detailRows = await _supabase
          .from(_requestDetailsTable)
          .select()
          .eq('request_id', widget.request.id);
      for (final row in detailRows) {
        final map = _asMap(row);
        addGroupClientsFromSource(map);
        addGroupClientsFromSource(_asMap(map['data']));
      }
    } catch (_) {
      // Keep modal usable if RLS blocks lookup.
    }

    for (final client in _buildGroupMeasurementClients()) {
      addClient(client);
    }

    return merged.isEmpty ? _buildGroupMeasurementClients() : merged;
  }

  List<GroupClientMeasurementData> _buildGroupMeasurementClients() {
    final clients = <GroupClientMeasurementData>[];
    final seen = <String>{};

    String clean(String value) => value.trim();
    String keyFor({String id = '', String email = '', String name = ''}) {
      final normalizedId = id.trim().toLowerCase();
      if (normalizedId.isNotEmpty) return 'id:$normalizedId';
      final normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail.isNotEmpty) return 'email:$normalizedEmail';
      final normalizedName = name.trim().toLowerCase();
      return normalizedName.isEmpty ? '' : 'name:$normalizedName';
    }

    void addClient({
      required String name,
      String id = '',
      String email = '',
      required String nailShape,
      required String nailLength,
      required NailDimensionsV2 leftHand,
      required NailDimensionsV2 rightHand,
      int? slotIndex,
    }) {
      final resolvedName = clean(name).isNotEmpty
          ? clean(name)
          : 'Client ${slotIndex ?? clients.length + 1}';
      final keys = <String>{
        keyFor(id: id, email: email, name: resolvedName),
        if (email.trim().isNotEmpty) 'email:${email.trim().toLowerCase()}',
        if (resolvedName.trim().isNotEmpty)
          'name:${resolvedName.trim().toLowerCase()}',
      }..removeWhere((e) => e.isEmpty);
      if (keys.any(seen.contains)) return;
      seen.addAll(keys);
      clients.add(
        GroupClientMeasurementData(
          name: resolvedName,
          nailShape: nailShape,
          nailLength: nailLength,
          leftHand: _dimsMap(leftHand),
          rightHand: _dimsMap(rightHand),
        ),
      );
    }

    // Submitted/accepted client must always be first.
    addClient(
      name: widget.request.clientName,
      email: widget.request.clientEmail,
      nailShape: widget.request.nailShape,
      nailLength: widget.request.nailLength,
      leftHand: widget.request.leftHand,
      rightHand: widget.request.rightHand,
    );

    for (final client in widget.request.groupClients) {
      addClient(
        name: client.clientName,
        id: client.clientId,
        email: client.clientEmail,
        nailShape: client.nailShape,
        nailLength: client.nailLength,
        leftHand: client.leftHand,
        rightHand: client.rightHand,
        slotIndex: client.slotIndex,
      );
      if (clients.length >= 16) break;
    }

    return clients;
  }

  Map<String, String> _dimsMap(NailDimensionsV2 dims) {
    return <String, String>{
      'thumb': dims.thumb,
      'index': dims.index,
      'middle': dims.middle,
      'ring': dims.ring,
      'pinky': dims.pinky,
    };
  }

  Widget _measureField(String label, String value) {
    final trimmed = value.trim();
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.blackCat.withValues(alpha: 0.60),
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            trimmed.isEmpty ? '-' : trimmed,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ),
      ],
    );
  }

  static Widget _softBox(Widget child) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: child,
    );
  }

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

  Widget _imageForPath(String raw) {
    final path = _normalizeImagePath(raw);

    Widget fallback() => Container(
      color: AppColors.blackCat.withValues(alpha: 0.06),
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.blackCat.withValues(alpha: 0.35),
      ),
    );

    if (path.isEmpty) return fallback();
    final dataBytes = _decodeDataImageBytes(path);
    if (dataBytes != null && dataBytes.isNotEmpty) {
      return Image.memory(
        dataBytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    final isNetwork =
        path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:') ||
        path.startsWith('content://');
    final isAsset = path.startsWith('assets/');
    final isFileUri = path.startsWith('file://');
    final isFilePath =
        !kIsWeb && (path.startsWith('/') || path.contains(':\\'));

    if (isNetwork || path.startsWith('gs://') || (kIsWeb && !isAsset)) {
      return FutureBuilder<String>(
        future: StorageUrlResolver.resolve(path).then((v) {
          final resolved = (v ?? '').trim();
          if (resolved.isNotEmpty) return resolved;
          if (path.startsWith('http://') || path.startsWith('https://')) {
            return path;
          }
          return '';
        }),
        builder: (_, snap) {
          final url = (snap.data ?? '').trim();
          if (url.isEmpty) return fallback();
          return Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          );
        },
      );
    }

    if (isAsset) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    if (isFileUri || isFilePath) {
      final localPath = isFileUri ? path.replaceFirst('file://', '') : path;
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    return FutureBuilder<String>(
      future: StorageUrlResolver.resolve(path).then((v) {
        final resolved = (v ?? '').trim();
        if (resolved.isNotEmpty) return resolved;
        if (path.startsWith('http://') || path.startsWith('https://')) {
          return path;
        }
        return '';
      }),
      builder: (_, snap) {
        final url = (snap.data ?? '').trim();
        if (url.isEmpty) return fallback();
        return Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback(),
        );
      },
    );
  }

  Uint8List? _decodeDataImageBytes(String value) {
    final src = value.trim();
    if (!src.startsWith('data:image/')) return null;
    final comma = src.indexOf(',');
    if (comma <= 0 || comma >= src.length - 1) return null;
    try {
      return base64Decode(src.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  Widget _photosGrid(List<String> images) {
    final renderable = images
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: renderable.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final src = renderable[i];
          return SizedBox(
            width: 112,
            child: InkWell(
              borderRadius: BorderRadius.zero,
              onTap: () => _openImagePreview(src),
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: _imageForPath(src),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openImagePreview(String src) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.snow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            AspectRatio(aspectRatio: 1, child: _imageForPath(src)),
            Positioned(
              right: 6,
              top: 6,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTrackingPreview([_ShipmentInfo? info]) async {
    final current = info ?? await _loadShipmentInfo();
    final courier = current.courier.trim();
    final tracking = current.tracking.trim();
    final shippedAt = current.shippedAt;
    final lineCourier = courier.isEmpty ? '-' : courier;
    final lineTracking = tracking.isEmpty ? '-' : tracking;
    final lineDate = shippedAt == null ? '-' : _fmtDate(shippedAt);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'Shipment Tracking',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Carrier: $lineCourier\nTracking #: $lineTracking\nShipped on: $lineDate',
          style: const TextStyle(fontSize: 11.5, height: 1.3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
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
    const wds = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wds[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}
