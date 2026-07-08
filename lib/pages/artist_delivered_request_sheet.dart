import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/client_request_v2.dart';
import '../services/storage_url_resolver.dart';
import '../theme/app_colors.dart';
import '../utils/request_nfc_details_loader.dart';
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
    final isFilePath = !kIsWeb && (path.startsWith('/') || path.contains(':\\'));

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

    return MediaQuery(
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
                icon: const Icon(Icons.close_rounded, size: 30),
                color: AppColors.blackCat.withValues(alpha: 0.72),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
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
    final clientProfile = _normalizeImagePath(request.clientProfileImage.trim());
    if (clientProfile.isNotEmpty) return clientProfile;
    final preview = _normalizeImagePath(request.previewImageAsset.trim());
    if (preview.isNotEmpty) return preview;
    return '';
  }

  Widget _requestTypeRow() {
    final requestLabel = request.isDirectRequest ? 'Direct Request' : 'Standard Request';
    final orderLabel = request.orderType == RequestOrderTypeV2.group
        ? 'Group Order'
        : 'Single Order';
    return _summaryPairRow(
      left: Row(
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
      ),
      right: Row(
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
      ),
    );
  }

  static Widget _summaryPairRow({
    required Widget left,
    required Widget right,
  }) {
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
            child: const Icon(
              Icons.check,
              color: Color(0xFF1E8E5A),
              size: 16,
            ),
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
    );
  }

  Widget _detailsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            value: request.clientName.trim().isEmpty ? '-' : request.clientName.trim(),
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
          _detailRow(
            'Description',
            request.bio.trim().isEmpty ? '-' : request.bio.trim(),
            valueWeight: FontWeight.w400,
          ),
          const SizedBox(height: 10),
          _detailRow(
            'Need by',
            _needByLabel(request.neededBy),
          ),
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
    final name = request.acceptedClientName.trim().isNotEmpty
        ? request.acceptedClientName.trim()
        : (request.clientName.trim().isNotEmpty ? request.clientName.trim() : 'Client');
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
    final accepted = _normalizeImagePath(request.acceptedClientProfileImage.trim());
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
          final baseClients = _buildGroupMeasurementClients();
          final clients = <GroupClientMeasurementData>[];
          for (var i = 0; i < baseClients.length; i++) {
            final client = baseClients[i];
            final slotIndex = i + 1;
            final slotNfc = slotIndex == 1
                ? nfc.main
                : (nfc.groupBySlotIndex[slotIndex] ??
                    RequestFingerNfcSelection.emptyConst);
            clients.add(
              GroupClientMeasurementData(
                name: client.name,
                clientEmail: client.clientEmail,
                nailShape: client.nailShape,
                nailLength: client.nailLength,
                leftHand: client.leftHand,
                rightHand: client.rightHand,
                leftNfc: slotNfc.left,
                rightNfc: slotNfc.right,
              ),
            );
          }
          return GroupClientMeasurementsTabs(
            clients: clients,
            compactRequestDetailsLayout: true,
            tabViewHeight: 248,
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _dimsCard(
                    'Left Hand',
                    request.leftHand,
                    nfc: nfc.main.left,
                  ),
                ),
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
                const SizedBox(width: 12),
                Expanded(
                  child: _metaValueCard(
                    'Length',
                    request.nailLength.trim().isEmpty ? '-' : request.nailLength,
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
          _detailRow(
            'Status',
            paymentStatus,
          ),
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
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.blackCat.withValues(alpha: 0.60),
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
            if (nfcRequested) ...[_nfcChip(), const SizedBox(width: 6)],
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

    return _borderBox(
      Column(
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
      ),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
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
    return _borderBox(
      Row(
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
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
    );
  }

  List<GroupClientMeasurementData> _buildGroupMeasurementClients() {
    final submittedName = request.clientName.trim().isEmpty
        ? 'Client'
        : request.clientName.trim();
    final clients = <GroupClientMeasurementData>[
      GroupClientMeasurementData(
        name: submittedName,
        nailShape: request.nailShape,
        nailLength: request.nailLength,
        leftHand: _dimsMap(request.leftHand),
        rightHand: _dimsMap(request.rightHand),
      ),
    ];
    final seen = <String>{submittedName.toLowerCase()};
    for (final client in request.groupClients) {
      final name = client.clientName.trim().isEmpty
          ? 'Client ${client.slotIndex}'
          : client.clientName.trim();
      final key = client.clientId.trim().isNotEmpty
          ? client.clientId.trim().toLowerCase()
          : name.toLowerCase();
      if (seen.contains(key) || seen.contains(name.toLowerCase())) continue;
      seen.add(key);
      seen.add(name.toLowerCase());
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


  String _needByLabel(DateTime d) {
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

  String _fmtDateLong(DateTime? d) {
    if (d == null) return '-';
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
    return '${wds[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
