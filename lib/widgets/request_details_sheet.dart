// lib/widgets/request_details_sheet.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/storage_url_resolver.dart';

/// ==============================
/// Enums
/// ==============================
enum RequestStatus {
  newRequest,
  inReview,
  accepted,
  declined,
  completed,
  shipped,
  delivered,
  cancelled,
  expired,
}

/// ==============================
/// Models
/// ==============================
@immutable
class NailDimensions {
  final String thumb;
  final String index;
  final String middle;
  final String ring;
  final String pinky;

  const NailDimensions({
    required this.thumb,
    required this.index,
    required this.middle,
    required this.ring,
    required this.pinky,
  });
}

@immutable
class ClientRequest {
  final String id;
  final String clientName;
  final String title;
  final String subtitle;
  final DateTime neededBy;
  final int budgetMin;
  final int budgetMax;
  final NailDimensions leftHand;
  final NailDimensions rightHand;
  final String nailShape;
  final String nailLength;
  final String bio;

  final List<String> images; // client uploaded (assets/urls)
  final List<String> artistUploads; // completion photos (paths/urls)

  final RequestStatus status;

  // shipping fields (appear after completed)
  final String? shippingQrCode;
  final String? shippingCarrier;
  final String? shippingService;
  final String? shippingLabelId;

  // shipped fields
  final String? trackingNumber;
  final DateTime? shippedAt;

  // delivered fields
  final DateTime? deliveredAt;

  const ClientRequest({
    required this.id,
    required this.clientName,
    required this.title,
    required this.subtitle,
    required this.neededBy,
    required this.budgetMin,
    required this.budgetMax,
    required this.leftHand,
    required this.rightHand,
    required this.nailShape,
    required this.nailLength,
    required this.bio,
    required this.images,
    this.artistUploads = const [],
    required this.status,
    this.shippingQrCode,
    this.shippingCarrier,
    this.shippingService,
    this.shippingLabelId,
    this.trackingNumber,
    this.shippedAt,
    this.deliveredAt,
  });

  ClientRequest copyWith({
    RequestStatus? status,
    List<String>? artistUploads,
    String? shippingQrCode,
    String? shippingCarrier,
    String? shippingService,
    String? shippingLabelId,
    String? trackingNumber,
    DateTime? shippedAt,
    DateTime? deliveredAt,
  }) {
    return ClientRequest(
      id: id,
      clientName: clientName,
      title: title,
      subtitle: subtitle,
      neededBy: neededBy,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      leftHand: leftHand,
      rightHand: rightHand,
      nailShape: nailShape,
      nailLength: nailLength,
      bio: bio,
      images: images,
      artistUploads: artistUploads ?? this.artistUploads,
      status: status ?? this.status,
      shippingQrCode: shippingQrCode ?? this.shippingQrCode,
      shippingCarrier: shippingCarrier ?? this.shippingCarrier,
      shippingService: shippingService ?? this.shippingService,
      shippingLabelId: shippingLabelId ?? this.shippingLabelId,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      shippedAt: shippedAt ?? this.shippedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }
}

/// ==============================
/// Public opener (USED by History page)
/// ==============================
Future<void> openRequestDetailsSheet({
  required BuildContext context,
  required ClientRequest request,
}) async {
  if (request.status == RequestStatus.delivered) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeliveredHistorySheet(request: request),
    );
    return;
  }

  if (request.status == RequestStatus.declined ||
      request.status == RequestStatus.expired ||
      request.status == RequestStatus.cancelled) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SimpleHistoryStatusSheet(request: request),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RequestDetailsSheet(
      request: request,
      readOnly: true,
      onDecline: null,
      onAccept: null,
      onUploadCompleted: null,
      onTakeCompleted: null,
      onDeleteCompletedAt: null,
      onMarkCompleted: () async {},
      onMarkShipped: (t) async {},
      onMarkDelivered: () async {},
    ),
  );
}

/// ==============================
/// Fullscreen image viewer
/// ==============================

