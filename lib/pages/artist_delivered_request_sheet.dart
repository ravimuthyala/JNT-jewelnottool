import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/client_request_v2.dart';
import '../services/storage_url_resolver.dart';
import '../theme/app_colors.dart';
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

class _DeliveredRequestSheet extends StatelessWidget {
  const _DeliveredRequestSheet({required this.request});

  final ClientRequestV2 request;
  static const int _decodeMax = 1024;

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

    if (isNetwork || path.startsWith('gs://') || (kIsWeb && !isAsset)) {
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
                        const SizedBox(height: 12),
                        _deliveredBox(),
                        const SizedBox(height: 12),
                        _softBox(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Description',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                request.bio.trim().isEmpty
                                    ? '-'
                                    : request.bio.trim(),
                                style: TextStyle(
                                  color: AppColors.blackCat.withValues(
                                    alpha: 0.78,
                                  ),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isBrandRequest(request)) ...[
                          _acceptedClientDetailsSection(request),
                          const SizedBox(height: 16),
                        ],
                        _measurementSection(),
                        const SizedBox(height: 16),
                        _photosSection(
                          'Uploaded Photos (Client)',
                          request.clientImages,
                        ),
                        const SizedBox(height: 18),
                        _photosSection(
                          'Uploaded Photos (Artist)',
                          request.artistImages,
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    child: Center(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
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
                icon: const Icon(Icons.close_rounded),
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
    final headerSubtitle = isBrandRequest ? request.title.trim() : '';
    final avatarPath = request.clientProfileImage.trim();
    final avatarLetter = headerName.isEmpty ? '' : headerName[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        children: [
          if (avatarPath.isNotEmpty)
            SizedBox(
              height: 78,
              width: 78,
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: _imageForPath(avatarPath),
              ),
            )
          else
            Container(
              height: 78,
              width: 78,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.zero,
                color: AppColors.blackCat.withValues(alpha: 0.06),
              ),
              alignment: Alignment.center,
              child: Text(
                avatarLetter,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            headerName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (headerSubtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              headerSubtitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.blackCat.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 6),
            _outlinedChip('Brand Request'),
          ],
          const SizedBox(height: 4),
          if (!isBrandRequest)
            Text(
              request.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 2),
          Text(
            request.subtitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.blackCat.withValues(alpha: 0.55),
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
    return _softBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Client Details',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 10),
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

  Widget _infoChips() {
    final courier = (request.shippedByCourier ?? '').trim().isEmpty
        ? '-'
        : (request.shippedByCourier ?? '').trim();
    return Text(
      'Shipped with $courier | Budget: \$${request.budgetMin} - \$${request.budgetMax}',
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13.5,
        color: AppColors.blackCat,
      ),
    );
  }

  Widget _deliveredBox() {
    return _softBox(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 28,
            width: 28,
            decoration: const BoxDecoration(
              color: Color(0xFFE6F4EA),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Color(0xFF1E8E5A), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivered!',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Client: ${request.clientName.trim().isEmpty ? '-' : request.clientName.trim()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Shipped by: ${(request.shippedByCourier ?? '').trim().isEmpty ? '-' : (request.shippedByCourier ?? '').trim()}',
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.65),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Delivered on: ${_fmtDate(request.deliveredAt)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Shipped on: ${_fmtDate(request.shippedAt)}',
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.65),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photosSection(String title, List<String> images) {
    final renderable = images
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 10),
        if (renderable.isEmpty)
          _softBox(
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
            ),
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
    );
  }

  Widget _measurementSection() {
    final isGroup = request.orderType == RequestOrderTypeV2.group;
    if (isGroup) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Client Measurements',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 10),
          GroupClientMeasurementsTabs(clients: _buildGroupMeasurementClients()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nail Dimensions',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _metaValueCard('Nail Shape', request.nailShape)),
            const SizedBox(width: 8),
            Expanded(child: _metaValueCard('Nail Length', request.nailLength)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _dimsCard('Left Hand', request.leftHand)),
            const SizedBox(width: 8),
            Expanded(child: _dimsCard('Right Hand', request.rightHand)),
          ],
        ),
      ],
    );
  }

  Widget _dimsCard(String title, NailDimensionsV2 dims) {
    String withMm(String raw) {
      final value = raw.trim();
      if (value.isEmpty) return '-';
      final lower = value.toLowerCase();
      if (lower.endsWith('mm')) return value;
      return '$value mm';
    }

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.blackCat.withValues(alpha: 0.60),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
            Text(
              withMm(value),
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

  Widget _metaValueCard(String label, String value) {
    final v = value.trim().isEmpty ? '-' : value.trim();
    return _softBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.60),
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            v,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<GroupClientMeasurementData> _buildGroupMeasurementClients() {
    final clients = <GroupClientMeasurementData>[
      GroupClientMeasurementData(
        name: request.clientName,
        nailShape: request.nailShape,
        nailLength: request.nailLength,
        leftHand: _dimsMap(request.leftHand),
        rightHand: _dimsMap(request.rightHand),
      ),
    ];
    final seen = <String>{request.clientName.trim().toLowerCase()};
    for (final client in request.groupClients) {
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

  Widget _softBox(Widget child) {
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

  String _fmtDate(DateTime? d) {
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
    return '${wds[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}
