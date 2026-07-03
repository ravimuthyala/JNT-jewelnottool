import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../models/client_request_v2.dart';
import '../services/notifications_service.dart';
import '../utils/shipping_qr_helper.dart';
import '../services/storage_url_resolver.dart';
import '../widgets/group_client_measurements_tabs.dart';
import '../utils/request_nfc_details_loader.dart';
import 'request_chat_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> showAcceptedRequestSheet({
  required BuildContext context,
  required ClientRequestV2 request,
  required int shipDays,
  required VoidCallback onClose,
  required Future<void> Function(bool completed, List<String> artistPhotos)
  onMarkCompleted,
}) async {
  final result = await showModalBottomSheet<_AcceptedSheetResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AcceptedRequestSheet(
      request: request,
      shipDays: shipDays,
      mode: _AcceptedSheetMode.accepted,
    ),
  );

  // The request row is already updated inside _handleMarkCompleted().
  if (result?.completed == true) {
    await onMarkCompleted(true, result?.artistPhotos ?? const <String>[]);
  } else {
    await onMarkCompleted(false, const <String>[]);
  }
}

Future<void> showDesigningRequestSheet({
  required BuildContext context,
  required ClientRequestV2 request,
  required int shipDays,
  required VoidCallback onClose,
  required Future<void> Function(bool completed, List<String> artistPhotos)
  onMarkCompleted,
}) async {
  final result = await showModalBottomSheet<_AcceptedSheetResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AcceptedRequestSheet(
      request: request,
      shipDays: shipDays,
      mode: _AcceptedSheetMode.designing,
    ),
  );

  // The request row is already updated inside _handleMarkCompleted().
  if (result?.completed == true) {
    await onMarkCompleted(true, result?.artistPhotos ?? const <String>[]);
  } else {
    await onMarkCompleted(false, const <String>[]);
  }
}

class _AcceptedSheetResult {
  const _AcceptedSheetResult({
    required this.completed,
    required this.artistPhotos,
  });

  final bool completed;
  final List<String> artistPhotos;
}

class _AcceptedRequestSheet extends StatefulWidget {
  const _AcceptedRequestSheet({
    required this.request,
    required this.shipDays,
    required this.mode,
  });

  final ClientRequestV2 request;
  final int shipDays;
  final _AcceptedSheetMode mode;

  @override
  State<_AcceptedRequestSheet> createState() => _AcceptedRequestSheetState();
}

