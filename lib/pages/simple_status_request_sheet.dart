import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_request_v2.dart';
import '../services/storage_url_resolver.dart';
import '../theme/app_colors.dart';
import '../widgets/group_client_measurements_tabs.dart';

enum SimpleRequestStatus { cancelled, declined, expired }

Future<void> showSimpleStatusRequestSheet({
  required BuildContext context,
  required ClientRequestV2 request,
  required SimpleRequestStatus status,
  required DateTime date,
  Future<void> Function()? onResubmit,
  bool forceDeclinedByArtistReason = false,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SimpleStatusRequestSheet(
      request: request,
      status: status,
      date: date,
      onResubmit: onResubmit,
      forceDeclinedByArtistReason: forceDeclinedByArtistReason,
    ),
  );
}

class _SimpleStatusRequestSheet extends StatelessWidget {
  const _SimpleStatusRequestSheet({
    required this.request,
    required this.status,
    required this.date,
    this.onResubmit,
    this.forceDeclinedByArtistReason = false,
  });

  final ClientRequestV2 request;
  final SimpleRequestStatus status;
  final DateTime date;
  final Future<void> Function()? onResubmit;
  final bool forceDeclinedByArtistReason;
  static const int _decodeMax = 1024;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.78;
    final cfg = _statusConfig(status);
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
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          height: 5,
                          width: 54,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _topHeroCondensed(request),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.snow,
                          borderRadius: BorderRadius.zero,
                          border: Border.all(
                            color: AppColors.blackCatBorderLight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 34,
                              width: 34,
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                cfg.icon,
                                color: cfg.iconColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cfg.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: cfg.titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${cfg.subtitle} ${_formatDate(date)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      fontSize: 13.5,
                                      color: Colors.black.withValues(
                                        alpha: 0.62,
                                      ),
                                    ),
                                  ),
                                  if (_statusReason().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_reasonLabel()}: ${_statusReason()}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13.5,
                                        color: Colors.black.withValues(
                                          alpha: 0.70,
                                        ),
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (status != SimpleRequestStatus.expired &&
                          request.orderType == RequestOrderTypeV2.group &&
                          status != SimpleRequestStatus.declined) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Client Measurements',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.black.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        GroupClientMeasurementsTabs(
                          clients: _buildGroupMeasurementClients(request),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Center(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
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
                                onPressed: () => Navigator.pop(context),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 18),
                                  child: Text(
                                    'Close',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      fontFamily: 'Arial',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (onResubmit != null)
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.snow,
                                    foregroundColor: AppColors.blackCat,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    side: const BorderSide(
                                      color: AppColors.blackCat,
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await onResubmit!.call();
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 18,
                                    ),
                                    child: Text(
                                      'Resubmit',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        fontFamily: 'Arial',
                                      ),
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
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: InkWell(
                borderRadius: BorderRadius.zero,
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.close_rounded,
                    size: 24,
                    color: Colors.black.withValues(alpha: 0.70),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topHeroCondensed(ClientRequestV2 r) {
    final letter = r.clientName.isEmpty ? '' : r.clientName[0].toUpperCase();
    final showTitle =
        r.title.trim().isNotEmpty &&
        r.title.trim().toLowerCase() != r.clientName.trim().toLowerCase();

    return Column(
      children: [
        FutureBuilder<String>(
          future: _resolveClientProfileImage(r),
          initialData: r.clientProfileImage.trim(),
          builder: (context, snapshot) {
            final avatarPath = _normalizeImagePath(
              (snapshot.data ?? '').trim(),
            );
            if (avatarPath.isNotEmpty) {
              return SizedBox(
                height: 70,
                width: 70,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: _imageForPath(avatarPath),
                ),
              );
            }
            return Container(
              height: 70,
              width: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.zero,
                color: AppColors.balletSlippers,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.blackCat,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          r.clientName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.blackCat,
          ),
        ),
        if (showTitle) ...[
          const SizedBox(height: 2),
          Text(
            r.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.blackCat,
            ),
          ),
        ],
        const SizedBox(height: 2),
        Text(
          r.subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  Future<String> _resolveClientProfileImage(ClientRequestV2 request) async {
    final accepted = _normalizeImagePath(
      request.acceptedClientProfileImage.trim(),
    );
    if (accepted.isNotEmpty) return accepted;

    final existing = _normalizeImagePath(request.clientProfileImage.trim());
    if (existing.isNotEmpty) return existing;

    return _lookupClientProfileImage(
      email: request.clientEmail.trim(),
      name: request.clientName.trim(),
    );
  }

  Future<String> _lookupClientProfileImage({
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
      return _normalizeImagePath(
        firstNonEmpty(<Object?>[
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
        ]),
      );
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
      color: Colors.black.withValues(alpha: 0.06),
      child: Icon(
        Icons.broken_image_outlined,
        color: Colors.black.withValues(alpha: 0.35),
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
          cacheWidth: _decodeMax,
          cacheHeight: _decodeMax,
          filterQuality: FilterQuality.low,
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

  _StatusConfig _statusConfig(SimpleRequestStatus s) {
    switch (s) {
      case SimpleRequestStatus.cancelled:
        return _StatusConfig(
          title: 'Cancelled',
          subtitle: 'Cancelled on',
          icon: Icons.block_rounded,
          titleColor: AppColors.blackCat,
          iconColor: AppColors.blackCat,
          iconBg: const Color(0xFFFFF3CD),
          bgColor: const Color(0xFFFFF8E6),
          borderColor: const Color(0xFFFFE8A1),
        );
      case SimpleRequestStatus.declined:
        return _StatusConfig(
          title: 'Declined',
          subtitle: 'Declined on',
          icon: Icons.close_rounded,
          titleColor: AppColors.blackCat,
          iconColor: AppColors.blackCat,
          iconBg: const Color(0xFFFFE4E8),
          bgColor: const Color(0xFFFFF1F3),
          borderColor: const Color(0xFFFFCCD5),
        );
      case SimpleRequestStatus.expired:
        return _StatusConfig(
          title: 'Expired',
          subtitle: 'Expired on',
          icon: Icons.event_busy_rounded,
          titleColor: AppColors.blackCat,
          iconColor: AppColors.blackCat,
          iconBg: const Color(0xFFFFEDD5),
          bgColor: const Color(0xFFFFF4E6),
          borderColor: const Color(0xFFFFD6A8),
        );
    }
  }

  String _statusReason() {
    if (status == SimpleRequestStatus.cancelled) {
      final reason = request.cancelReason.trim();
      return reason.isNotEmpty ? reason : 'Cancelled by user';
    }
    if (status == SimpleRequestStatus.declined) {
      if (forceDeclinedByArtistReason) {
        return 'Declined by Artist';
      }
      final reason = request.declineReason.trim();
      if (reason.isNotEmpty) return reason;
      if (request.cancelReason.trim().isNotEmpty) {
        return request.cancelReason.trim();
      }
      if (request.completionDeclineReason.trim().isNotEmpty) {
        return request.completionDeclineReason.trim();
      }
      if (request.completionDeclineDescription.trim().isNotEmpty) {
        return request.completionDeclineDescription.trim();
      }
      return 'Declined by Artist';
    }
    return 'Request expired';
  }

  String _reasonLabel() {
    switch (status) {
      case SimpleRequestStatus.declined:
        return 'Decline reason';
      case SimpleRequestStatus.cancelled:
        return 'Cancellation reason';
      case SimpleRequestStatus.expired:
        return 'Reason';
    }
  }

  static String _formatDate(DateTime d) {
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
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  List<GroupClientMeasurementData> _buildGroupMeasurementClients(
    ClientRequestV2 request,
  ) {
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
}

class _StatusConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color titleColor;
  final Color iconColor;
  final Color iconBg;
  final Color bgColor;
  final Color borderColor;

  _StatusConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.titleColor,
    required this.iconColor,
    required this.iconBg,
    required this.bgColor,
    required this.borderColor,
  });
}