Future<String> _resolveSheetDisplayPath(String raw) async {
  var p = raw.trim();
  for (var i = 0; i < 3; i++) {
    try {
      final decoded = Uri.decodeFull(p);
      if (decoded == p) break;
      p = decoded.trim();
    } catch (_) {
      break;
    }
  }

  if (p.isEmpty) return '';
  if (p.startsWith('http://') ||
      p.startsWith('https://') ||
      p.startsWith('assets/') ||
      p.startsWith('blob:') ||
      p.startsWith('data:') ||
      p.startsWith('content://') ||
      p.startsWith('file://')) {
    return p;
  }

  final looksStoragePath =
      p.startsWith('company_custom_requests/') ||
      p.startsWith('client_custom_requests/') ||
      p.startsWith('clients/') ||
      p.startsWith('artists/') ||
      p.startsWith('client_artists/') ||
      p.startsWith('company/') ||
      p.startsWith('request-inspiration-photos/') ||
      p.startsWith('portfolio-images/') ||
      p.startsWith('profile-pictures/') ||
      (!p.contains('://') && p.contains('/'));

  if (looksStoragePath) {
    final resolved = await StorageUrlResolver.resolve(p);
    if ((resolved ?? '').trim().isNotEmpty) return resolved!.trim();
  }

  final resolved = await StorageUrlResolver.resolve(p);
  if ((resolved ?? '').trim().isNotEmpty) return resolved!.trim();
  return p;
}

ImageProvider _sheetProviderForResolved(String path) {
  String decodeRepeated(String value) {
    var out = value;
    for (var i = 0; i < 3; i++) {
      try {
        final decoded = Uri.decodeFull(out);
        if (decoded == out) break;
        out = decoded;
      } catch (_) {
        break;
      }
    }
    return out;
  }

  var p = decodeRepeated(path.trim());
  if (p.startsWith('assets/')) {
    final rest = p.substring('assets/'.length);
    final decodedRest = decodeRepeated(rest).trim();
    final lower = decodedRest.toLowerCase();
    if (lower.startsWith('data:') ||
        lower.startsWith('blob:') ||
        lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('content://') ||
        lower.startsWith('file://')) {
      p = decodedRest;
    }
  }

  if (p.startsWith('data:image/')) {
    final comma = p.indexOf(',');
    if (comma > 0 && comma < p.length - 1) {
      try {
        return MemoryImage(base64Decode(p.substring(comma + 1)));
      } catch (_) {}
    }
  }

  final isAsset = p.startsWith('assets/');
  final isNetwork =
      p.startsWith('http://') ||
      p.startsWith('https://') ||
      p.startsWith('blob:') ||
      p.startsWith('content://');
  final isFileUri = p.startsWith('file://');
  if (isNetwork || (kIsWeb && !isAsset)) return NetworkImage(p);
  if (isAsset) return AssetImage(p);
  if (isFileUri) {
    final localPath = p.replaceFirst('file://', '');
    return FileImage(File(localPath));
  }
  return FileImage(File(p));
}


class _ImageViewerDialog extends StatelessWidget {
  const _ImageViewerDialog({required this.image});
  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              child: Center(
                child: Image(image: image, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: AppColors.blackCat),
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    );
  }
}

/// ==============================
/// ✅ Center header (NO X here)
/// X is placed at top-right of the popup container (not near avatar)
/// ==============================
class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.clientName,
    required this.title,
    required this.subtitle,
  });

  final String clientName;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final letter = clientName.isEmpty ? '' : clientName[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              color: Colors.black.withValues(alpha: 0.06),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: AppColors.blackCat,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            clientName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ), // ✅ smaller
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ), // ✅ smaller
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.45),
              fontWeight: FontWeight.w600,
              fontSize: 12, // ✅ smaller
            ),
          ),
        ],
      ),
    );
  }
}

/// ==============================
/// ✅ Delivered History Sheet
/// ==============================
class _DeliveredHistorySheet extends StatelessWidget {
  const _DeliveredHistorySheet({required this.request});
  final ClientRequest request;

  bool _isUrl(String p) => p.startsWith('http://') || p.startsWith('https://');