class _AcceptedRequestSheetState extends State<_AcceptedRequestSheet> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _picker = ImagePicker();
  static const int _maxArtistImageBytes = 2 * 1024 * 1024;
  static const int _maxArtistCompletedPhotos = 10;

  /// Local photos selected for the final completed set.
  final List<XFile> _artistPhotos = [];

  bool _markingCompleted = false;

  List<String> _clientModalPhotos() {
    final out = <String>[];
    for (final raw in widget.request.clientImages) {
      final s = raw.trim();
      if (s.isNotEmpty && !out.contains(s)) out.add(s);
    }
    final preview = widget.request.previewImageAsset.trim();
    if (out.isEmpty && preview.isNotEmpty) out.add(preview);
    return out;
  }

  String _heroPhotoSource(ClientRequestV2 r) {
    final profile = r.clientProfileImage.trim();
    if (profile.isNotEmpty) return profile;
    return '';
  }

  Future<String> _resolvedHeroPhotoSource(ClientRequestV2 r) async {
    final existing = _heroPhotoSource(r).trim();
    if (existing.isNotEmpty) return existing;
    return _lookupClientProfileImage(
      email: r.clientEmail.trim(),
      name: r.clientName.trim(),
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
      return firstNonEmpty(<Object?>[
        row['client_profile_image'], row['clientProfileImage'],
        row['profileImageUrl'], row['profile_image_url'], row['profile_picture_url'],
        row['profilePhotoUrl'], row['profile_photo_url'],
        row['avatarUrl'], row['avatar_url'], row['photoUrl'], row['photo_url'],
        profile['profileImageUrl'], profile['profile_image_url'], profile['profile_picture_url'], profile['avatarUrl'], profile['avatar_url'], profile['photoUrl'], profile['photo_url'],
        basic['profileImageUrl'], basic['profile_image_url'], basic['profile_picture_url'], basic['avatarUrl'], basic['avatar_url'], basic['photoUrl'], basic['photo_url'],
        client['profileImageUrl'], client['profile_image_url'], client['profile_picture_url'], client['avatarUrl'], client['avatar_url'], client['photoUrl'], client['photo_url'],
        clientProfile['profileImageUrl'], clientProfile['profile_image_url'], clientProfile['profile_picture_url'], clientProfile['avatarUrl'], clientProfile['avatar_url'], clientProfile['photoUrl'], clientProfile['photo_url'],
        data['clientProfileImage'], data['client_profile_image'], data['profileImageUrl'], data['profile_image_url'], data['avatarUrl'], data['avatar_url'], data['photoUrl'], data['photo_url'],
      ]);
    }

    Future<String> lookupBy(String table, String column, String value) async {
      final needle = value.trim();
      if (needle.isEmpty) return '';
      try {
        final row = await _supabase
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

    for (final table in const <String>['client', 'clients', 'client_artist']) {
      for (final column in const <String>['email', 'client_email']) {
        final byEmail = await lookupBy(table, column, email.toLowerCase());
        if (byEmail.isNotEmpty) return byEmail;
      }
    }
    for (final table in const <String>['client', 'clients', 'client_artist']) {
      for (final column in const <String>['name', 'displayName', 'display_name', 'client_name']) {
        final byName = await lookupBy(table, column, name);
        if (byName.isNotEmpty) return byName;
      }
    }
    return '';
  }

  bool get _showClientDeclineInfo =>
      widget.request.completionReviewStatus.trim().toLowerCase() == 'declined';

  bool get _isDesigningMode => widget.mode == _AcceptedSheetMode.designing;

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

  List<dynamic> _asList(Object? value) {
    if (value is List) return List<dynamic>.from(value);
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return <dynamic>[];
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) return List<dynamic>.from(decoded);
      } catch (_) {}
    }
    return <dynamic>[];
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
      final dataArtistQuote = _asMap(data['artistQuote'] ?? data['artist_quote']);
      final payloadArtistQuote = _asMap(payload['artistQuote'] ?? payload['artist_quote']);
      final detailsArtistQuote = _asMap(details['artistQuote'] ?? details['artist_quote']);

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
      if (root != null) maps.add(Map<String, dynamic>.from(root as Map));
    } catch (_) {}

    try {
      final orderNo = widget.request.orderNumber.trim();
      if (orderNo.isNotEmpty) {
        final rootByOrder = await _supabase
            .from(_requestTable)
            .select()
            .or('order_number.eq.$orderNo,request_number.eq.$orderNo')
            .maybeSingle();
        if (rootByOrder != null) {
          maps.add(Map<String, dynamic>.from(rootByOrder as Map));
        }
      }
    } catch (_) {}

    try {
      final details = await _supabase
          .from(_requestDetailsTable)
          .select()
          .eq('request_id', widget.request.id);
      for (final row in details) {
        final map = _asMap(row);
        maps.add(map);
        maps.add(_asMap(map['data']));
      }
    } catch (_) {}

    return _amountFromMaps(maps);
  }

  String _formatMoneyAmount(double? amount) {
    if (amount == null || amount <= 0) return '-';
    final rounded = amount.roundToDouble();
    if ((amount - rounded).abs() < 0.01) return '\$${rounded.toInt()}';
    return '\$${amount.toStringAsFixed(2)}';
  }

  List<dynamic> _mergeUniqueList(List<dynamic> base, List<dynamic> incoming) {
    final out = <dynamic>[...base];
    final seen = out.map((e) => jsonEncode(e)).toSet();
    for (final item in incoming) {
      final key = jsonEncode(item);
      if (seen.add(key)) out.add(item);
    }
    return out;
  }

  String _currentUserEmail() =>
      (_supabase.auth.currentUser?.email ?? '').trim().toLowerCase();

  String _currentUserId() => (_supabase.auth.currentUser?.id ?? '').trim();

  String _currentUserDisplayName() {
    final user = _supabase.auth.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final candidates = <Object?>[
      metadata['display_name'],
      metadata['displayName'],
      metadata['full_name'],
      metadata['name'],
      user?.email?.split('@').first,
    ];
    for (final raw in candidates) {
      final value = (raw ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Object? _firstPresent(Map<String, dynamic> source, String snakeKey, String camelKey) {
    if (source.containsKey(snakeKey)) return source[snakeKey];
    return source[camelKey];
  }

  Future<Map<String, dynamic>?> _findUserRowByEmail(
    List<String> tables,
    String email,
  ) async {
    for (final table in tables) {
      final row = await _supabase
          .from(table)
          .select()
          .ilike('email', email)
          .maybeSingle();
      if (row != null) {
        return <String, dynamic>{
          ...Map<String, dynamic>.from(row),
          '_table': table,
        };
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _findUserRowById(
    List<String> tables,
    String id,
  ) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return null;
    for (final table in tables) {
      final row =
          await _supabase.from(table).select().eq('id', normalizedId).maybeSingle();
      if (row != null) {
        return <String, dynamic>{
          ...Map<String, dynamic>.from(row),
          '_table': table,
        };
      }
      final byUid =
          await _supabase.from(table).select().eq('uid', normalizedId).maybeSingle();
      if (byUid != null) {
        return <String, dynamic>{
          ...Map<String, dynamic>.from(byUid),
          '_table': table,
        };
      }
    }
    return null;
  }



  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _AcceptedRequestSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;

    final clientModalPhotos = _clientModalPhotos();
    return Align(
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
            const SizedBox(height: 10),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _topHeader(widget.request, shipDays: widget.shipDays),

                  const SizedBox(height: 12),

                  // ✅ Accepted / Designing card
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 22,
                        width: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CBF6A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: AppColors.blackCat.withValues(alpha: 0.78),
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                              fontSize: 13.5,
                            ),
                            children: [
                              TextSpan(
                                text: _isDesigningMode
                                    ? 'Designing!\n'
                                    : 'Accepted!\n',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              TextSpan(
                                text: _isDesigningMode
                                    ? 'You are now designing '
                                    : 'You accepted ',
                              ),
                              TextSpan(
                                text: "${widget.request.clientName}'s request",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: _isDesigningMode
                                    ? '. Continue designing the set, upload photos, and mark as completed.'
                                    : '. Once the set is ready, upload photos and mark as completed.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (!_isDesigningMode)
                    _paymentSectionBox(widget.request),
                  if (!_isDesigningMode) ...[
                    const SizedBox(height: 10),
                  ],
                  if (_showClientDeclineInfo) ...[
                    _clientDeclineReasonSection(widget.request),
                    const SizedBox(height: 10),
                  ],

                  _softBox(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Description'),
                        const SizedBox(height: 8),
                        Text(
                          widget.request.bio.trim().isEmpty
                              ? '�'
                              : widget.request.bio.trim(),
                          style: TextStyle(
                            color: AppColors.blackCat.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w400,
                            height: 1.25,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isBrandRequest(widget.request)) ...[
                    _acceptedClientDetailsSection(widget.request),
                    const SizedBox(height: 10),
                  ],
                  _measurementSection(),
                  if (_isDesigningMode) ...[
                    const SizedBox(height: 12),
                    _finalAcceptedAmountBox(widget.request),
                  ],
                  const SizedBox(height: 12),
                  _softBox(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Uploaded Photos (Client)'),
                        const SizedBox(height: 10),
                        if (clientModalPhotos.isEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: AppColors.blackCat.withValues(alpha: 0.45),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'No images uploaded',
                                style: TextStyle(
                                  color: AppColors.blackCat.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        else
                          _clientPhotosGrid(clientModalPhotos),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_isDesigningMode) ...[
                    _softBox(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionTitle('Upload Completed Set (Artist)'),
                          const SizedBox(height: 10),
                          Center(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.blackCat.withValues(
                                    alpha: 0.78,
                                  ),
                                  foregroundColor: AppColors.snow,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                ),
                                onPressed: () => _openPickOptions(),
                                icon: const Icon(Icons.add_a_photo_outlined),
                                label: const Text(
                                  'Upload',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Allowed formats: JPG, JPEG, PNG. Max file size: < 2 MB each. Maximum 10 photos.',
                            style: TextStyle(
                              color: AppColors.blackCat.withValues(alpha: 0.55),
                              fontWeight: FontWeight.w500,
                              fontSize: 11.5,
                            ),
                          ),
                          if (_artistPhotos.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _artistPhotosGrid(),
                          ],
                          if (_artistPhotos.isEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Add photos of the finished nails before marking as completed.',
                              style: TextStyle(
                                color: AppColors.blackCat.withValues(alpha: 0.60),
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ],
              ),
            ),

            // Bottom actions
            if (_isDesigningMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 132,
                      height: 54,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.blackCat.withValues(
                            alpha: 0.16,
                          ),
                          foregroundColor: AppColors.blackCat,
                          side: BorderSide(
                            color: AppColors.blackCat.withValues(alpha: 0.30),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () {
                          final artistEmail =
                              (widget.request.acceptedByArtistEmail
                                          .trim()
                                          .isNotEmpty
                                      ? widget.request.acceptedByArtistEmail
                                      : _currentUserEmail())
                                  .trim()
                                  .toLowerCase();
                          if (widget.request.clientEmail.trim().isEmpty ||
                              artistEmail.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Chat unavailable until both client and artist are assigned.',
                                ),
                              ),
                            );
                            return;
                          }
                          showRequestChatModal(
                            context: context,
                            requestId: widget.request.id,
                            clientEmail: widget.request.clientEmail,
                            artistEmail: artistEmail,
                            clientName: widget.request.clientName,
                            artistName: _currentUserDisplayName(),
                          );
                        },
                        child: const Text(
                          'Chat',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            fontFamily: 'Arial',
                            color: AppColors.snow,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 166,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blackCat,
                          foregroundColor: AppColors.snow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          elevation: 0,
                        ),
                        onPressed: (_markingCompleted || _artistPhotos.isEmpty)
                            ? null
                            : _handleMarkCompleted,
                        child: _markingCompleted
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Mark as Completed',
                                style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12,
                                  fontFamily: 'Arial',
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
    );
  }

  // -----------------------
  // Actions
  // -----------------------
  Future<void> _openPickOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: const BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 5,
                width: 54,
                decoration: BoxDecoration(
                  color: AppColors.blackCat.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.zero,
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add photos',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.blackCat.withValues(alpha: 0.22),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          backgroundColor: AppColors.snow,
                        ),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                          color: AppColors.blackCat,
                        ),
                        label: const Text(
                          'Choose from Gallery',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            color: AppColors.blackCat,
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _pickFromGallery();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.blackCat.withValues(alpha: 0.22),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          backgroundColor: AppColors.snow,
                        ),
                        icon: const Icon(
                          Icons.camera_alt_outlined,
                          size: 18,
                          color: AppColors.blackCat,
                        ),
                        label: const Text(
                          'Take Photo',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            color: AppColors.blackCat,
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _takePhoto();
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (picked.isEmpty) return;

    await _validateAndAddPhotos(picked);
  }

  Future<void> _takePhoto() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (x == null) return;

    await _validateAndAddPhotos([x]);
  }

  bool _isAllowedImageExtension(String value) {
    final p = value.trim().toLowerCase();
    return p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png');
  }

  bool _hasAllowedImageSignature(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return true; // JPEG
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return true; // PNG
    }
    return false;
  }

  Future<bool> _isAllowedImageFile(XFile file) async {
    if (_isAllowedImageExtension(file.name) ||
        _isAllowedImageExtension(file.path)) {
      return true;
    }
    try {
      final bytes = await file.readAsBytes();
      return _hasAllowedImageSignature(bytes);
    } catch (_) {
      return false;
    }
  }

  Future<void> _validateAndAddPhotos(List<XFile> files) async {
    final accepted = <XFile>[];
    var invalidType = 0;
    var invalidSize = 0;
    var skippedForLimit = 0;
    const maxPhotos = _maxArtistCompletedPhotos;
    final existingCount = _artistPhotos.length;

    for (final file in files) {
      if (existingCount + accepted.length >= maxPhotos) {
        skippedForLimit++;
        continue;
      }
      if (!await _isAllowedImageFile(file)) {
        invalidType++;
        continue;
      }
      final bytes = await file.length();
      if (bytes > _maxArtistImageBytes) {
        invalidSize++;
        continue;
      }
      accepted.add(file);
    }

    if (accepted.isNotEmpty) {
      setState(() {
        _artistPhotos.addAll(accepted);
      });
    }

    if (!mounted) return;
    if (invalidType > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$invalidType file(s) skipped. Only JPG, JPEG, PNG are allowed.',
          ),
        ),
      );
    }
    if (invalidSize > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$invalidSize file(s) skipped. File size must be less than 2 MB.',
          ),
        ),
      );
    }
    if (skippedForLimit > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Extra photos were skipped. Maximum is 10.'),
        ),
      );
    }
  }

  Future<void> _handleMarkCompleted() async {
    if (_artistPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least 1 photo before completing.'),
        ),
      );
      return;
    }

    setState(() => _markingCompleted = true);

    try {
      final uploadedArtistPhotos = await _uploadArtistPhotos();

      if (uploadedArtistPhotos.isEmpty) {
        throw Exception(
          'Photo upload failed. No uploaded image URL was returned.',
        );
      }

      final artistId = _currentUserId();
      final artistEmail = _currentUserEmail();
      final orderNumber = widget.request.orderNumber.trim().isNotEmpty
          ? widget.request.orderNumber.trim()
          : widget.request.id;

      final shipping = buildShippingPayload(
        collectionName: widget.request.sourceCollection,
        orderDocId: widget.request.id,
        orderNumber: orderNumber,
        artistId: artistId,
        artistEmail: artistEmail,
        shippingAddressDifferentFromProfile:
            widget.request.shippingAddressDifferentFromProfile,
        shippingStreet: widget.request.shippingStreet,
        shippingCity: widget.request.shippingCity,
        shippingState: widget.request.shippingState,
        shippingZip: widget.request.shippingZip,
        shippingCountry: widget.request.shippingCountry,
      );

      await _supabase.rpc(
        'artist_mark_request_completed',
        params: <String, dynamic>{
          'p_request_id': widget.request.id,
          'p_order_number': orderNumber,
          'p_artist_photos': uploadedArtistPhotos,
          'p_shipping': shipping,
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(
        _AcceptedSheetResult(
          completed: true,
          artistPhotos: uploadedArtistPhotos,
        ),
      );

      // Run non-critical side effects after closing the sheet so UI is not blocked.
      unawaited(_runPostCompleteSideEffects(uploadedArtistPhotos));
    } catch (e, st) {
      debugPrint('MARK COMPLETED FAILED: $e');
      debugPrintStack(stackTrace: st);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to mark completed: $e')));
    } finally {
      if (mounted) {
        setState(() => _markingCompleted = false);
      }
    }
  }

  Future<void> _runPostCompleteSideEffects(
    List<String> uploadedArtistPhotos,
  ) async {
    try {
      await _notifyClientOrderCompleted();
    } catch (e, st) {
      debugPrint(
        'POST COMPLETE notify failed request=${widget.request.id} order=${widget.request.orderNumber}: $e',
      );
      debugPrintStack(stackTrace: st);
    }
    try {
      await _mirrorCompletedPhotosToClientPortfolio(uploadedArtistPhotos);
    } catch (e, st) {
      debugPrint(
        'POST COMPLETE client portfolio mirror failed request=${widget.request.id} order=${widget.request.orderNumber}: $e',
      );
      debugPrintStack(stackTrace: st);
    }
    try {
      await _mirrorCompletedPhotosToArtistPortfolio(uploadedArtistPhotos);
    } catch (e, st) {
      debugPrint(
        'POST COMPLETE artist portfolio mirror failed request=${widget.request.id} order=${widget.request.orderNumber}: $e',
      );
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _notifyClientOrderCompleted() async {
    final orderNo = widget.request.orderNumber.trim().isNotEmpty
        ? widget.request.orderNumber.trim()
        : widget.request.id;

    final row = await _supabase
        .from(_requestTable)
        .select()
        .eq('id', widget.request.id)
        .maybeSingle();
    final data = row == null ? const <String, dynamic>{} : Map<String, dynamic>.from(row);
    final detailRow = await _supabase
        .from(_requestDetailsTable)
        .select()
        .eq('request_id', widget.request.id)
        .eq('detail_key', 'payload')
        .maybeSingle();
    final detailData = detailRow == null ? const <String, dynamic>{} : _asMap(detailRow['data']);

    if (_isBrandRequest(widget.request)) {
      // Brand request completion notifications are emitted by the centralized
      // flow in artist_requests_page_redesign.dart. Skip here to avoid duplicates.
      return;
    } else {
      // Client in-app completion notification is emitted by
      // artist_requests_page_redesign.dart. Skip here to avoid duplicates.
    }

    try {
      final profileSnapshot =
          (detailData['clientProfileSnapshot'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final basic =
          (profileSnapshot['basic'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final phone =
          ((data['clientPhone'] ?? basic['phone'] ?? data['phone'] ?? '')
                  as Object)
              .toString()
              .trim();
      if (phone.isNotEmpty) {
        await NotificationsService.queueSms(
          to: phone,
          text:
              'JNT: Your completed design for order $orderNo is ready for review. Please accept or decline in the app.',
        );
      }
    } catch (_) {}
  }

  Future<void> _mirrorCompletedPhotosToClientPortfolio(
    List<String> photos,
  ) async {
    if (photos.isEmpty) return;
    final clientEmail = widget.request.clientEmail.trim().toLowerCase();
    if (clientEmail.isEmpty) return;

    final clientRow = await _findUserRowByEmail(
      const <String>['client_artist', 'client'],
      clientEmail,
    );
    if (clientRow == null) return;
    final table = (clientRow['_table'] ?? '').toString().trim();
    final rowId = (clientRow['id'] ?? '').toString().trim();
    if (table.isEmpty || rowId.isEmpty) return;

    final cleaned = photos
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (cleaned.isEmpty) return;

    final nowIso = DateTime.now().toIso8601String();
    final itemMaps = cleaned
        .map(
          (url) => <String, dynamic>{
            'imageUrl': url,
            'url': url,
            'image': url,
            'style': 'All',
            'source': 'artist_completed_set',
            'requestId': widget.request.id,
            'createdAt': nowIso,
          },
        )
        .toList(growable: false);
    final portfolio = _asMap(clientRow['portfolio']);
    final client = _asMap(clientRow['client']);
    final clientPortfolio = _asMap(client['portfolio']);
    final nextPortfolioImages = _mergeUniqueList(
      _asList(_firstPresent(clientRow, 'portfolio_images', 'portfolioImages')),
      cleaned,
    );
    final nextPortfolioItems = _mergeUniqueList(
      _asList(_firstPresent(clientRow, 'portfolio_items', 'portfolioItems')),
      itemMaps,
    );
    await _supabase.from(table).update({
      'portfolio_images': nextPortfolioImages,
      'panel_portfolio_images': nextPortfolioImages,
      'panel_artist_portfolio_images': nextPortfolioImages,
      'portfolio_items': nextPortfolioItems,
      'portfolio': {
        ...portfolio,
        'images': _mergeUniqueList(_asList(portfolio['images']), cleaned),
        'items': _mergeUniqueList(_asList(portfolio['items']), itemMaps),
      },
      'client': {
        ...client,
        'portfolioImages': nextPortfolioImages,
        'portfolioItems': nextPortfolioItems,
        'portfolio': {
          ...clientPortfolio,
          'images': _mergeUniqueList(_asList(clientPortfolio['images']), cleaned),
          'items': _mergeUniqueList(_asList(clientPortfolio['items']), itemMaps),
        },
      },
      'updated_at': nowIso,
      'updatedAt': nowIso,
    }).eq('id', rowId);
  }

  Future<void> _mirrorCompletedPhotosToArtistPortfolio(
    List<String> photos,
  ) async {
    if (photos.isEmpty) return;
    final currentArtistId = _currentUserId();
    final artistEmail =
        (widget.request.acceptedByArtistEmail.trim().isNotEmpty
                ? widget.request.acceptedByArtistEmail
                : _currentUserEmail())
            .trim()
            .toLowerCase();
    Map<String, dynamic>? artistRow;
    if (currentArtistId.isNotEmpty) {
      artistRow = await _findUserRowById(
        const <String>['artist', 'client_artist'],
        currentArtistId,
      );
    }
    if (artistRow == null) {
      if (artistEmail.isEmpty) return;
      artistRow = await _findUserRowByEmail(
        const <String>['artist', 'client_artist'],
        artistEmail,
      );
    }
    if (artistRow == null) return;
    final table = (artistRow['_table'] ?? '').toString().trim();
    final rowId = (artistRow['id'] ?? '').toString().trim();
    if (table.isEmpty || rowId.isEmpty) return;

    final cleaned = photos
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (cleaned.isEmpty) return;

    final nowIso = DateTime.now().toIso8601String();
    final itemMaps = cleaned
        .map(
          (url) => <String, dynamic>{
            'imageUrl': url,
            'url': url,
            'image': url,
            'style': 'All',
            'source': 'artist_completed_set',
            'requestId': widget.request.id,
            'createdAt': nowIso,
          },
        )
        .toList(growable: false);
    final portfolio = _asMap(artistRow['portfolio']);
    final artist = _asMap(artistRow['artist']);
    final artistPortfolio = _asMap(artist['portfolio']);
    final nextPortfolioImages = _mergeUniqueList(
      _asList(_firstPresent(artistRow, 'portfolio_images', 'portfolioImages')),
      cleaned,
    );
    final nextPortfolioItems = _mergeUniqueList(
      _asList(_firstPresent(artistRow, 'portfolio_items', 'portfolioItems')),
      itemMaps,
    );
    debugPrint(
      'ARTIST PORTFOLIO MIRROR request=${widget.request.id} order=${widget.request.orderNumber} '
      'targetTable=$table targetRowId=$rowId currentArtistId=$currentArtistId '
      'photoCount=${cleaned.length}',
    );
    await _supabase.from(table).update({
      'portfolio_images': nextPortfolioImages,
      'panel_portfolio_images': nextPortfolioImages,
      'panel_artist_portfolio_images': nextPortfolioImages,
      'portfolio_items': nextPortfolioItems,
      'portfolio': {
        ...portfolio,
        'images': _mergeUniqueList(_asList(portfolio['images']), cleaned),
        'items': _mergeUniqueList(_asList(portfolio['items']), itemMaps),
      },
      'artist': {
        ...artist,
        'portfolioImages': nextPortfolioImages,
        'portfolioItems': nextPortfolioItems,
        'portfolio': {
          ...artistPortfolio,
          'images': _mergeUniqueList(_asList(artistPortfolio['images']), cleaned),
          'items': _mergeUniqueList(_asList(artistPortfolio['items']), itemMaps),
        },
      },
      'updated_at': nowIso,
      'updatedAt': nowIso,
    }).eq('id', rowId);
    debugPrint(
      'ARTIST PORTFOLIO MIRROR success request=${widget.request.id} order=${widget.request.orderNumber} '
      'targetTable=$table targetRowId=$rowId',
    );
  }

  Future<List<String>> _uploadArtistPhotos() async {
    return _uploadPhotosFor(
      photos: _artistPhotos,
      storageFolder: 'artist_completed_sets',
    );
  }

  Future<List<String>> _uploadPhotosFor({
    required List<XFile> photos,
    required String storageFolder,
  }) async {
    final refs = <String>[];
    final requestId = widget.request.id.trim().isEmpty
        ? 'request'
        : widget.request.id.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    var dataUriBudget = 900000;

    for (var i = 0; i < photos.length; i++) {
      final file = photos[i];
      final ext = _guessExt(file.path);
      final objectPath = '$requestId/$now-$i.$ext';
      final contentType = 'image/jpeg';

      String uploadedUrl = '';
      try {
        final originalBytes = await file.readAsBytes().timeout(
          const Duration(seconds: 20),
        );
        final bytes = _normalizeImageBytes(originalBytes);
        await _supabase.storage
            .from(storageFolder)
            .uploadBinary(
              objectPath,
              bytes,
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            )
            .timeout(const Duration(seconds: 20));
        uploadedUrl = _supabase.storage.from(storageFolder).getPublicUrl(objectPath);
      } catch (e) {
        debugPrint('[ArtistPhotoUpload] upload failed for ${file.name}: $e');
      }

      if (uploadedUrl.trim().isEmpty) {
        // Fallback: keep a compact data URI so completion does not block.
        try {
          final original = await file.readAsBytes().timeout(
            const Duration(seconds: 20),
          );
          final compact = _compactDataBytes(original);
          final dataUri = 'data:$contentType;base64,${base64Encode(compact)}';
          if (dataUri.length <= dataUriBudget) {
            uploadedUrl = dataUri;
            dataUriBudget -= dataUri.length;
            debugPrint(
              '[ArtistPhotoUpload] using data-uri fallback for ${file.name}',
            );
          }
        } catch (_) {}
      }

      if (uploadedUrl.trim().isNotEmpty) refs.add(uploadedUrl.trim());
    }
    return refs;
  }

  String _guessExt(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'png';
    if (p.endsWith('.jpeg')) return 'jpeg';
    if (p.endsWith('.jpg')) return 'jpg';
    return 'jpg';
  }

  Uint8List _normalizeImageBytes(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      img.Image output = decoded;
      const maxSide = 1080;
      if (decoded.width > maxSide || decoded.height > maxSide) {
        output = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxSide : null,
          height: decoded.height > decoded.width ? maxSide : null,
          maintainAspect: true,
          interpolation: img.Interpolation.linear,
        );
      }
      var encoded = img.encodeJpg(output, quality: 58);
      if (encoded.length > 850 * 1024) {
        final tighter = img.copyResize(
          output,
          width: output.width >= output.height ? 900 : null,
          height: output.height > output.width ? 900 : null,
          maintainAspect: true,
          interpolation: img.Interpolation.linear,
        );
        encoded = img.encodeJpg(tighter, quality: 48);
      }
      return Uint8List.fromList(encoded);
    } catch (_) {
      return bytes;
    }
  }

  Uint8List _compactDataBytes(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      img.Image output = decoded;
      const maxSide = 900;
      if (decoded.width > maxSide || decoded.height > maxSide) {
        output = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxSide : null,
          height: decoded.height > decoded.width ? maxSide : null,
          maintainAspect: true,
          interpolation: img.Interpolation.linear,
        );
      }
      final encoded = img.encodeJpg(output, quality: 45);
      return Uint8List.fromList(encoded);
    } catch (_) {
      return bytes;
    }
  }

  // -----------------------
  // UI helpers
  // -----------------------
  Widget _artistPhotosGrid() {
    return _localPhotosGrid(
      photos: _artistPhotos,
      onRemoveAt: (i) => setState(() => _artistPhotos.removeAt(i)),
    );
  }

  Widget _localPhotosGrid({
    required List<XFile> photos,
    required void Function(int index) onRemoveAt,
  }) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final x = photos[i];

          final imageWidget = kIsWeb
              ? Image.network(x.path, fit: BoxFit.cover)
              : Image.file(File(x.path), fit: BoxFit.cover);

          return SizedBox(
            width: 112,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: imageWidget,
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: InkWell(
                    onTap: () => onRemoveAt(i),
                    child: Container(
                      height: 26,
                      width: 26,
                      decoration: BoxDecoration(
                        color: AppColors.blackCat.withValues(alpha: 0.70),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
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

  static Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
  );

  Widget _finalAcceptedAmountBox(ClientRequestV2 r) {
    return _softBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Amount',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Final Amount by Artist:',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackCat.withValues(alpha: 0.80),
                ),
              ),
              const Spacer(),
              FutureBuilder<double?>(
                future: _loadAcceptedArtistAmount(),
                initialData: r.artistFinalAmount,
                builder: (context, snapshot) {
                  final amount = snapshot.data ?? r.artistFinalAmount;
                  return Text(
                    _formatMoneyAmount(amount),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blackCat,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Artist can start working immediately after acceptance.',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.blackCat.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentSectionBox(ClientRequestV2 r) {
    final paymentStatus = r.paymentStatus.trim().toLowerCase();
    final isPaid =
        _isDesigningMode ||
        paymentStatus == 'paid' ||
        paymentStatus == 'completed';
    final statusText = isPaid ? 'Paid' : 'Pending';
    final statusBg = AppColors.balletSlippers;
    final statusFg = AppColors.blackCat;
    final fallbackAmountText = r.artistFinalAmount != null
        ? _formatMoneyAmount(r.artistFinalAmount)
        : '\$${r.budgetMin} to \$${r.budgetMax}';

    return _softBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Amount:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.blackCat.withValues(alpha: 0.65),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.balletSlippers,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(
                    color: AppColors.blackCat.withValues(alpha: 0.05),
                  ),
                ),
                child: FutureBuilder<double?>(
                  future: _loadAcceptedArtistAmount(),
                  initialData: r.artistFinalAmount,
                  builder: (context, snapshot) {
                    final amount = snapshot.data ?? r.artistFinalAmount;
                    return Text(
                      amount != null && amount > 0
                          ? _formatMoneyAmount(amount)
                          : fallbackAmountText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blackCat,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Status:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.blackCat.withValues(alpha: 0.65),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(
                    color: AppColors.blackCat.withValues(alpha: 0.05),
                  ),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isPaid ? const Color(0xFFEAF7F2) : const Color(0xFFF8F8FB),
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: AppColors.blackCat.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isPaid ? Icons.check_circle_outline : Icons.info_outline,
                  size: 14,
                  color: isPaid
                      ? const Color(0xFF2E8B57)
                      : AppColors.blackCat.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isPaid
                        ? (_isDesigningMode
                              ? 'Continue designing and mark as completed when done.'
                              : 'You can now complete and ship this order.')
                        : 'Waiting for client payment. You will get a notification once payment is received.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                      color: AppColors.blackCat.withValues(alpha: 0.72),
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

  Widget _clientDeclineReasonSection(ClientRequestV2 r) {
    final raw = r.completionDeclineReason.trim();
    final reasons = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    String? otherReason;
    final primaryReasons = <String>[];
    for (final reason in reasons) {
      if (reason.toLowerCase().startsWith('other:')) {
        final detail = reason.substring('other:'.length).trim();
        if (detail.isNotEmpty) {
          otherReason = detail;
        }
      } else {
        primaryReasons.add(reason);
      }
    }
    final dateText = _dateText(r.completionDeclinedAt) ?? '—';

    return _softBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Decline Reason',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _kv(
            'Reason to decline',
            primaryReasons.isEmpty ? '—' : primaryReasons.join(', '),
          ),
          if (otherReason != null && otherReason.isNotEmpty)
            _kv('Other reason', otherReason),
          _kv('Date declined', dateText),
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

  static Widget _dimRow(String k, String v, {bool nfcRequested = false}) {
    String formatMm(String raw) {
      final value = raw.trim();
      if (value.isEmpty || value == '-') return '-';
      final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
      final parsed = double.tryParse(cleaned);
      if (parsed == null) return value;
      return '${parsed.toStringAsFixed(2)} mm';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: TextStyle(
                color: AppColors.blackCat.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ),
          if (nfcRequested) ...[_nfcDimensionChip(), const SizedBox(width: 6)],
          Text(
            formatMm(v),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  static Widget _handCardCentered(
    String title,
    NailDimensionsV2 d, {
    Map<String, bool> nfc = const <String, bool>{},
  }) {
    return _softBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(height: 10),
          _dimRow('Thumb', d.thumb, nfcRequested: nfc['thumb'] == true),
          _dimRow('Index', d.index, nfcRequested: nfc['index'] == true),
          _dimRow('Middle', d.middle, nfcRequested: nfc['middle'] == true),
          _dimRow('Ring', d.ring, nfcRequested: nfc['ring'] == true),
          _dimRow('Pinky', d.pinky, nfcRequested: nfc['pinky'] == true),
        ],
      ),
    );
  }

  static Widget _nfcDimensionChip() {
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

  static String _lengthLabel(String len) {
    final v = len.trim().toLowerCase();
    if (v == 'short') return 'Short';
    if (v == 'medium') return 'Medium';
    if (v == 'long') return 'Long';
    if (v == 'extra long' || v == 'xlong' || v == 'xl') return 'Extra Long';
    return len.trim();
  }

  GroupClientMeasurementData _requestMeasurementFallback() {
    return GroupClientMeasurementData(
      name: widget.request.clientName.trim().isEmpty
          ? 'Client'
          : widget.request.clientName.trim(),
      nailShape: widget.request.nailShape,
      nailLength: widget.request.nailLength,
      leftHand: _dimsMap(widget.request.leftHand),
      rightHand: _dimsMap(widget.request.rightHand),
    );
  }

  Future<GroupClientMeasurementData> _loadSubmittedMeasurementClient() async {
    String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
      for (final raw in values) {
        final text = (raw ?? '').toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
      return fallback;
    }

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

    try {
      final sourceMaps = <Map<String, dynamic>>[];

      final root = await _supabase
          .from(_requestTable)
          .select()
          .eq('id', widget.request.id)
          .maybeSingle();
      if (root != null) {
        final rootMap = Map<String, dynamic>.from((root as Map));
        sourceMaps.add(rootMap);
        sourceMaps.add(_asMap(rootMap['payload']));
        sourceMaps.add(_asMap(rootMap['data']));
        sourceMaps.add(
          _asMap(rootMap['requestDetails'] ?? rootMap['request_details']),
        );
        sourceMaps.add(
          _asMap(rootMap['order'] ?? rootMap['orderData'] ?? rootMap['order_data']),
        );
      }

      final detailRows = await _supabase
          .from(_requestDetailsTable)
          .select()
          .eq('request_id', widget.request.id);
      for (final row in detailRows) {
        final map = _asMap(row);
        sourceMaps.add(map);
        sourceMaps.add(_asMap(map['payload']));
        sourceMaps.add(_asMap(map['data']));
        sourceMaps.add(_asMap(map['details']));
        sourceMaps.add(_asMap(map['requestDetails'] ?? map['request_details']));
        sourceMaps.add(
          _asMap(map['order'] ?? map['orderData'] ?? map['order_data']),
        );
      }

      final nailSources = <Map<String, dynamic>>[];
      for (final source in sourceMaps) {
        final nail = _asMap(source['nailPreferences'] ?? source['nail_preferences']);
        if (nail.isNotEmpty) nailSources.add(nail);
      }

      final left = firstDims(<Object?>[
        ...nailSources,
        for (final source in sourceMaps) ...<Object?>[
          source['leftHandDimensions'],
          source['left_hand_dimensions'],
          source['dimensions'],
        ],
      ], left: true);

      final right = firstDims(<Object?>[
        ...nailSources,
        for (final source in sourceMaps) ...<Object?>[
          source['rightHandDimensions'],
          source['right_hand_dimensions'],
          source['dimensions'],
        ],
      ], left: false);

      final shape = firstNonEmpty(<Object?>[
        for (final source in nailSources) ...<Object?>[
          source['shape'],
          source['nailShape'],
          source['nail_shape'],
        ],
        for (final source in sourceMaps) ...<Object?>[
          source['nailShape'],
          source['nail_shape'],
        ],
        widget.request.nailShape,
      ], fallback: widget.request.nailShape);

      final length = firstNonEmpty(<Object?>[
        for (final source in nailSources) ...<Object?>[
          source['length'],
          source['nailLength'],
          source['nail_length'],
        ],
        for (final source in sourceMaps) ...<Object?>[
          source['nailLength'],
          source['nail_length'],
        ],
        widget.request.nailLength,
      ], fallback: widget.request.nailLength);

      final hasDims = left.values.any((v) => v.trim().isNotEmpty) ||
          right.values.any((v) => v.trim().isNotEmpty);
      if (!hasDims && shape.trim().isEmpty && length.trim().isEmpty) {
        return _requestMeasurementFallback();
      }

      final nfcDetails = await loadRequestNfcDetails(
        sourceCollection: widget.request.sourceCollection,
        requestId: widget.request.id,
      );
      final fallback = _requestMeasurementFallback();
      return GroupClientMeasurementData(
        name: widget.request.clientName.trim().isEmpty
            ? 'Client'
            : widget.request.clientName.trim(),
        clientEmail: widget.request.clientEmail,
        nailShape: shape,
        nailLength: length,
        leftHand: hasDims ? left : fallback.leftHand,
        rightHand: hasDims ? right : fallback.rightHand,
        leftNfc: nfcDetails.main.left,
        rightNfc: nfcDetails.main.right,
      );
    } catch (_) {
      return _requestMeasurementFallback();
    }
  }

  Widget _measurementSection() {
    final isGroup = widget.request.orderType == RequestOrderTypeV2.group;
    if (isGroup) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Client Measurements'),
          const SizedBox(height: 10),
          FutureBuilder<List<GroupClientMeasurementData>>(
            future: _loadGroupMeasurementClients(),
            builder: (context, snapshot) {
              final clients = snapshot.data ?? _buildGroupMeasurementClients();
              return _CompactGroupClientMeasurementsTabs(clients: clients);
            },
          ),
        ],
      );
    }

    return FutureBuilder<GroupClientMeasurementData>(
      future: _loadSubmittedMeasurementClient(),
      builder: (context, snapshot) {
        final client = snapshot.data ?? _requestMeasurementFallback();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Nail Dimensions',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        fontFamily: 'ArialBold',
                        color: AppColors.blackCat,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _handCardCentered(
                          'Left Hand',
                          _dimsObject(client.leftHand),
                          nfc: client.leftNfc,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _handCardCentered(
                          'Right Hand',
                          _dimsObject(client.rightHand),
                          nfc: client.rightNfc,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _softBox(
                          Row(
                            children: [
                              const Text(
                                'Shape',
                                style: TextStyle(
                                  color: AppColors.blackCat,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  fontFamily: 'Arial',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  client.nailShape.trim().isEmpty
                                      ? '-'
                                      : client.nailShape,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: AppColors.blackCat,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    fontFamily: 'ArialBold',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _softBox(
                          Row(
                            children: [
                              const Text(
                                'Length',
                                style: TextStyle(
                                  color: AppColors.blackCat,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  fontFamily: 'Arial',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _lengthLabel(client.nailLength).trim().isEmpty
                                      ? '-'
                                      : _lengthLabel(client.nailLength),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: AppColors.blackCat,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    fontFamily: 'ArialBold',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        );
      },
    );
  }


  Future<List<GroupClientMeasurementData>> _loadGroupMeasurementClients() async {
    final merged = <GroupClientMeasurementData>[];
    final seen = <String>{};
    final nfcDetails = await loadRequestNfcDetails(
      sourceCollection: widget.request.sourceCollection,
      requestId: widget.request.id,
    );

    void addClient(GroupClientMeasurementData client, {String email = '', String id = ''}) {
      final name = client.name.trim();
      final normalizedEmail = email.trim().toLowerCase();
      final normalizedId = id.trim().toLowerCase();
      final normalizedName = name.toLowerCase();

      // Prevent the submitted client from appearing twice when the migrated
      // group_clients JSON also contains that same person. We mark all known
      // identifiers for every added client, not just the first available key.
      final keys = <String>{
        if (normalizedEmail.isNotEmpty) 'email:$normalizedEmail',
        if (normalizedId.isNotEmpty) 'id:$normalizedId',
        if (normalizedName.isNotEmpty) 'name:$normalizedName',
      };
      if (keys.isEmpty) return;
      if (keys.any(seen.contains)) return;
      seen.addAll(keys);
      merged.add(client);
    }

    // The submitted client must always be the first tab. Added/group clients
    // are appended after this and deduped by email/id/name.
    final submittedClient = await _loadSubmittedMeasurementClient();
    addClient(
      GroupClientMeasurementData(
        name: submittedClient.name,
        clientEmail: widget.request.clientEmail,
        nailShape: submittedClient.nailShape,
        nailLength: submittedClient.nailLength,
        leftHand: submittedClient.leftHand,
        rightHand: submittedClient.rightHand,
        leftNfc: nfcDetails.main.left,
        rightNfc: nfcDetails.main.right,
      ),
      email: widget.request.clientEmail,
    );

    String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
      for (final raw in values) {
        final text = (raw ?? '').toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
      return fallback;
    }

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

    void addGroupClientFromMap(Map<String, dynamic> client, int index) {
      if (client.isEmpty) return;

      final email = firstNonEmpty(<Object?>[
        client['clientEmail'],
        client['client_email'],
        client['email'],
      ]).toLowerCase();
      final id = firstNonEmpty(<Object?>[
        client['clientId'],
        client['client_id'],
        client['id'],
        client['uid'],
      ]);
      final name = firstNonEmpty(<Object?>[
        client['clientName'],
        client['client_name'],
        client['name'],
        client['displayName'],
        client['display_name'],
      ], fallback: 'Client $index');

      final savedNails = _asMap(client['savedNails'] ?? client['saved_nails']);
      final draftNails = _asMap(client['draftNails'] ?? client['draft_nails']);
      final nailPreferences = _asMap(client['nailPreferences'] ?? client['nail_preferences']);
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
          nailShape: firstNonEmpty(<Object?>[
            client['nailShape'],
            client['nail_shape'],
            nailSource['shape'],
            nailSource['nailShape'],
            nailSource['nail_shape'],
          ], fallback: widget.request.nailShape),
          nailLength: firstNonEmpty(<Object?>[
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
      final payload = _asMap(source['payload']);
      final details = _asMap(source['details']);
      final data = _asMap(source['data']);
      final requestDetails = _asMap(source['requestDetails'] ?? source['request_details']);
      final orderData = _asMap(source['order'] ?? source['orderData'] ?? source['order_data']);

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
      if (root != null) {
        addGroupClientsFromSource(Map<String, dynamic>.from(root));
      }

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
      // Keep the sheet usable even if a migrated detail row is missing or RLS blocks it.
    }

    for (final client in _buildGroupMeasurementClients()) {
      addClient(client);
    }

    return merged.isEmpty ? _buildGroupMeasurementClients() : merged;
  }

  List<GroupClientMeasurementData> _buildGroupMeasurementClients() {
    final clients = <GroupClientMeasurementData>[
      _requestMeasurementFallback(),
    ];

    final seen = <String>{
      if (widget.request.clientName.trim().isNotEmpty)
        'name:${widget.request.clientName.trim().toLowerCase()}',
      if (widget.request.clientEmail.trim().isNotEmpty)
        'email:${widget.request.clientEmail.trim().toLowerCase()}',
    };
    for (final client in widget.request.groupClients) {
      final name = client.clientName.trim().isEmpty
          ? 'Client ${client.slotIndex}'
          : client.clientName.trim();
      final keys = <String>{
        if (client.clientId.trim().isNotEmpty)
          'id:${client.clientId.trim().toLowerCase()}',
        if (client.clientEmail.trim().isNotEmpty)
          'email:${client.clientEmail.trim().toLowerCase()}',
        if (name.trim().isNotEmpty) 'name:${name.trim().toLowerCase()}',
      };
      if (keys.isEmpty || keys.any(seen.contains)) continue;
      seen.addAll(keys);
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

  NailDimensionsV2 _dimsObject(Map<String, String> dims) {
    return NailDimensionsV2(
      thumb: dims['thumb'] ?? '',
      index: dims['index'] ?? '',
      middle: dims['middle'] ?? '',
      ring: dims['ring'] ?? '',
      pinky: dims['pinky'] ?? '',
    );
  }

  Widget _topHeader(ClientRequestV2 r, {required int shipDays}) {
    final isBrandRequest = _isBrandRequest(r);
    final headerName = isBrandRequest && r.brandName.trim().isNotEmpty
        ? r.brandName.trim()
        : r.clientName;
    final headerSubtitle = isBrandRequest ? r.title.trim() : '';
    final avatarPath = _heroPhotoSource(r);
    final avatarLetter = headerName.isEmpty ? '' : headerName[0].toUpperCase();

    Widget avatarFallback() => Container(
      height: 78,
      width: 78,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        color: AppColors.balletSlippers,
      ),
      alignment: Alignment.center,
      child: Text(
        avatarLetter,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
      ),
    );

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              FutureBuilder<String>(
                future: _resolvedHeroPhotoSource(r),
                builder: (_, snap) {
                  final resolved = (snap.data ?? avatarPath).trim();
                  if (resolved.isNotEmpty) {
                    return SizedBox(
                      height: 78,
                      width: 78,
                      child: ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: _clientImage(resolved),
                      ),
                    );
                  }
                  return avatarFallback();
                },
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
                'Order # ${r.orderNumber.trim().isNotEmpty ? r.orderNumber.trim() : r.id}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                  color: AppColors.blackCat.withValues(alpha: 0.60),
                ),
              ),
                  const SizedBox(height: 14),
                  _requestTypeOrderRow(r),
                  const SizedBox(height: 12),
                  Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _chipInfo(
                        icon: Icons.calendar_today_outlined,
                        text: 'Need by: ${_needByLabel(r.neededBy)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 18,
                    color: AppColors.blackCatBorderLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _chipInfo(
                        icon: Icons.attach_money_rounded,
                        text: 'Budget: \$${r.budgetMin} to \$${r.budgetMax}',
                      ),
                    ),
                  ),
                ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
        Positioned(
          right: 6,
          top: 6,
          child: InkWell(
            borderRadius: BorderRadius.zero,
            onTap: () => Navigator.pop(
              context,
              const _AcceptedSheetResult(
                completed: false,
                artistPhotos: <String>[],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.close_rounded,
                size: 22,
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
                        child: _clientImage(avatarPath),
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
      _normalizeImagePath(_heroPhotoSource(request)),
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
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _chipInfo(
              icon: r.isDirectRequest
                  ? Icons.arrow_outward_rounded
                  : Icons.arrow_forward_rounded,
              text: requestType,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 1,
          height: 18,
          color: AppColors.blackCatBorderLight,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _chipInfo(
              icon: r.orderType == RequestOrderTypeV2.group
                  ? Icons.groups_2_outlined
                  : Icons.person_outline_rounded,
              text: orderType,
            ),
          ),
        ),
      ],
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

  Widget _clientPhotosGrid(List<String> images) {
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
            child: InkWell(
              borderRadius: BorderRadius.zero,
              onTap: () => _openImagePreview(path),
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: _clientImage(path),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _clientImage(String path) {
    final p = _normalizeImagePath(path);
    Widget fallback() => Container(
      color: AppColors.blackCat.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.blackCat.withValues(alpha: 0.35),
      ),
    );
    final dataBytes = _decodeDataImageBytes(p);
    if (dataBytes != null && dataBytes.isNotEmpty) {
      return Image.memory(
        dataBytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    final isRemoteLike =
        p.startsWith('gs://') ||
        p.startsWith('http://') ||
        p.startsWith('https://') ||
        p.startsWith('blob:') ||
        p.startsWith('content://');

    if (isRemoteLike) {
      return FutureBuilder<String>(
        future: StorageUrlResolver.resolve(p).then((v) {
          final resolved = (v ?? '').trim();
          if (resolved.isNotEmpty) return resolved;
          if (p.startsWith('http://') || p.startsWith('https://')) return p;
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
    if (p.startsWith('assets/')) {
      return Image.asset(
        p,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    if (!kIsWeb &&
        (p.startsWith('/') || p.contains(':\\') || p.startsWith('file://'))) {
      final local = p.startsWith('file://') ? p.substring(7) : p;
      return Image.file(
        File(local),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    return FutureBuilder<String>(
      future: StorageUrlResolver.resolve(p).then((v) {
        final resolved = (v ?? '').trim();
        if (resolved.isNotEmpty) return resolved;
        if (p.startsWith('http://') || p.startsWith('https://')) return p;
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

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppColors.blackCat.withValues(alpha: 0.65),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _dateText(DateTime? date) {
    if (date == null) return null;
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
    return '${wds[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _normalizeImagePath(String raw) {
    var p = raw.trim();
    if (p.isEmpty) return p;
    for (var i = 0; i < 3; i++) {
      final decoded = Uri.decodeFull(p);
      if (decoded == p) break;
      p = decoded;
    }
    if (p.startsWith('gs%3A') ||
        p.startsWith('content%3A') ||
        p.startsWith('file%3A') ||
        p.startsWith('http%3A') ||
        p.startsWith('https%3A')) {
      p = Uri.decodeFull(p);
    }
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      if (rest.startsWith('http://') ||
          rest.startsWith('https://') ||
          rest.startsWith('gs://') ||
          rest.startsWith('blob:') ||
          rest.startsWith('data:') ||
          rest.startsWith('content://') ||
          rest.startsWith('file://')) {
        p = rest;
      }
    }
    return p;
  }

  Future<void> _openImagePreview(String path) async {
    final p = _normalizeImagePath(path);
    Widget image = _clientImage(p);
    if (p.startsWith('gs://')) {
      image = FutureBuilder<String>(
        future: StorageUrlResolver.resolve(p).then((v) {
          final resolved = (v ?? '').trim();
          if (resolved.isNotEmpty) return resolved;
          if (p.startsWith('http://') || p.startsWith('https://')) return p;
          return '';
        }),
        builder: (_, snap) {
          final url = (snap.data ?? '').trim();
          if (url.isEmpty) return const SizedBox.shrink();
          return Image.network(url, fit: BoxFit.contain);
        },
      );
    }
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(child: image),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.blackCat),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _CompactGroupClientMeasurementsTabs extends StatefulWidget {
  const _CompactGroupClientMeasurementsTabs({required this.clients});

  final List<GroupClientMeasurementData> clients;

  @override
  State<_CompactGroupClientMeasurementsTabs> createState() =>
      _CompactGroupClientMeasurementsTabsState();
}

class _CompactGroupClientMeasurementsTabsState
    extends State<_CompactGroupClientMeasurementsTabs> {
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(covariant _CompactGroupClientMeasurementsTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.clients.length) {
      _selectedIndex = 0;
    }
  }

  String _value(Object? value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '-';
    return text;
  }

  String _mm(Object? value) {
    final text = _value(value);
    if (text == '-') return '-';
    if (text.toLowerCase().contains('mm')) return text;
    return '$text mm';
  }

  String _dim(Map<String, String> dims, String key) => _mm(dims[key]);

  Widget _dimRow(String label, String value, {bool nfcRequested = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.blackCat.withValues(alpha: 0.74),
              ),
            ),
          ),
          if (nfcRequested) ...[_AcceptedRequestSheetState._nfcDimensionChip(), const SizedBox(width: 6)],
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat,
            ),
          ),
        ],
      ),
    );
  }

  Widget _handBox(
    String title,
    Map<String, String> dims, {
    Map<String, bool> nfc = const <String, bool>{},
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.blackCat,
            ),
          ),
          const SizedBox(height: 10),
          _dimRow('Thumb', _dim(dims, 'thumb'), nfcRequested: nfc['thumb'] == true),
          _dimRow('Index', _dim(dims, 'index'), nfcRequested: nfc['index'] == true),
          _dimRow('Middle', _dim(dims, 'middle'), nfcRequested: nfc['middle'] == true),
          _dimRow('Ring', _dim(dims, 'ring'), nfcRequested: nfc['ring'] == true),
          _dimRow('Pinky', _dim(dims, 'pinky'), nfcRequested: nfc['pinky'] == true),
        ],
      ),
    );
  }

  Widget _summaryBox(String label, String value) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _value(value),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.blackCat,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: widget.clients.length,
        separatorBuilder: (_, __) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final selected = index == _selectedIndex;
          final name = _value(widget.clients[index].name);
          return InkWell(
            borderRadius: BorderRadius.zero,
            onTap: () => setState(() => _selectedIndex = index),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: AppColors.blackCat.withValues(
                        alpha: selected ? 1 : 0.78,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Container(
                  height: 3,
                  width: 44,
                  color: selected ? AppColors.alabaster : Colors.transparent,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.22)),
        ),
        child: Text(
          'No client measurements found for this order.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.blackCat.withValues(alpha: 0.62),
          ),
        ),
      );
    }

    final client = widget.clients[_selectedIndex];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tabBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nail Dimensions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.blackCat,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _handBox(
                        'Left Hand',
                        client.leftHand,
                        nfc: client.leftNfc,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _handBox(
                        'Right Hand',
                        client.rightHand,
                        nfc: client.rightNfc,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _summaryBox('Shape', client.nailShape),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _summaryBox('Length', client.nailLength),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _AcceptedSheetMode { accepted, designing }

