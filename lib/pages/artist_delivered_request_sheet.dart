import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_request_v2.dart';
import '../services/artist_requests_repository.dart';
import '../services/storage_url_resolver.dart';
import '../theme/app_colors.dart';
import '../utils/date_format_utils.dart';
import '../utils/request_nfc_details_loader.dart';
import '../utils/company_bio_loader.dart';
import '../widgets/group_client_measurements_tabs.dart';

Future<void> showDeliveredRequestSheet({
  required BuildContext context,
  required ClientRequestV2 request,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DeliveredRequestSheet(request: request),
  );
}

class _DeliveredRequestSheet extends StatefulWidget {
  const _DeliveredRequestSheet({required this.request});

  final ClientRequestV2 request;

  @override
  State<_DeliveredRequestSheet> createState() => _DeliveredRequestSheetState();
}

class _DeliveredRequestSheetState extends State<_DeliveredRequestSheet> {
  static const int _decodeMax = 1024;
  int _selectedTab = 2; // Open Delivered tab first for delivered history.

  ClientRequestV2 get request => widget.request;

  String get _requestTable =>
      request.sourceCollection == 'Company_Custom_Requests'
      ? 'company_custom_requests'
      : 'client_custom_requests';

  String get _requestDetailsTable =>
      request.sourceCollection == 'Company_Custom_Requests'
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

  String _firstNonEmpty(Iterable<Object?> values, {String fallback = ''}) {
    for (final raw in values) {
      final text = (raw ?? '').toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  String _normalizeImagePath(String raw) {
    var p = raw.trim();
    if (p.isEmpty) return '';
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      final decodedRest = Uri.decodeFull(rest);
      if (rest.startsWith('data:') ||
          rest.startsWith('blob:') ||
          rest.startsWith('gs://') ||
          rest.startsWith('content://') ||
          rest.startsWith('file://') ||
          decodedRest.startsWith('data:') ||
          decodedRest.startsWith('blob:') ||
          decodedRest.startsWith('gs://') ||
          decodedRest.startsWith('content://') ||
          decodedRest.startsWith('file://') ||
          decodedRest.startsWith('http://') ||
          decodedRest.startsWith('https://')) {
        p = decodedRest;
      }
    }
    if (p.startsWith('data%3A') ||
        p.startsWith('blob%3A') ||
        p.startsWith('gs%3A') ||
        p.startsWith('content%3A') ||
        p.startsWith('file%3A') ||
        p.startsWith('http%3A') ||
        p.startsWith('https%3A')) {
      p = Uri.decodeFull(p);
    }
    return p;
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
        cacheWidth: _decodeMax,
        cacheHeight: _decodeMax,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    final isAsset = path.startsWith('assets/');
    final isFileUri = path.startsWith('file://');
    final isFilePath =
        !kIsWeb && (path.startsWith('/') || path.contains(':\\'));

    if (isNetwork) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        cacheWidth: _decodeMax,
        cacheHeight: _decodeMax,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    if (path.startsWith('gs://') ||
        path.startsWith('blob:') ||
        path.startsWith('content://') ||
        (kIsWeb && !isAsset)) {
      return FutureBuilder<String>(
        future: StorageUrlResolver.resolve(path).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = (snap.data ?? '').trim();
          if (url.isEmpty) return fallback();
          return Image.network(
            url,
            fit: BoxFit.cover,
            cacheWidth: _decodeMax,
            cacheHeight: _decodeMax,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, _, _) => fallback(),
          );
        },
      );
    }