  ImageProvider _providerFor(String path) {
    String decodeRepeated(String value) {
      var out = value;
      for (var i = 0; i < 3; i++) {
        try {
          final decoded = Uri.decodeFull(out);
          if (decoded == out) break;
          out = decoded;
        } catch (_) {
          break;
        }
      }
      return out;
    }

    var p = path.trim();
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      final decodedRest = decodeRepeated(rest).trim();
      final lower = decodedRest.toLowerCase();
      if (lower.startsWith('data:') ||
          lower.startsWith('blob:') ||
          lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('content://') ||
          lower.startsWith('file://')) {
        p = decodedRest;
      }
    }
    p = decodeRepeated(p).trim();
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      final decodedRest = decodeRepeated(rest).trim();
      final lower = decodedRest.toLowerCase();
      if (lower.startsWith('data:') ||
          lower.startsWith('blob:') ||
          lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('content://') ||
          lower.startsWith('file://')) {
        p = decodedRest;
      }
    }
    if (p.startsWith('data:image/')) {
      final comma = p.indexOf(',');
      if (comma > 0 && comma < p.length - 1) {
        try {
          return MemoryImage(base64Decode(p.substring(comma + 1)));
        } catch (_) {}
      }
    }
    final isAsset = p.startsWith('assets/');
    final isNetwork =
        _isUrl(p) || p.startsWith('blob:') || p.startsWith('content://');
    final isFileUri = p.startsWith('file://');
    if (isNetwork || (kIsWeb && !isAsset)) return NetworkImage(p);
    if (isAsset) return AssetImage(p);
    if (isFileUri) {
      final localPath = p.replaceFirst('file://', '');
      return FileImage(File(localPath));
    }
    return FileImage(File(p));
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Stack(
        children: [
          Container(
            constraints: BoxConstraints(maxHeight: maxH),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F7FB),
              borderRadius: BorderRadius.zero,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  height: 5,
                  width: 54,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                const SizedBox(height: 6),

                _HistoryHeader(
                  clientName: request.clientName,
                  title: request.title,
                  subtitle: request.subtitle,
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    children: [
                      _deliveredCard(),
                      const SizedBox(height: 14),
                      const Text(
                        'Uploaded Photos (Client)',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (request.images.isEmpty)
                        _softBox(
                          Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: Colors.black.withValues(alpha: 0.45),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'No images uploaded',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        _photoGrid(
                          context: context,
                          images: request.images,
                          providerFor: _providerFor,
                        ),
                      const SizedBox(height: 14),
                      const Text(
                        'Uploaded Photos (Artist)',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (request.artistUploads.isEmpty)
                        _softBox(
                          Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: Colors.black.withValues(alpha: 0.45),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'No artist photos uploaded',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        _photoGrid(
                          context: context,
                          images: request.artistUploads,
                          providerFor: _providerFor,
                        ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: Center(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.deepPlum,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ✅ X at TOP-RIGHT CORNER of popup
          Positioned(
            right: 10,
            top: 10,
            child: Semantics(
              button: true,
              label: 'Close',
              child: ExcludeSemantics(
                child: InkWell(
                  borderRadius: BorderRadius.zero,
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.close_rounded, size: 24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deliveredCard() {
    final delivered = request.deliveredAt;
    final shipped = request.shippedAt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEAFB),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              size: 18,
              color: Color(0xFF2E8B57),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivered!',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _line(
                  'Delivered on:',
                  delivered == null ? '—' : _fmt(delivered),
                ),
                const SizedBox(height: 6),
                _line('Shipped on:', shipped == null ? '—' : _fmt(shipped)),
                const SizedBox(height: 6),
                _line('Shipped with:', request.shippingCarrier ?? '—'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String k, String v) {
    return Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.55),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
        Text(
          v,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
        ),
      ],
    );
  }

  static String _fmt(DateTime d) {
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
    final wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
    return '$wd, ${months[d.month - 1]} ${d.day}';
  }
}

/// ==============================
/// ✅ Simple History Status Sheet (Declined/Expired/Cancelled)
/// FIXES:
/// - X is at popup top-right
/// - NO big blank space before button
/// - smaller fonts
/// ==============================
class _SimpleHistoryStatusSheet extends StatelessWidget {
  const _SimpleHistoryStatusSheet({required this.request});
  final ClientRequest request;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;

    final isExpired = request.status == RequestStatus.expired;
    final isDeclined = request.status == RequestStatus.declined;
    final isCancelled = request.status == RequestStatus.cancelled;

    final statusTitle = isExpired
        ? 'Expired'
        : isDeclined
        ? 'Declined'
        : 'Cancelled';

    final icon = isExpired ? Icons.event_busy_rounded : Icons.close_rounded;

    final tint = isExpired ? const Color(0xFFB65A1E) : const Color(0xFFB42318);
    final bg = isExpired ? const Color(0xFFF8EEE8) : const Color(0xFFF7E9EE);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Stack(
        children: [
          Container(
            constraints: BoxConstraints(maxHeight: maxH),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F7FB),
              borderRadius: BorderRadius.zero,
            ),

            // ✅ NO Expanded spacer -> content stays tight, button sits right under
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    height: 5,
                    width: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  const SizedBox(height: 6),

                  _HistoryHeader(
                    clientName: request.clientName,
                    title: request.title,
                    subtitle: request.subtitle,
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.04),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 32,
                            width: 32,
                            decoration: BoxDecoration(
                              color: tint.withValues(alpha: 0.20),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(icon, size: 18, color: tint),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  statusTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16, // ✅ smaller
                                    color: tint,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$statusTitle on: Tue, Apr 23',
                                  style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.60),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5, // ✅ smaller
                                  ),
                                ),
                                if (isCancelled) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Reason: Client canceled request',
                                    style: TextStyle(
                                      color: Colors.black.withValues(alpha: 0.60),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5, // ✅ smaller
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ✅ NO extra spacer here
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      0,
                    ), // keep spacing before button
                    child: Center(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.deepPlum,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
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

          // ✅ X at TOP-RIGHT CORNER of popup (NOT near avatar)
          Positioned(
            right: 10,
            top: 10,
            child: Semantics(
              button: true,
              label: 'Close',
              child: ExcludeSemantics(
                child: InkWell(
                  borderRadius: BorderRadius.zero,
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.close_rounded, size: 24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared soft box helper
Widget _softBox(Widget child) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.zero,
      border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
    ),
    child: child,
  );
}

/// Shared horizontal photo helper
Widget _photoGrid({
  required BuildContext context,
  required List<String> images,
  required ImageProvider Function(String path) providerFor,
}) {
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
        return FutureBuilder<String>(
          future: _resolveSheetDisplayPath(renderable[i]),
          builder: (context, snap) {
            final resolved = (snap.data ?? '').trim();
            if (resolved.isEmpty) {
              return const SizedBox(width: 148);
            }
            final provider = _sheetProviderForResolved(resolved);
            return SizedBox(
              width: 148,
              child: Semantics(
                button: true,
                label: 'View photo full screen',
                child: ExcludeSemantics(
                  child: InkWell(
                    borderRadius: BorderRadius.zero,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => _ImageViewerDialog(image: provider),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: Image(
                        image: provider,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: Colors.black.withValues(alpha: 0.06),
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

/// ===========================================================================
/// ✅ KEEP your existing full _RequestDetailsSheet below (UNCHANGED)
/// ===========================================================================

class _RequestDetailsSheet extends StatefulWidget {
  const _RequestDetailsSheet({
    required this.request,
    required this.readOnly,
    required this.onDecline,
    required this.onAccept,
    required this.onUploadCompleted,
    required this.onTakeCompleted,
    required this.onDeleteCompletedAt,
    required this.onMarkCompleted,
    required this.onMarkShipped,
    required this.onMarkDelivered,
  });

  final ClientRequest request;
  final bool readOnly;
  final VoidCallback? onDecline;
  final Future<void> Function()? onAccept;

  final VoidCallback? onUploadCompleted;
  final VoidCallback? onTakeCompleted;
  final Future<void> Function(int index)? onDeleteCompletedAt;

  final Future<void> Function() onMarkCompleted;
  final Future<void> Function(String tracking) onMarkShipped;
  final Future<void> Function() onMarkDelivered;

  @override
  State<_RequestDetailsSheet> createState() => _RequestDetailsSheetState();
}

class _RequestDetailsSheetState extends State<_RequestDetailsSheet> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
