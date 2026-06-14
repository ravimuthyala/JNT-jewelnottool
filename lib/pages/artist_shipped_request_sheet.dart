// artist_shipped_request_sheet.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/client_request_v2.dart';
import '../services/storage_url_resolver.dart';
import '../theme/app_colors.dart';
import '../widgets/group_client_measurements_tabs.dart';

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

class _ShippedRequestSheetState extends State<_ShippedRequestSheet> {
  bool _isMarkingDelivered = false;
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
    final profile = widget.request.clientProfileImage.trim();
    if (profile.isNotEmpty) return profile;
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
    final tracking = (widget.request.trackingNumber ?? '').trim();
    final shippedAt = widget.request.shippedAt;

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
                  color: Colors.black.withOpacity(0.12),
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

                    _softBox(
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 32,
                            width: 32,
                            decoration: const BoxDecoration(
                              color: AppColors.alabaster,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 18,
                              color: AppColors.blackCat,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (shippedAt != null)
                                  Text(
                                    'Shipped on ${_fmtDate(shippedAt)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  )
                                else
                                  const Text(
                                    'Shipped',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Tracking Number: ',
                                      style: TextStyle(
                                        color: Colors.black.withOpacity(0.60),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        tracking.isEmpty ? '-' : tracking,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 44,
                                  child: ElevatedButton.icon(
                                    onPressed: _openTrackingPreview,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.blackCat,
                                      foregroundColor: AppColors.snow,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.zero,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.travel_explore_rounded,
                                      size: 16,
                                    ),
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
                    ),

                    const SizedBox(height: 12),
                    const Divider(
                      height: 1,
                      color: AppColors.blackCatBorderLight,
                    ),
                    const SizedBox(height: 12),
                    if (_isBrandRequest(widget.request)) ...[
                      _acceptedClientDetailsSection(widget.request),
                      const SizedBox(height: 12),
                      const Divider(
                        height: 1,
                        color: AppColors.blackCatBorderLight,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _measurementSection(),
                    const SizedBox(height: 14),
                    const Divider(
                      height: 1,
                      color: AppColors.blackCatBorderLight,
                    ),
                    const SizedBox(height: 12),

                    _sectionTitle('Uploaded Photos (Client)'),
                    const SizedBox(height: 10),
                    if (modalClientPhotos.isEmpty)
                      _softBox(
                        Row(
                          children: [
                            Icon(
                              Icons.image_outlined,
                              color: Colors.black.withOpacity(0.45),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'No images uploaded',
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.65),
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _photosGrid(modalClientPhotos),

                    const SizedBox(height: 16),
                    const Divider(
                      height: 1,
                      color: AppColors.blackCatBorderLight,
                    ),
                    const SizedBox(height: 12),

                    _sectionTitle('Uploaded Photos (Artist)'),
                    const SizedBox(height: 10),
                    if (widget.request.artistImages.isEmpty)
                      _softBox(
                        Row(
                          children: [
                            Icon(
                              Icons.image_outlined,
                              color: Colors.black.withOpacity(0.45),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'No artist photos uploaded',
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.65),
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _photosGrid(widget.request.artistImages),
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
                            color: Colors.black.withOpacity(0.65),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Delivery status updates automatically from courier tracking.',
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.72),
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
                          color: Colors.black.withOpacity(0.58),
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
    final avatarPath = _heroPhotoSource();
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
                child: avatarPath.isNotEmpty
                    ? SizedBox(
                        height: 78,
                        width: 78,
                        child: ClipRRect(
                          borderRadius: BorderRadius.zero,
                          child: _imageForPath(avatarPath),
                        ),
                      )
                    : Container(
                        height: 78,
                        width: 78,
                        decoration: BoxDecoration(
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
                    color: Colors.black.withOpacity(0.75),
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
                  color: Colors.black.withOpacity(0.60),
                ),
              ),
              const SizedBox(height: 10),
              _requestTypeOrderRow(request),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _chipInfo(
                      icon: Icons.calendar_today_outlined,
                      text: 'Need by: ${_needByLabel(request.neededBy)}',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _chipInfo(
                      icon: Icons.attach_money_rounded,
                      text:
                          'Budget: \$${request.budgetMin} to \$${request.budgetMax}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.blackCatBorderLight),
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
                color: Colors.black.withOpacity(0.70),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          r.isDirectRequest
              ? Icons.arrow_outward_rounded
              : Icons.arrow_forward_rounded,
          size: 16,
          color: AppColors.blackCat,
        ),
        const SizedBox(width: 6),
        Text(
          requestType,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        const SizedBox(width: 14),
        Container(width: 1, height: 16, color: AppColors.blackCatBorderLight),
        const SizedBox(width: 14),
        Icon(
          r.orderType == RequestOrderTypeV2.group
              ? Icons.groups_2_outlined
              : Icons.person_outline_rounded,
          size: 16,
          color: AppColors.blackCat,
        ),
        const SizedBox(width: 6),
        Text(
          orderType,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ],
    );
  }

  static Widget _chipInfo({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.blackCat),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
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
    if (isGroup) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Client Measurements'),
          const SizedBox(height: 10),
          GroupClientMeasurementsTabs(
            clients: _buildGroupMeasurementClients(),
            compactRequestDetailsLayout: true,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Nail Dimensions (mm)'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _dimsCard('Left Hand', widget.request.leftHand)),
            const SizedBox(width: 8),
            Expanded(child: _dimsCard('Right Hand', widget.request.rightHand)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _measureField('Nail Shape', widget.request.nailShape),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _measureField(
                'Nail Length',
                _prettyLength(widget.request.nailLength),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dimsCard(String title, NailDimensionsV2 dims) {
    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.60),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
            Text(
              value.trim().isEmpty ? '-' : value.trim(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      );
    }

    return _softBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          row('Thumb', dims.thumb),
          row('Index', dims.index),
          row('Middle', dims.middle),
          row('Ring', dims.ring),
          row('Pinky', dims.pinky),
        ],
      ),
    );
  }

  List<GroupClientMeasurementData> _buildGroupMeasurementClients() {
    final clients = <GroupClientMeasurementData>[
      GroupClientMeasurementData(
        name: widget.request.clientName,
        nailShape: widget.request.nailShape,
        nailLength: widget.request.nailLength,
        leftHand: _dimsMap(widget.request.leftHand),
        rightHand: _dimsMap(widget.request.rightHand),
      ),
    ];
    final seen = <String>{widget.request.clientName.trim().toLowerCase()};
    for (final client in widget.request.groupClients) {
      final name = client.clientName.trim().isEmpty
          ? 'Client ${client.slotIndex}'
          : client.clientName.trim();
      final key = client.clientId.trim().isNotEmpty
          ? client.clientId.trim().toLowerCase()
          : name.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      clients.add(
        GroupClientMeasurementData(
          name: name,
          nailShape: client.nailShape,
          nailLength: client.nailLength,
          leftHand: _dimsMap(client.leftHand),
          rightHand: _dimsMap(client.rightHand),
        ),
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
    return _softBox(
      Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.black.withOpacity(0.60),
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
          const Spacer(),
          Text(
            trimmed.isEmpty ? '-' : trimmed,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  static Widget _softBox(Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      color: Colors.black.withOpacity(0.06),
      child: Icon(
        Icons.broken_image_outlined,
        color: Colors.black.withOpacity(0.35),
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

  Future<void> _openTrackingPreview() async {
    final courier = (widget.request.shippedByCourier ?? '').trim();
    final tracking = (widget.request.trackingNumber ?? '').trim();
    final shippedAt = widget.request.shippedAt;
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
