import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'artist_history_page.dart'; // ✅ for ArtistOrderLite
import '../services/storage_url_resolver.dart';
import '../theme/app_colors.dart';
import '../utils/date_format_utils.dart';
import '../utils/image_cache_utils.dart';

Future<void> showDeliveredHistorySheetLite({
  required BuildContext context,
  required ArtistOrderLite order,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DeliveredHistorySheetLite(order: order),
  );
}

class _DeliveredHistorySheetLite extends StatelessWidget {
  const _DeliveredHistorySheetLite({required this.order});
  final ArtistOrderLite order;

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
        cacheWidth: kMaxImageDecodeDimension,
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
        cacheWidth: kMaxImageDecodeDimension,
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
            cacheWidth: kMaxImageDecodeDimension,
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
      future: StorageUrlResolver.resolve(path).then((v) => v ?? ''),
      builder: (_, snap) {
        final url = (snap.data ?? '').trim();
        if (url.isEmpty) return fallback();
        return Image.network(
          url,
          fit: BoxFit.cover,
          cacheWidth: kMaxImageDecodeDimension,
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

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Delivery history',
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
              const SizedBox(height: 8),

              // ✅ NO duplicate "Ava Client's Request" text
              // ✅ X button top-right
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _hero(context),
                    const SizedBox(height: 12),

                    // ✅ Shipped with + Budget (exact layout)
                    Row(
                      children: [
                        Expanded(
                          child: _pillCard(
                            icon: Icons.local_shipping_outlined,
                            text: 'Shipped with ${order.carrier ?? '—'}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _pillCard(
                            icon: Icons.attach_money_rounded,
                            text:
                                'Budget: \$${order.budgetMin} to \$${order.budgetMax}',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ✅ Delivered section (exact content)
                    _deliveredCard(),
                    const SizedBox(height: 16),

                    // ✅ ONLY photos sections after this (nothing else)
                    _sectionTitle('Uploaded Photos (Client)'),
                    const SizedBox(height: 10),
                    if (order.clientPhotos.isEmpty)
                      _emptyPhotos()
                    else
                      _photosGrid(order.clientPhotos),

                    const SizedBox(height: 16),

                    _sectionTitle('Uploaded Photos (Artist)'),
                    const SizedBox(height: 10),
                    if (order.artistPhotos.isEmpty)
                      _emptyPhotos()
                    else
                      _photosGrid(order.artistPhotos),
                  ],
                ),
              ),

              // ✅ Bottom close button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
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
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final s = MediaQuery.of(context).size.width < 390 ? 0.92 : 1.0;
    final avatarPath = (order.imageAsset ?? '').trim();
    final letter = order.clientName.isEmpty
        ? ''
        : order.clientName[0].toUpperCase();

    return Column(
      children: [
        if (avatarPath.isNotEmpty)
          SizedBox(
            height: 78 * s,
            width: 78 * s,
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: _imageForPath(avatarPath),
            ),
          )
        else
          Container(
            height: 78 * s,
            width: 78 * s,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              color: AppColors.balletSlippers,
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22 * s,
                color: AppColors.blackCat,
              ),
            ),
          ),
        const SizedBox(height: 10),
        Text(
          order.clientName,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22 * s),
        ),
        const SizedBox(height: 2),
        Text(
          order.title,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18 * s),
        ),
        const SizedBox(height: 2),
        Text(
          order.subtitle,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14 * s,
            color: AppColors.blackCat.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  Widget _pillCard({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.blackCat.withValues(alpha: 0.70)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deliveredCard() {
    String fmtDate(DateTime? d) => formatDateMdyOrDash(d, fallback: '—');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppColors.snow,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.blackCat.withValues(alpha: 0.05),
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check_rounded, color: Color(0xFF2E8B57)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivered!',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'Delivered on: ${fmtDate(order.deliveredAt)}',
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Shipped on: ${fmtDate(order.shippedAt)}',
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                /*const SizedBox(height: 4),
                Text(
                  'Shipped with: ${order.carrier ?? '—'}',
                  style: TextStyle(color: AppColors.blackCat.withValues(alpha: 0.65), fontWeight: FontWeight.w700),
                ),*/
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
  );

  Widget _emptyPhotos() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Row(
        children: [
          Icon(
            Icons.image_outlined,
            color: AppColors.blackCat.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 10),
          Text(
            'No photos',
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.65),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
          final path = renderable[i];
          return SizedBox(
            width: 112,
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: _imageForPath(path),
            ),
          );
        },
      ),
    );
  }
}