    if (isAsset) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        cacheWidth: _decodeMax,
        cacheHeight: _decodeMax,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    if (isFileUri || isFilePath) {
      final localPath = isFileUri ? path.replaceFirst('file://', '') : path;
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        cacheWidth: _decodeMax,
        cacheHeight: _decodeMax,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    return FutureBuilder<String>(
      future: StorageUrlResolver.resolve(path).then((v) => v ?? ''),
      builder: (_, snap) {
        final url = (snap.data ?? '').trim();
        if (url.isEmpty) return fallback();
        return Image.network(
          url,
          fit: BoxFit.cover,
          cacheWidth: _decodeMax,
          cacheHeight: _decodeMax,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, _, _) => fallback(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;
    final sheetMediaQuery = MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(1.0));

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Delivered request details',
      child: MediaQuery(
        data: sheetMediaQuery,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Stack(
            children: [
              Container(
                constraints: BoxConstraints(maxHeight: maxH),
                decoration: const BoxDecoration(
                  color: AppColors.snow,
                  borderRadius: BorderRadius.zero,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _dragHandle(),
                    _topHero(context),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          _infoChips(),
                          const SizedBox(height: 14),
                          _deliveredBanner(),
                          const SizedBox(height: 18),
                          _tabBar(),
                          const SizedBox(height: 14),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: KeyedSubtree(
                              key: ValueKey<int>(_selectedTab),
                              child: _selectedTab == 0
                                  ? _detailsTab()
                                  : _selectedTab == 1
                                  ? _photosTab()
                                  : _deliveredTab(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                      child: Center(
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
                            onPressed: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18),
                              child: Text(
                                'Close',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, size: 30),
                  color: AppColors.blackCat.withValues(alpha: 0.72),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dragHandle() => Container(
    height: 5,
    width: 54,
    decoration: BoxDecoration(
      color: AppColors.blackCat.withValues(alpha: 0.12),
      borderRadius: BorderRadius.zero,
    ),
  );

  Widget _topHero(BuildContext context) {
    final isBrandRequest = _isBrandRequest(request);
    final headerName = isBrandRequest && request.brandName.trim().isNotEmpty
        ? request.brandName.trim()
        : request.clientName;
    final avatarPath = _headerAvatarPath();
    final avatarLetter = headerName.trim().isEmpty
        ? ''
        : headerName.trim()[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Column(
        children: [
          SizedBox(
            height: 78,
            width: 78,
            child: avatarPath.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: _imageForPath(avatarPath),
                  )
                : Container(
                    color: AppColors.balletSlippers,
                    alignment: Alignment.center,
                    child: Text(
                      avatarLetter,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blackCat,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            headerName.trim().isEmpty ? 'Client' : headerName.trim(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat,
            ),
          ),
          const SizedBox(height: 16),
          _requestTypeRow(),
          const SizedBox(height: 16),
          _needBudgetRow(),
        ],
      ),
    );
  }

  String _headerAvatarPath() {
    final accepted = _safeAcceptedClientAvatarPath(request);
    if (accepted.isNotEmpty) return accepted;
    final clientProfile = _normalizeImagePath(
      request.clientProfileImage.trim(),
    );
    if (clientProfile.isNotEmpty) return clientProfile;
    final preview = _normalizeImagePath(request.previewImageAsset.trim());
    if (preview.isNotEmpty) return preview;
    return '';
  }

  Widget _requestTypeRow() {
    // requestTypeLabel is frozen at submission and must never be
    // recomputed from current state (e.g. after client/artist acceptance).
    // Fall back to the old simplified rule only for legacy rows that
    // predate this field.
    final requestLabel = request.requestTypeLabel.isNotEmpty
        ? request.requestTypeLabel
        : (request.isDirectRequest ? 'Direct' : 'Standard');
    final orderLabel = request.orderType == RequestOrderTypeV2.group
        ? 'Group'
        : 'Single';

    Widget requestTypeContent() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          request.isDirectRequest
              ? Icons.arrow_outward_rounded
              : Icons.arrow_forward_rounded,
          size: 15,
          color: AppColors.blackCat,
        ),
        const SizedBox(width: 5),
        Text(
          requestLabel,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.blackCat,
          ),
        ),
      ],
    );

    Widget orderTypeContent() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          request.orderType == RequestOrderTypeV2.group
              ? Icons.groups_2_outlined
              : Icons.person_outline_rounded,
          size: 15,
          color: AppColors.blackCat,
        ),
        const SizedBox(width: 5),
        Text(
          orderLabel,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.blackCat,
          ),
        ),
      ],
    );

    return FutureBuilder<RequestNfcDetails>(
      future: loadRequestNfcDetails(
        sourceCollection: request.sourceCollection,
        requestId: request.id,
        requestOrderNumber: request.orderNumber,
      ),
      builder: (context, snapshot) {
        final nfc = snapshot.data ?? RequestNfcDetails.emptyConst;
        final requiresNfc =
            nfc.main.left['thumb'] == true || nfc.main.right['thumb'] == true;
        if (!requiresNfc) {
          return _summaryPairRow(
            left: requestTypeContent(),
            right: orderTypeContent(),
          );
        }
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              requestTypeContent(),
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 18,
                color: AppColors.blackCatBorderLight,
              ),
              const SizedBox(width: 10),
              orderTypeContent(),
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 18,
                color: AppColors.blackCatBorderLight,
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.nfc_rounded,
                size: 15,
                color: AppColors.blackCat,
              ),
              const SizedBox(width: 5),
              const Text(
                'NFC',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ],
          ),
        );
      },
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
      left: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 15,
            color: AppColors.blackCat,
          ),
          const SizedBox(width: 5),
          Text(
            'Need by: ${_needByLabel(request.neededBy)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat,
            ),
          ),
        ],
      ),
      right: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.attach_money_rounded,
            size: 15,
            color: AppColors.blackCat,
          ),
          const SizedBox(width: 2),
          Text(
            'Budget: \$${request.budgetMin} to \$${request.budgetMax}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat,
            ),
          ),
        ],
      ),
    );
  }

  bool _isBrandRequest(ClientRequestV2 request) =>
      request.sourceCollection == 'Company_Custom_Requests' ||
      request.orderNumber.trim().toUpperCase().startsWith('BE-') ||
      request.orderNumber.trim().toUpperCase().startsWith('BR-');

  Widget _descriptionAndCompanyBioSection(ClientRequestV2 r) {
    if (!_isBrandRequest(r)) {
      return _borderBox(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Description',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.blackCat,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              r.bio.trim().isEmpty ? '-' : r.bio.trim(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.blackCat,
              ),
            ),
          ],
        ),
      );
    }
    return FutureBuilder<String>(
      future: fetchCompanyBio(
        sourceCollection: r.sourceCollection,
        requestId: r.id,
        requestOrderNumber: r.orderNumber,
      ),
      builder: (context, snapshot) {
        final bio = (snapshot.data ?? '').trim();
        return _borderBox(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.blackCat,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                r.bio.trim().isEmpty ? '-' : r.bio.trim(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.blackCat,
                ),
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: AppColors.blackCatBorderLight),
              const SizedBox(height: 12),
              const Text(
                'Company Bio',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.blackCat,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bio.isEmpty ? 'No company bio available' : bio,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.blackCat,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoChips() {
    final courier = (request.shippedByCourier ?? '').trim().isEmpty
        ? '-'
        : (request.shippedByCourier ?? '').trim();
    return Container(
      height: 1,
      color: AppColors.blackCatBorderLight,
      margin: const EdgeInsets.only(top: 2),
      child: Semantics(label: 'Shipped with $courier'),
    );
  }

  Widget _deliveredBanner() {
    return _borderBox(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 26,
            width: 26,
            decoration: const BoxDecoration(
              color: Color(0xFFDBF4E6),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check, color: Color(0xFF1E8E5A), size: 16),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivered!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackCat,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'The order has been delivered to the client.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.blackCat,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
    );
  }

  Widget _tabBar() {
    return Row(
      children: [
        _tabButton('Details', 0),
        _tabButton('Photos', 1),
        _tabButton('Delivered', 2),
      ],
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: () => setState(() => _selectedTab = index),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: AppColors.blackCat,
                    ),
                  ),
                ),
                Container(
                  height: 3,
                  width: double.infinity,
                  color: selected ? AppColors.blackCat : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _descriptionAndCompanyBioSection(request),
        const SizedBox(height: 14),
        if (_isBrandRequest(request)) ...[
          _acceptedClientDetailsSection(request),
          const SizedBox(height: 14),
        ],
        _orderDetailsSection(),
        const SizedBox(height: 14),
        _paymentSection(),
      ],
    );
  }

  Widget _photosTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _photosSection('Uploaded Photos (Client)', request.clientImages),
        const SizedBox(height: 14),
        _photosSection('Uploaded Photos (Artist)', request.artistImages),
      ],
    );
  }

  Widget _deliveredTab() {
    return _borderBox(
      Column(
        children: [
          _deliveryInfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Client Name',
            value: request.clientName.trim().isEmpty
                ? '-'
                : request.clientName.trim(),
          ),
          _deliveryInfoRow(
            icon: Icons.local_shipping_outlined,
            label: 'Shipped By',
            value: (request.shippedByCourier ?? '').trim().isEmpty
                ? '-'
                : (request.shippedByCourier ?? '').trim(),
          ),
          _deliveryInfoRow(
            icon: Icons.qr_code_2_rounded,
            label: 'Tracking #',
            value: (request.trackingNumber?.trim() ?? '').isEmpty
                ? '-'
                : (request.trackingNumber?.trim() ?? ''),
          ),
          _deliveryInfoRow(
            icon: Icons.event_available_outlined,
            label: 'Shipped Date',
            value: _fmtDateLong(request.shippedAt),
          ),
          _deliveryInfoRow(
            icon: Icons.event_available_outlined,
            label: 'Delivered Date',
            value: _fmtDateLong(request.deliveredAt),
            bottomPadding: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
    );
  }

  Widget _deliveryInfoRow({
    required IconData icon,
    required String label,
    required String value,
    double bottomPadding = 22,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Icon(icon, size: 18, color: AppColors.blackCat),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackCat,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.trim().isEmpty ? '-' : value.trim(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.blackCat,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderDetailsSection() {
    return _borderBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Details',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.blackCat,
            ),
          ),
          const SizedBox(height: 12),
          _detailRow('Need by', _needByLabel(request.neededBy)),
          const SizedBox(height: 14),
          const Text(
            'Nail Dimensions',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.blackCat,
            ),
          ),
          const SizedBox(height: 14),
          _measurementContent(),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    );
  }

  Widget _acceptedClientDetailsSection(ClientRequestV2 request) {
    // Do not fall back to request.clientName here -- for brand-sourced
    // requests that field holds the brand/company name, not the client's,
    // whenever no accepted-client snapshot was captured.
    final name = request.acceptedClientName.trim().isNotEmpty
        ? request.acceptedClientName.trim()
        : 'Client';
    final avatarPath = _safeAcceptedClientAvatarPath(request);
    final avatarLetter = name[0].toUpperCase();
    return _borderBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Client Details',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.blackCat,
            ),
          ),
          const SizedBox(height: 12),
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
                          color: AppColors.blackCat,
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
                    color: AppColors.blackCat,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _safeAcceptedClientAvatarPath(ClientRequestV2 request) {
    final accepted = _normalizeImagePath(
      request.acceptedClientProfileImage.trim(),
    );
    if (accepted.isEmpty) return '';
    final blocked = <String>{
      _normalizeImagePath(request.clientProfileImage),
      _normalizeImagePath(request.previewImageAsset),
    }..removeWhere((e) => e.trim().isEmpty);
    return blocked.contains(accepted) ? '' : accepted;
  }

  Widget _photosSection(String title, List<String> images) {
    final renderable = images
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    return _borderBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.blackCat,
            ),
          ),
          const SizedBox(height: 12),
          if (renderable.isEmpty)
            Row(
              children: [
                Icon(
                  Icons.image_outlined,
                  color: AppColors.blackCat.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 10),
                Text(
                  'No photos uploaded',
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.65),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            )
          else
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: renderable.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => SizedBox(
                  width: 112,
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: _imageForPath(renderable[i]),
                  ),
                ),
              ),
            ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    );
  }

  Widget _measurementContent() {
    final isGroup = request.orderType == RequestOrderTypeV2.group;
    return FutureBuilder<RequestNfcDetails>(
      future: loadRequestNfcDetails(
        sourceCollection: request.sourceCollection,
        requestId: request.id,
      ),
      builder: (context, snapshot) {
        final nfc = snapshot.data ?? RequestNfcDetails.emptyConst;
        if (isGroup) {
          return FutureBuilder<List<GroupClientMeasurementData>>(
            future: _loadGroupMeasurementClients(nfc),
            builder: (context, groupSnapshot) {
              final clients =
                  groupSnapshot.data ?? _buildGroupMeasurementClients(nfc);
              return GroupClientMeasurementsTabs(
                clients: clients,
                compactRequestDetailsLayout: true,
                tabViewHeight: 312,
              );
            },
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _dimsCard(
                      'Left Hand',
                      request.leftHand,
                      nfc: nfc.main.left,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(width: 1, color: AppColors.blackCatBorderLight),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dimsCard(
                      'Right Hand',
                      request.rightHand,
                      nfc: nfc.main.right,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.blackCatBorderLight),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _metaValueCard(
                    'Shape',
                    request.nailShape.trim().isEmpty ? '-' : request.nailShape,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    height: 42,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.blackCatBorderLight,
                    ),
                  ),
                ),
                Expanded(
                  child: _metaValueCard(
                    'Length',
                    request.nailLength.trim().isEmpty
                        ? '-'
                        : request.nailLength,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _paymentSection() {
    final finalAmount = request.artistFinalAmount;
    final paymentStatus = request.paymentStatus.trim().isEmpty
        ? 'Pending'
        : request.paymentStatus.trim();
    final amountText = finalAmount != null
        ? '\$${finalAmount.toStringAsFixed(finalAmount % 1 == 0 ? 0 : 2)}'
        : '\$${request.budgetMin} to \$${request.budgetMax}';

    return _borderBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.blackCat,
            ),
          ),
          const SizedBox(height: 12),
          _detailRow(
            finalAmount != null ? 'Final Amount by Artist' : 'Amount',
            amountText,
          ),
          const SizedBox(height: 10),
          _detailRow('Status', paymentStatus),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    FontWeight valueWeight = FontWeight.w700,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.blackCat,
          ),
        ),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '-' : value.trim(),
            style: TextStyle(
              color: AppColors.blackCat,
              fontWeight: valueWeight,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dimsCard(
    String title,
    NailDimensionsV2 dims, {
    Map<String, bool> nfc = const <String, bool>{},
  }) {
    String withMm(String raw) {
      final value = raw.trim();
      if (value.isEmpty || value == '-') return '-';
      final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
      final parsed = double.tryParse(cleaned);
      if (parsed == null) return value;
      return '${parsed.toStringAsFixed(2)} mm';
    }

    Widget row(String label, String value, {bool nfcRequested = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        color: AppColors.blackCat.withValues(alpha: 0.60),
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (nfcRequested) ...[const SizedBox(width: 6), _nfcChip()],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              withMm(value),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.blackCat,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.blackCat,
            ),
          ),
        ),
        const SizedBox(height: 12),
        row('Thumb', dims.thumb, nfcRequested: nfc['thumb'] == true),
        row('Index', dims.index, nfcRequested: nfc['index'] == true),
        row('Middle', dims.middle, nfcRequested: nfc['middle'] == true),
        row('Ring', dims.ring, nfcRequested: nfc['ring'] == true),
        row('Pinky', dims.pinky, nfcRequested: nfc['pinky'] == true),
      ],
    );
  }

  Widget _nfcChip() {
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

  Widget _metaValueCard(String label, String value) {
    final v = value.trim().isEmpty ? '-' : value.trim();
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.blackCat,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          v,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.blackCat,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Future<List<GroupClientMeasurementData>> _loadGroupMeasurementClients(
    RequestNfcDetails nfc,
  ) async {
    final hydrated = await ArtistRequestsRepository.fetchRequestById(
      sourceCollection: request.sourceCollection,
      requestId: request.id,
    );
    final clients = _buildGroupMeasurementClients(
      nfc,
      source: hydrated ?? request,
    );
    final directGroupClients = await _loadGroupClientOverrides(nfc);
    final submittedDims = await _loadSubmittedMeasurementOverride();
    var resolvedClients = clients;

    if (clients.isNotEmpty && submittedDims != null) {
      final left = submittedDims['left'] ?? const <String, String>{};
      final right = submittedDims['right'] ?? const <String, String>{};
      if (left.values.any((v) => v.trim().isNotEmpty) ||
          right.values.any((v) => v.trim().isNotEmpty)) {
        final current = clients.first;
        resolvedClients = <GroupClientMeasurementData>[
          GroupClientMeasurementData(
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
          ),
          ...clients.skip(1),
        ];
      }
    }

    if (directGroupClients.isEmpty) return resolvedClients;

    final merged = <GroupClientMeasurementData>[...resolvedClients];
    final seen = <String>{};
    for (final client in merged) {
      final email = client.clientEmail.trim().toLowerCase();
      final name = client.name.trim().toLowerCase();
      if (email.isNotEmpty) seen.add('email:$email');
      if (name.isNotEmpty) seen.add('name:$name');
    }
    for (final client in directGroupClients) {
      final email = client.clientEmail.trim().toLowerCase();
      final name = client.name.trim().toLowerCase();
      final keys = <String>{
        if (email.isNotEmpty) 'email:$email',
        if (name.isNotEmpty) 'name:$name',
      };
      if (keys.isEmpty || keys.any(seen.contains)) continue;
      seen.addAll(keys);
      merged.add(client);
      if (merged.length >= 16) break;
    }
    return merged;
  }

  Future<List<GroupClientMeasurementData>> _loadGroupClientOverrides(
    RequestNfcDetails nfc,
  ) async {
    final clients = <GroupClientMeasurementData>[];
    final seen = <String>{};

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

    Map<String, String> firstDims(
      Iterable<Object?> sources, {
      required bool left,
    }) {
      for (final source in sources) {
        final dims = dimsFrom(source, left: left);
        if (dims.values.any((v) => v.trim().isNotEmpty)) return dims;
      }
      return const <String, String>{};
    }

    int slotIndexOf(Map<String, dynamic> client, int fallback) {
      final raw =
          client['slotIndex'] ?? client['slot_index'] ?? client['index'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse((raw ?? '').toString().trim()) ?? fallback;
    }

    void addClient(Map<String, dynamic> client, int fallbackIndex) {
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
      ]).toLowerCase();
      final name = _firstNonEmpty(<Object?>[
        client['clientName'],
        client['client_name'],
        client['name'],
        client['displayName'],
        client['display_name'],
      ], fallback: 'Client $fallbackIndex');

      final keys = <String>{
        if (email.isNotEmpty) 'email:$email',
        if (id.isNotEmpty) 'id:$id',
        if (name.trim().isNotEmpty) 'name:${name.trim().toLowerCase()}',
      };
      if (keys.isEmpty || keys.any(seen.contains)) return;

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
      final slotIndex = slotIndexOf(client, fallbackIndex);
      final slotNfc =
          nfc.groupBySlotIndex[slotIndex] ??
          RequestFingerNfcSelection.emptyConst;

      seen.addAll(keys);
      clients.add(
        GroupClientMeasurementData(
          name: name,
          clientEmail: email,
          nailShape: _firstNonEmpty(<Object?>[
            client['nailShape'],
            client['nail_shape'],
            nailSource['shape'],
            nailSource['nailShape'],
            nailSource['nail_shape'],
          ], fallback: request.nailShape),
          nailLength: _firstNonEmpty(<Object?>[
            client['nailLength'],
            client['nail_length'],
            nailSource['length'],
            nailSource['nailLength'],
            nailSource['nail_length'],
          ], fallback: request.nailLength),
          leftHand: left,
          rightHand: right,
          leftNfc: slotNfc.left,
          rightNfc: slotNfc.right,
        ),
      );
    }

    void addFromSource(Map<String, dynamic> source) {
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

      var fallbackIndex = 1;
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
            addClient(_asMap(rawClient), fallbackIndex++);
          }
        }
      }
    }

    try {
      final root = await Supabase.instance.client
          .from(_requestTable)
          .select()
          .eq('id', request.id)
          .maybeSingle();
      if (root != null) addFromSource(Map<String, dynamic>.from(root as Map));

      final detailRows = await Supabase.instance.client
          .from(_requestDetailsTable)
          .select()
          .eq('request_id', request.id);
      for (final row in detailRows) {
        final map = _asMap(row);
        addFromSource(map);
        addFromSource(_asMap(map['data']));
      }
    } catch (_) {}

    return clients;
  }

  Future<Map<String, Map<String, String>>?>
  _loadSubmittedMeasurementOverride() async {
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

    Map<String, String> firstDims(
      Iterable<Object?> sources, {
      required bool left,
    }) {
      for (final source in sources) {
        final dims = dimsFrom(source, left: left);
        if (dims.values.any((v) => v.trim().isNotEmpty)) return dims;
      }
      return const <String, String>{};
    }

    Map<String, Map<String, String>> fromSource(Map<String, dynamic> source) {
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

      return <String, Map<String, String>>{
        'left': firstDims(leftSources, left: true),
        'right': firstDims(rightSources, left: false),
      };
    }

    bool hasAny(Map<String, Map<String, String>> dims) {
      final left = dims['left'] ?? const <String, String>{};
      final right = dims['right'] ?? const <String, String>{};
      return left.values.any((v) => v.trim().isNotEmpty) ||
          right.values.any((v) => v.trim().isNotEmpty);
    }

    try {
      final root = await Supabase.instance.client
          .from(_requestTable)
          .select()
          .eq('id', request.id)
          .maybeSingle();
      if (root != null) {
        final dims = fromSource(Map<String, dynamic>.from(root as Map));
        if (hasAny(dims)) return dims;
      }

      final detailRows = await Supabase.instance.client
          .from(_requestDetailsTable)
          .select()
          .eq('request_id', request.id);
      for (final row in detailRows) {
        final map = _asMap(row);
        final dims = fromSource(map);
        if (hasAny(dims)) return dims;
        final dataDims = fromSource(_asMap(map['data']));
        if (hasAny(dataDims)) return dataDims;
      }
    } catch (_) {}

    return null;
  }

  List<GroupClientMeasurementData> _buildGroupMeasurementClients(
    RequestNfcDetails nfc, {
    ClientRequestV2? source,
  }) {
    final data = source ?? request;
    final submittedName = data.clientName.trim().isEmpty
        ? 'Client'
        : data.clientName.trim();
    final clients = <GroupClientMeasurementData>[
      GroupClientMeasurementData(
        name: submittedName,
        clientEmail: data.clientEmail,
        nailShape: data.nailShape,
        nailLength: data.nailLength,
        leftHand: _dimsMap(data.leftHand),
        rightHand: _dimsMap(data.rightHand),
        leftNfc: nfc.main.left,
        rightNfc: nfc.main.right,
      ),
    ];
    final seen = <String>{
      submittedName.toLowerCase(),
      if (data.clientEmail.trim().isNotEmpty)
        data.clientEmail.trim().toLowerCase(),
    };
    for (final client in data.groupClients) {
      final name = client.clientName.trim().isEmpty
          ? 'Client ${client.slotIndex}'
          : client.clientName.trim();
      final key = client.clientId.trim().isNotEmpty
          ? client.clientId.trim().toLowerCase()
          : name.toLowerCase();
      if (seen.contains(key) || seen.contains(name.toLowerCase())) continue;
      seen.add(key);
      seen.add(name.toLowerCase());
      final slotNfc =
          nfc.groupBySlotIndex[client.slotIndex] ??
          RequestFingerNfcSelection.emptyConst;
      clients.add(
        GroupClientMeasurementData(
          name: name,
          clientEmail: client.clientEmail,
          nailShape: client.nailShape,
          nailLength: client.nailLength,
          leftHand: _dimsMap(client.leftHand),
          rightHand: _dimsMap(client.rightHand),
          leftNfc: slotNfc.left,
          rightNfc: slotNfc.right,
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

  Widget _borderBox(
    Widget child, {
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: child,
    );
  }

  String _needByLabel(DateTime d) => formatDateMdy(d);

  String _fmtDateLong(DateTime? d) => formatDateMdyOrDash(d);
}
