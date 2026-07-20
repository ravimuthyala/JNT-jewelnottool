// lib/pages/artist_history_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/client_request_v2.dart';
import '../services/artist_requests_repository.dart';
import '../services/storage_url_resolver.dart';
import '../theme/app_colors.dart';
import 'artist_delivered_request_sheet.dart';
import 'artist_profile_page.dart';
import 'artist_reviews_page.dart';
import 'notifications_page.dart';
import 'simple_status_request_sheet.dart';
import '../widgets/artist_profile_avatar_icon.dart';
import '../widgets/jnt_standard_app_bar.dart';

class ArtistHistoryPage extends StatefulWidget {
  const ArtistHistoryPage({
    super.key,
    this.onBackHome,
    this.onOpenNotifications,
    this.onManageProfile,
    this.onOpenInbox,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onOpenReviews,
    this.onSignOut,
    this.showExtendedAvatarMenu = false,
    this.hideHistoryMenuItem = false,
    this.hideCalendarMenuItem = false,
    this.showBottomNav = false,
    this.bottomNavIndex = 4,
    this.onNavTap,
    this.bottomNavigationBar,
  });

  final VoidCallback? onBackHome;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onManageProfile;
  final VoidCallback? onOpenInbox;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final VoidCallback? onOpenReviews;
  final VoidCallback? onSignOut;
  final bool showExtendedAvatarMenu;
  final bool hideHistoryMenuItem;
  final bool hideCalendarMenuItem;
  final bool showBottomNav;
  final int bottomNavIndex;
  final ValueChanged<int>? onNavTap;
  final Widget? bottomNavigationBar;

  @override
  State<ArtistHistoryPage> createState() => _ArtistHistoryPageState();
}

class _ArtistHistoryPageState extends State<ArtistHistoryPage> {
  ArtistHistoryFilter _filter = ArtistHistoryFilter.all;
  bool _isLoadingDb = true;

  final List<ClientRequestV2> _all = <ClientRequestV2>[];
  final Set<String> _persistedArtistDeclinedRequestIds = <String>{};
  RealtimeChannel? _requestsChannel;

  @override
  void initState() {
    super.initState();
    _loadHistoryFromDb();
    _listenRealtime();
  }

  @override
  void dispose() {
    _requestsChannel?.unsubscribe();
    super.dispose();
  }

  void _listenRealtime() {
    _requestsChannel?.unsubscribe();
    _requestsChannel = Supabase.instance.client
        .channel('artist_history_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'client_custom_requests',
          callback: (_) => _loadHistoryFromDb(),
        )
        .subscribe((status, [error]) {
          if (error != null) {
            debugPrint('Artist history realtime error: $error');
          }
        });
  }


  bool _rowWasDeclinedByArtist(
    Map<String, dynamic> row,
    String artistEmail,
  ) {
    final email = artistEmail.trim().toLowerCase();
    if (email.isEmpty) return false;

    bool listContains(Object? raw) {
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim().toLowerCase())
            .contains(email);
      }
      if (raw is String) {
        return raw
            .split(',')
            .map((e) => e.trim().toLowerCase())
            .contains(email);
      }
      return false;
    }

    String text(Object? value) => (value ?? '').toString().trim().toLowerCase();
    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
      return const <String, dynamic>{};
    }

    final data = asMap(row['data']);
    final artistDecline = asMap(data['artistDecline']);
    final roleStatuses = asMap(data['roleStatuses']);

    if (listContains(row['declined_by_artist_emails']) ||
        listContains(data['declinedByArtistEmails']) ||
        listContains(data['declined_by_artist_emails'])) {
      return true;
    }

    final declinedBy = <String>[
      text(row['declined_by_artist_email']),
      text(data['declinedByArtistEmail']),
      text(data['declined_by_artist_email']),
      text(artistDecline['artistEmail']),
      text(artistDecline['artist_email']),
    ].where((e) => e.isNotEmpty).toSet();
    if (declinedBy.contains(email)) return true;

    final acceptedBy = text(row['accepted_by_artist_email']);
    final selectedArtist = text(row['selected_artist_email']);
    final selectedArtistData = text(data['selectedArtistEmail']);
    final assignedToCurrent = acceptedBy == email ||
        selectedArtist == email ||
        selectedArtistData == email;

    final rootStatusDeclined = text(row['status']) == 'declined' ||
        text(row['artist_status']) == 'declined' ||
        text(row['direct_artist_status']) == 'declined' ||
        text(row['artist_pool_status']) == 'declined';
    final dataStatusDeclined = text(data['status']) == 'declined' ||
        text(data['artistStatus']) == 'declined' ||
        text(data['artist_status']) == 'declined' ||
        text(data['directArtistStatus']) == 'declined' ||
        text(data['direct_artist_status']) == 'declined' ||
        text(roleStatuses['artist']) == 'declined';

    return assignedToCurrent && (rootStatusDeclined || dataStatusDeclined);
  }


  RequestStatusV2? _statusFromDbRow(Map<String, dynamic> row) {
    String norm(Object? value) =>
        (value ?? '').toString().trim().toLowerCase().replaceAll(' ', '_');
    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
      return const <String, dynamic>{};
    }

    final data = asMap(row['data']);
    final payload = asMap(row['payload']);
    final details = asMap(row['details']);
    final roleStatuses = asMap(data['roleStatuses']);
    final payloadRoleStatuses = asMap(payload['roleStatuses']);
    final detailRoleStatuses = asMap(details['roleStatuses']);

    final values = <String>[
      norm(row['artist_status']),
      norm(row['status']),
      norm(row['client_status']),
      norm(data['artistStatus']),
      norm(data['artist_status']),
      norm(data['status']),
      norm(roleStatuses['artist']),
      norm(payload['artistStatus']),
      norm(payload['artist_status']),
      norm(payload['status']),
      norm(payloadRoleStatuses['artist']),
      norm(details['artistStatus']),
      norm(details['artist_status']),
      norm(details['status']),
      norm(detailRoleStatuses['artist']),
    ].where((v) => v.isNotEmpty).toList(growable: false);

    bool has(String value) => values.contains(value);
    if (has('delivered')) return RequestStatusV2.delivered;
    if (has('declined')) return RequestStatusV2.declined;
    if (has('cancelled') || has('canceled')) return RequestStatusV2.cancelled;
    if (has('expired')) return RequestStatusV2.expired;
    if (has('shipped')) return RequestStatusV2.shipped;
    if (has('completed') || has('complete')) return RequestStatusV2.completed;
    if (has('designing') || has('in_progress') || has('inprogress')) {
      return RequestStatusV2.designing;
    }
    if (has('accepted')) return RequestStatusV2.accepted;
    if (has('in_review') || has('inreview') || has('pending')) {
      return RequestStatusV2.inReview;
    }
    return null;
  }

  DateTime? _dateFromDbValue(Object? value) {
    if (value is DateTime) return value;
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  Future<List<ClientRequestV2>> _applyRootHistoryStatusOverrides(
    List<ClientRequestV2> requests,
  ) async {
    if (requests.isEmpty) return requests;

    final byId = <String, Map<String, dynamic>>{};
    final byOrder = <String, Map<String, dynamic>>{};

    void addRow(Map<String, dynamic> row) {
      final status = _statusFromDbRow(row);
      if (status == null) return;
      final id = (row['id'] ?? '').toString().trim();
      final orderNumber = (row['order_number'] ?? '').toString().trim();
      final requestNumber = (row['request_number'] ?? '').toString().trim();
      final info = <String, dynamic>{'status': status, 'row': row};
      if (id.isNotEmpty) byId[id] = info;
      if (orderNumber.isNotEmpty) byOrder[orderNumber] = info;
      if (requestNumber.isNotEmpty) byOrder[requestNumber] = info;
    }

    Future<void> scan(String table) async {
      try {
        final rows = await Supabase.instance.client
            .from(table)
            .select()
            .order('updated_at', ascending: false)
            .limit(1000);
        for (final raw in rows.whereType<Map>()) {
          addRow(Map<String, dynamic>.from(raw));
        }
      } catch (_) {}
    }

    await scan('client_custom_requests');
    await scan('company_custom_requests');

    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return const <String, dynamic>{};
    }

    String firstText(List<dynamic> values) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
      return '';
    }

    List<String> collectPhotos(List<dynamic> values) {
      final out = <String>[];
      final seen = <String>{};
      void addValue(dynamic value) {
        if (value == null) return;
        if (value is String) {
          final text = value.trim();
          if (text.isNotEmpty && text.toLowerCase() != 'null' && seen.add(text)) {
            out.add(text);
          }
          return;
        }
        if (value is Iterable) {
          for (final item in value) {
            addValue(item);
          }
          return;
        }
        if (value is Map) {
          final map = asMap(value);
          for (final key in const <String>[
            'url',
            'downloadUrl',
            'downloadURL',
            'photoUrl',
            'imageUrl',
            'image',
            'path',
            'storagePath',
            'fullPath',
            'ref',
            'photo',
            'src',
            'uri',
          ]) {
            if (map.containsKey(key)) addValue(map[key]);
          }
        }
      }

      for (final value in values) {
        addValue(value);
      }
      return out;
    }

    return requests.map((request) {
      final info = byId[request.id] ?? byOrder[request.orderNumber];
      if (info == null) return request;
      final status = info['status'] as RequestStatusV2?;
      if (status == null) return request;
      final row =
          (info['row'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      final payload = asMap(row['payload']);
      final details = asMap(row['details']);
      final requestDetails = asMap(
        payload['requestDetails'] ?? row['requestDetails'] ?? row['request_details'],
      );
      final orderData = asMap(payload['order'] ?? payload['orderData'] ?? row['order']);
      final snapshot = asMap(details['clientProfileSnapshot'] ?? payload['clientProfileSnapshot']);
      final snapshotBasic = asMap(snapshot['basic']);
      final snapshotProfile = asMap(snapshot['profile']);
      final acceptedClient = asMap(
        row['acceptedClient'] ??
            details['acceptedClient'] ??
            payload['acceptedClient'] ??
            orderData['acceptedClient'],
      );
      final deliveredAt = _dateFromDbValue(
            row['delivered_at'] ??
                row['order_delivered_at'] ??
                row['deliveredAt'] ??
                row['orderDeliveredAt'],
          ) ??
          request.deliveredAt;
      final shippedAt = _dateFromDbValue(
            row['shipped_at'] ??
                row['artist_shipped_at'] ??
                row['order_shipped_at'] ??
                row['shippedAt'],
          ) ??
          request.shippedAt;
      final clientProfileImage = firstText([
        row['clientProfileImage'],
        row['clientProfilePic'],
        row['clientProfilePhoto'],
        row['clientAvatar'],
        row['clientAvatarUrl'],
        row['companyProfileImage'],
        row['brandProfileImage'],
        row['companyLogoUrl'],
        row['brandLogoUrl'],
        row['client_profile_image'],
        row['profileImageUrl'],
        row['profile_image_url'],
        row['profile_picture_url'],
        row['photoUrl'],
        row['photo_url'],
        row['avatarUrl'],
        row['avatar_url'],
        payload['clientProfileImage'],
        payload['clientProfilePic'],
        payload['clientProfilePhoto'],
        payload['clientAvatar'],
        payload['clientAvatarUrl'],
        payload['client_profile_image'],
        payload['profileImageUrl'],
        payload['profile_image_url'],
        payload['profile_picture_url'],
        payload['photoUrl'],
        payload['photo_url'],
        payload['avatarUrl'],
        payload['avatar_url'],
        details['clientProfileImage'],
        details['clientProfilePic'],
        details['clientProfilePhoto'],
        details['clientAvatar'],
        details['clientAvatarUrl'],
        details['client_profile_image'],
        details['profileImageUrl'],
        details['profile_image_url'],
        details['profile_picture_url'],
        details['photoUrl'],
        details['photo_url'],
        details['avatarUrl'],
        details['avatar_url'],
        snapshot['profileImageUrl'],
        snapshot['profile_image_url'],
        snapshot['profile_picture_url'],
        snapshot['photoUrl'],
        snapshot['photo_url'],
        snapshot['avatarUrl'],
        snapshot['avatar_url'],
        snapshotBasic['profileImagePath'],
        snapshotBasic['profileImageUrl'],
        snapshotBasic['profile_image_url'],
        snapshotBasic['profile_picture_url'],
        snapshotBasic['photoUrl'],
        snapshotBasic['photo_url'],
        snapshotBasic['avatarUrl'],
        snapshotBasic['avatar_url'],
        snapshotProfile['profileImageUrl'],
        snapshotProfile['profile_image_url'],
        snapshotProfile['profile_picture_url'],
        snapshotProfile['photoUrl'],
        snapshotProfile['photo_url'],
        snapshotProfile['avatarUrl'],
        snapshotProfile['avatar_url'],
        requestDetails['clientProfileImage'],
        requestDetails['clientProfilePic'],
        requestDetails['clientAvatarUrl'],
        requestDetails['profileImageUrl'],
        requestDetails['profileImagePath'],
      ]);
      final acceptedClientProfileImage = firstText([
        row['acceptedClientProfileImage'],
        row['accepted_client_profile_image'],
        details['acceptedClientProfileImage'],
        payload['acceptedClientProfileImage'],
        acceptedClient['profileImageUrl'],
        acceptedClient['profile_image_url'],
        acceptedClient['avatarUrl'],
        acceptedClient['avatar_url'],
      ]);
      final clientImages = collectPhotos([
        row['clientImages'],
        row['client_images'],
        row['photos'],
        row['images'],
        row['uploadedPhotos'],
        row['uploaded_photos'],
        row['inspirationPhotos'],
        row['inspiration_photos'],
        row['brandInspirationPhotos'],
        row['brand_inspiration_photos'],
        row['previewImage'],
        row['preview_image'],
        row['previewImageAsset'],
        row['preview_image_asset'],
        payload['clientImages'],
        payload['client_images'],
        payload['photos'],
        payload['images'],
        payload['uploadedPhotos'],
        payload['uploaded_photos'],
        payload['inspirationPhotos'],
        payload['inspiration_photos'],
        payload['brandInspirationPhotos'],
        payload['brand_inspiration_photos'],
        payload['previewImage'],
        payload['preview_image'],
        payload['previewImageAsset'],
        payload['preview_image_asset'],
        details['clientImages'],
        details['client_images'],
        details['photos'],
        details['images'],
        details['uploadedPhotos'],
        details['uploaded_photos'],
        details['inspirationPhotos'],
        details['inspiration_photos'],
        details['brandInspirationPhotos'],
        details['brand_inspiration_photos'],
        details['previewImage'],
        details['preview_image'],
        details['previewImageAsset'],
        details['preview_image_asset'],
        requestDetails['clientImages'],
        requestDetails['client_images'],
        requestDetails['photos'],
        requestDetails['images'],
        requestDetails['uploadedPhotos'],
        requestDetails['uploaded_photos'],
        requestDetails['inspirationPhotos'],
        requestDetails['inspiration_photos'],
        requestDetails['brandInspirationPhotos'],
        requestDetails['brand_inspiration_photos'],
        requestDetails['previewImage'],
        requestDetails['preview_image'],
        requestDetails['previewImageAsset'],
        requestDetails['preview_image_asset'],
        orderData['clientImages'],
        orderData['client_images'],
        orderData['photos'],
        orderData['images'],
        orderData['uploadedPhotos'],
        orderData['uploaded_photos'],
        orderData['inspirationPhotos'],
        orderData['inspiration_photos'],
        orderData['brandInspirationPhotos'],
        orderData['brand_inspiration_photos'],
        orderData['previewImage'],
        orderData['preview_image'],
        orderData['previewImageAsset'],
        orderData['preview_image_asset'],
      ]);
      final artistImages = collectPhotos([
        row['artistImages'],
        row['artist_images'],
        row['completedPhotos'],
        row['completed_photos'],
        row['artistCompletedPhotos'],
        row['artist_completed_photos'],
        row['designPreviewPhotos'],
        row['design_preview_photos'],
        row['uploadedPhotosArtist'],
        row['uploaded_photos_artist'],
        payload['artistImages'],
        payload['artist_images'],
        payload['completedPhotos'],
        payload['artistCompletedPhotos'],
        payload['designPreviewPhotos'],
        payload['design_preview_photos'],
        payload['uploadedPhotosArtist'],
        payload['uploaded_photos_artist'],
        details['artistImages'],
        details['artist_images'],
        details['completedPhotos'],
        details['artistCompletedPhotos'],
        details['designPreviewPhotos'],
        details['design_preview_photos'],
        details['uploadedPhotosArtist'],
        details['uploaded_photos_artist'],
        orderData['artistImages'],
        orderData['artist_images'],
        orderData['completedPhotos'],
        orderData['artistCompletedPhotos'],
        orderData['designPreviewPhotos'],
        orderData['design_preview_photos'],
        orderData['uploadedPhotosArtist'],
        orderData['uploaded_photos_artist'],
      ]);
      final deliveredBio = firstText([
        row['bio'],
        row['description'],
        details['bio'],
        details['description'],
        payload['bio'],
        payload['description'],
        requestDetails['bio'],
        requestDetails['description'],
      ]);
      final shippedByCourier = firstText([
        row['shipped_by_courier'],
        row['shippedByCourier'],
        row['shipping_label_carrier'],
        row['shippingLabelCarrier'],
        details['shippedByCourier'],
        details['shippingLabelCarrier'],
        payload['shippedByCourier'],
        payload['shippingLabelCarrier'],
      ]);
      final trackingNumber = firstText([
        row['tracking_number'],
        row['trackingNumber'],
        row['shipping_label_tracking_number'],
        row['shippingLabelTrackingNumber'],
        details['trackingNumber'],
        details['shippingLabelTrackingNumber'],
        payload['trackingNumber'],
        payload['shippingLabelTrackingNumber'],
      ]);
      final brandName = firstText([
        row['brandName'],
        row['brand_name'],
        details['brandName'],
        payload['brandName'],
        orderData['brandName'],
      ]);
      return request.copyWith(
        status: status,
        deliveredAt: deliveredAt,
        shippedAt: shippedAt,
        clientProfileImage: clientProfileImage.isNotEmpty
            ? clientProfileImage
            : request.clientProfileImage,
        acceptedClientProfileImage: acceptedClientProfileImage.isNotEmpty
            ? acceptedClientProfileImage
            : request.acceptedClientProfileImage,
        clientImages: clientImages.isNotEmpty ? clientImages : request.clientImages,
        artistImages: artistImages.isNotEmpty ? artistImages : request.artistImages,
        bio: deliveredBio.isNotEmpty ? deliveredBio : request.bio,
        shippedByCourier: shippedByCourier.isNotEmpty
            ? shippedByCourier
            : request.shippedByCourier,
        trackingNumber: trackingNumber.isNotEmpty
            ? trackingNumber
            : request.trackingNumber,
        brandName: brandName.isNotEmpty ? brandName : request.brandName,
      );
    }).toList(growable: false);
  }

  Future<Set<String>> _fetchPersistedArtistDeclinedRequestIds(
    String artistEmail,
  ) async {
    final email = artistEmail.trim().toLowerCase();
    if (email.isEmpty) return <String>{};
    final ids = <String>{};

    Future<void> scanTable(String table) async {
      try {
        final rows = await Supabase.instance.client
            .from(table)
            .select('id,status,artist_status,direct_artist_status,artist_pool_status,accepted_by_artist_email,selected_artist_email,declined_by_artist_email,declined_by_artist_emails,data,updated_at')
            .order('updated_at', ascending: false)
            .limit(1000);
        for (final raw in rows.whereType<Map>()) {
          final row = Map<String, dynamic>.from(raw);
          final id = (row['id'] ?? '').toString().trim();
          if (id.isEmpty) continue;
          if (_rowWasDeclinedByArtist(row, email)) ids.add(id);
        }
      } catch (_) {
        try {
          final rows = await Supabase.instance.client
              .from(table)
              .select('id,status,artist_status,accepted_by_artist_email,selected_artist_email,data,updated_at')
              .order('updated_at', ascending: false)
              .limit(1000);
          for (final raw in rows.whereType<Map>()) {
            final row = Map<String, dynamic>.from(raw);
            final id = (row['id'] ?? '').toString().trim();
            if (id.isEmpty) continue;
            if (_rowWasDeclinedByArtist(row, email)) ids.add(id);
          }
        } catch (_) {}
      }
    }

    await scanTable('client_custom_requests');
    await scanTable('company_custom_requests');
    return ids;
  }

  Future<void> _loadHistoryFromDb() async {
    try {
      final fetchedRequests = await ArtistRequestsRepository.fetchAllRequests();
      final allRequests = await _applyRootHistoryStatusOverrides(fetchedRequests);
      final currentArtistEmail =
          (Supabase.instance.client.auth.currentUser?.email ?? '').trim().toLowerCase();
      final persistedDeclinedIds = await _fetchPersistedArtistDeclinedRequestIds(
        currentArtistEmail,
      );
      unawaited(
        _syncArtistRatingFromReviews(
          allRequests,
          artistEmail: currentArtistEmail,
        ),
      );
      if (!mounted) return;

      setState(() {
        _persistedArtistDeclinedRequestIds
          ..clear()
          ..addAll(persistedDeclinedIds);
        _all
          ..clear()
          ..addAll(
            allRequests.where(
              (r) =>
                  _isHistoryStatus(r, currentArtistEmail) &&
                  _isVisibleToArtist(
                    request: r,
                    artistEmail: currentArtistEmail,
                  ),
            ),
          );
        _all.sort(
          (a, b) =>
              _historyDateForStatus(b).compareTo(_historyDateForStatus(a)),
        );
        _isLoadingDb = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingDb = false);
    }
  }

  Future<void> _syncArtistRatingFromReviews(
    List<ClientRequestV2> allRequests, {
    required String artistEmail,
  }) async {
    final reviewedDelivered = allRequests
        .where((r) {
          if (r.status != RequestStatusV2.delivered) return false;
          final rating = r.clientRating ?? 0;
          if (rating <= 0) return false;
          return _isVisibleToArtist(request: r, artistEmail: artistEmail);
        })
        .toList(growable: false);

    if (reviewedDelivered.isEmpty) return;

    final highestRating = reviewedDelivered
        .map((r) => r.clientRating ?? 0)
        .fold<double>(0, (max, value) => value > max ? value : max)
        .clamp(0, 5);
    final reviewCount = reviewedDelivered.length;

    final supabase = Supabase.instance.client;
    final uid = (supabase.auth.currentUser?.id ?? '').trim();
    final email =
        (supabase.auth.currentUser?.email ?? '').trim().toLowerCase();
    if (uid.isEmpty && email.isEmpty) return;

    Map<String, dynamic>? artistRow;
    String? artistTable;
    for (final table in const <String>['artist', 'client_artist']) {
      try {
        Map<String, dynamic>? row;
        if (uid.isNotEmpty) {
          row = await supabase
              .from(table)
              .select('id, email, display_name, name, profile')
              .eq('id', uid)
              .maybeSingle();
        }
        if (row == null && email.isNotEmpty) {
          row = await supabase
              .from(table)
              .select('id, email, display_name, name, profile')
              .eq('email', email)
              .maybeSingle();
        }
        if (row != null) {
          artistRow = row;
          artistTable = table;
          break;
        }
      } catch (_) {}
    }

    if (artistRow == null || artistTable == null) return;

    final rowId = (artistRow['id'] ?? '').toString().trim();
    if (rowId.isEmpty) return;

    final existingProfile =
        (artistRow['profile'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final existingStats =
        (existingProfile['stats'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final existingRating =
        ((existingStats['rating'] ??
                    existingProfile['rating'] ??
                    artistRow['rating'])
                as num?)
            ?.toDouble() ??
        0;
    final existingCount =
        ((existingStats['reviewCount'] ??
                    existingStats['reviews'] ??
                    existingProfile['reviewCount'])
                as num?)
            ?.toInt() ??
        0;
    final ratingUnchanged = (existingRating - highestRating).abs() < 0.0001;
    if (ratingUnchanged && existingCount == reviewCount) return;

    final updatedProfile = <String, dynamic>{
      ...existingProfile,
      'stats': <String, dynamic>{
        ...existingStats,
        'rating': highestRating,
        'averageRating': highestRating,
        'reviewCount': reviewCount,
        'reviews': reviewCount,
      },
      'rating': highestRating,
      'averageRating': highestRating,
      'reviewCount': reviewCount,
      'reviews': reviewCount,
    };

    try {
      await supabase
          .from(artistTable)
          .update({
            'profile': updatedProfile,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', rowId);
    } catch (e) {
      debugPrint('_syncArtistRatingFromReviews Supabase update failed: $e');
    }
  }

  bool _isArtistDeclinedForHistory(
    ClientRequestV2 request,
    String artistEmail,
  ) {
    if (artistEmail.isEmpty) return false;
    final normalizedEmail = artistEmail.trim().toLowerCase();
    final artistDeclined = request.declinedByArtistEmails
        .map((e) => e.trim().toLowerCase())
        .contains(normalizedEmail);
    if (_persistedArtistDeclinedRequestIds.contains(request.id)) return true;
    if (!artistDeclined) return false;
    return request.status == RequestStatusV2.inReview ||
        request.status == RequestStatusV2.cancelled ||
        request.status == RequestStatusV2.declined;
  }

  bool _isHistoryStatus(ClientRequestV2 request, String artistEmail) {
    return request.status == RequestStatusV2.delivered ||
        request.status == RequestStatusV2.declined ||
        request.status == RequestStatusV2.expired ||
        request.status == RequestStatusV2.cancelled ||
        _isArtistDeclinedForHistory(request, artistEmail);
  }

  bool _isVisibleToArtist({
    required ClientRequestV2 request,
    required String artistEmail,
  }) {
    final ownedBy = request.acceptedByArtistEmail.trim().toLowerCase();
    final selectedBy = request.selectedArtistEmail.trim().toLowerCase();
    final resolvedOwner = ownedBy.isNotEmpty ? ownedBy : selectedBy;
    final isOwnedByCurrentArtist =
        artistEmail.isNotEmpty && resolvedOwner == artistEmail;
    if (_isArtistDeclinedForHistory(request, artistEmail)) {
      return true;
    }
    return resolvedOwner.isEmpty || isOwnedByCurrentArtist;
  }

  DateTime _historyDateForStatus(ClientRequestV2 r) {
    switch (r.status) {
      case RequestStatusV2.delivered:
        return r.deliveredAt ?? r.shippedAt ?? r.neededBy;
      case RequestStatusV2.declined:
        return r.completionDeclinedAt ?? r.neededBy;
      case RequestStatusV2.expired:
      case RequestStatusV2.cancelled:
      default:
        return r.neededBy;
    }
  }

  String _statusTextForHistory(ClientRequestV2 r) {
    final d = _historyDateForStatus(r);
    final currentArtistEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (_isArtistDeclinedForHistory(r, currentArtistEmail)) {
      return 'Declined ${_monthShort(d.month)} ${d.day}';
    }
    switch (r.status) {
      case RequestStatusV2.delivered:
        return 'Delivered ${_monthShort(d.month)} ${d.day}';
      case RequestStatusV2.declined:
        return 'Declined ${_monthShort(d.month)} ${d.day}';
      case RequestStatusV2.expired:
        return 'Expired ${_monthShort(d.month)} ${d.day}';
      case RequestStatusV2.cancelled:
        return 'Cancelled ${_monthShort(d.month)} ${d.day}';
      default:
        return r.status.label;
    }
  }

  ArtistOrderLiteStatus _toLiteStatus(RequestStatusV2 s) {
    switch (s) {
      case RequestStatusV2.delivered:
        return ArtistOrderLiteStatus.delivered;
      case RequestStatusV2.declined:
        return ArtistOrderLiteStatus.declined;
      case RequestStatusV2.expired:
        return ArtistOrderLiteStatus.expired;
      case RequestStatusV2.cancelled:
      default:
        return ArtistOrderLiteStatus.cancelled;
    }
  }

  ArtistOrderLiteStatus _historyLiteStatus(ClientRequestV2 r) {
    final currentArtistEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (_isArtistDeclinedForHistory(r, currentArtistEmail)) {
      return ArtistOrderLiteStatus.declined;
    }
    return _toLiteStatus(r.status);
  }

  String _pickCardImage(ClientRequestV2 r) {
    String clean(String value) {
      final v = value.trim();
      if (v.isEmpty) return '';
      final lower = v.toLowerCase();
      if (lower == 'null' || lower == 'none' || lower == '-') return '';
      return v;
    }

    final accepted = clean(r.acceptedClientProfileImage);
    if (accepted.isNotEmpty) return accepted;

    final client = clean(r.clientProfileImage);
    if (client.isNotEmpty) return client;

    return '';
  }

  String _historyReasonForStatus(ClientRequestV2 r) {
    final currentArtistEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (_isArtistDeclinedForHistory(r, currentArtistEmail)) {
      final reason = r.declineReason.trim().isNotEmpty
          ? r.declineReason.trim()
          : r.completionDeclineReason.trim();
      return reason.isNotEmpty ? reason : 'Declined by artist';
    }
    switch (r.status) {
      case RequestStatusV2.declined:
        final reason = r.declineReason.trim().isNotEmpty
            ? r.declineReason.trim()
            : r.completionDeclineReason.trim();
        return reason.isNotEmpty ? reason : 'Declined by artist';
      case RequestStatusV2.cancelled:
        final reason = r.cancelReason.trim();
        return reason.isNotEmpty ? reason : 'Cancelled by user';
      case RequestStatusV2.expired:
        return 'Request expired';
      default:
        return r.title;
    }
  }

  List<ArtistOrderLite> get _historyItems {
    return _all
        .map(
          (r) => ArtistOrderLite(
            id: r.id,
            clientName: _isBrandRequest(r)
                ? (r.brandName.trim().isNotEmpty
                      ? r.brandName.trim()
                      : r.clientName)
                : r.clientName,
            clientEmail: r.clientEmail,
            title: r.title,
            subtitle: _isBrandRequest(r) ? r.title : _historyReasonForStatus(r),
            isBrandRequest: _isBrandRequest(r),
            status: _historyLiteStatus(r),
            statusText: _statusTextForHistory(r),
            imageAsset: _pickCardImage(r),
            budgetMin: r.budgetMin,
            budgetMax: r.budgetMax,
            carrier: r.shippedByCourier,
            shippedAt: r.shippedAt,
            deliveredAt: r.deliveredAt,
            clientPhotos: const [],
            artistPhotos: const [],
          ),
        )
        .toList(growable: false);
  }

  bool _isBrandRequest(ClientRequestV2 r) {
    final source = r.sourceCollection.trim();
    final orderNo = r.orderNumber.trim().toUpperCase();
    return source == 'Company_Custom_Requests' ||
        orderNo.startsWith('BE-') ||
        orderNo.startsWith('BR-');
  }

  List<ClientRequestV2> get _filteredRequests {
    switch (_filter) {
      case ArtistHistoryFilter.all:
        return _all;
      case ArtistHistoryFilter.delivered:
        return _all
            .where((r) => r.status == RequestStatusV2.delivered)
            .toList(growable: false);
      case ArtistHistoryFilter.declined:
        return _all
            .where((r) {
              final currentArtistEmail =
                  (Supabase.instance.client.auth.currentUser?.email ?? '')
                      .trim()
                      .toLowerCase();
              return r.status == RequestStatusV2.declined ||
                  _isArtistDeclinedForHistory(r, currentArtistEmail);
            })
            .toList(growable: false);
      case ArtistHistoryFilter.expired:
        return _all
            .where((r) => r.status == RequestStatusV2.expired)
            .toList(growable: false);
      case ArtistHistoryFilter.cancelled:
        return _all
            .where((r) => r.status == RequestStatusV2.cancelled)
            .toList(growable: false);
    }
  }

  int _countForFilter(ArtistHistoryFilter filter) {
    final currentArtistEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    switch (filter) {
      case ArtistHistoryFilter.all:
        return _all.length;
      case ArtistHistoryFilter.delivered:
        return _all.where((r) => r.status == RequestStatusV2.delivered).length;
      case ArtistHistoryFilter.declined:
        return _all
            .where(
              (r) =>
                  r.status == RequestStatusV2.declined ||
                  _isArtistDeclinedForHistory(r, currentArtistEmail),
            )
            .length;
      case ArtistHistoryFilter.expired:
        return _all.where((r) => r.status == RequestStatusV2.expired).length;
      case ArtistHistoryFilter.cancelled:
        return _all.where((r) => r.status == RequestStatusV2.cancelled).length;
    }
  }

  Future<void> _openHistoryPopup(
    BuildContext context,
    ClientRequestV2 request,
  ) async {
    final currentArtistEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (_isArtistDeclinedForHistory(request, currentArtistEmail)) {
      await showSimpleStatusRequestSheet(
        context: context,
        request: request,
        status: SimpleRequestStatus.declined,
        date: _historyDateForStatus(request),
      );
      return;
    }

    if (request.status == RequestStatusV2.delivered) {
      await showDeliveredRequestSheet(context: context, request: request);
      return;
    }

    late final SimpleRequestStatus simpleStatus;
    switch (request.status) {
      case RequestStatusV2.declined:
        simpleStatus = SimpleRequestStatus.declined;
        break;
      case RequestStatusV2.expired:
        simpleStatus = SimpleRequestStatus.expired;
        break;
      case RequestStatusV2.cancelled:
      default:
        simpleStatus = SimpleRequestStatus.cancelled;
        break;
    }

    await showSimpleStatusRequestSheet(
      context: context,
      request: request,
      status: simpleStatus,
      date: _historyDateForStatus(request),
    );
  }

  void _openNotifications() {
    if (widget.onOpenNotifications != null) {
      widget.onOpenNotifications!.call();
      return;
    }
    NotificationsPage.showAsModal(context);
  }

  void _openManageProfile() {
    if (widget.onManageProfile != null) {
      widget.onManageProfile!.call();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ArtistProfilePage(showBottomNav: true, bottomNavIndex: 3),
      ),
    );
  }

  Future<void> _signOut() async {
    if (widget.onSignOut != null) {
      widget.onSignOut!.call();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _openHistoryFromMenu() {
    widget.onOpenHistory?.call();
  }

  void _openCalendarFromMenu() {
    widget.onOpenCalendar?.call();
  }

  void _openArtistFromMenu() {
    widget.onOpenArtist?.call();
  }

  void _openReviewsFromMenu() {
    if (widget.onOpenReviews != null) {
      widget.onOpenReviews!.call();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArtistReviewsPage()),
    );
  }

  Widget _avatarMenu() {
    return PopupMenuButton<_HeaderAvatarAction>(
      tooltip: '',
      position: PopupMenuPosition.under,
      elevation: 12,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      onSelected: (v) {
        switch (v) {
          case _HeaderAvatarAction.profile:
            _openManageProfile();
            break;
          case _HeaderAvatarAction.history:
            _openHistoryFromMenu();
            break;
          case _HeaderAvatarAction.calendar:
            _openCalendarFromMenu();
            break;
          case _HeaderAvatarAction.artist:
            _openArtistFromMenu();
            break;
          case _HeaderAvatarAction.reviews:
            _openReviewsFromMenu();
            break;
          case _HeaderAvatarAction.signOut:
            _signOut();
            break;
        }
      },
      child: SizedBox(
        height: JntHeaderMetrics.avatarSize,
        width: JntHeaderMetrics.avatarSize,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: const ArtistProfileAvatarIcon(size: JntHeaderMetrics.avatarSize),
        ),
      ),
      itemBuilder: (_) {
        if (!widget.showExtendedAvatarMenu) {
          return [
            if (widget.onOpenReviews != null)
              const PopupMenuItem(
                value: _HeaderAvatarAction.reviews,
                child: _HeaderMenuRow(
                  icon: Icons.star_outline_rounded,
                  label: 'Reviews',
                ),
              ),
            if (widget.onOpenReviews != null) const PopupMenuDivider(),
            const PopupMenuItem(
              value: _HeaderAvatarAction.signOut,
              child: _HeaderMenuRow(
                icon: Icons.logout_rounded,
                label: 'Logout',
              ),
            ),
          ];
        }
        return [
          const PopupMenuItem(
            value: _HeaderAvatarAction.profile,
            child: _HeaderMenuRow(icon: Icons.person_outline, label: 'Profile'),
          ),
          if (!widget.hideHistoryMenuItem)
            const PopupMenuItem(
              value: _HeaderAvatarAction.history,
              child: _HeaderMenuRow(icon: Icons.history, label: 'History'),
            ),
          if (!widget.hideCalendarMenuItem)
            const PopupMenuItem(
              value: _HeaderAvatarAction.calendar,
              child: _HeaderMenuRow(
                icon: Icons.calendar_month_outlined,
                label: 'Calendar',
              ),
            ),
          const PopupMenuItem(
            value: _HeaderAvatarAction.artist,
            child: _HeaderMenuRow(icon: Icons.brush_outlined, label: 'Artist'),
          ),
          const PopupMenuItem(
            value: _HeaderAvatarAction.reviews,
            child: _HeaderMenuRow(
              icon: Icons.star_outline_rounded,
              label: 'Reviews',
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: _HeaderAvatarAction.signOut,
            child: _HeaderMenuRow(
              icon: Icons.logout_rounded,
              label: 'Logout',
              color: AppColors.blackCat,
            ),
          ),
        ];
      },
    );
  }

  String _monthShort(int m) {
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
    return months[(m - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRequests;
    final items = _historyItems;
    final byId = <String, ArtistOrderLite>{
      for (final item in items) item.id: item,
    };
    final brandRequests = filtered
        .where(_isBrandRequest)
        .toList(growable: false);
    final clientRequests = filtered
        .where((r) => !_isBrandRequest(r))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: JntStandardAppBar(
        onNotifications: _openNotifications,
        trailing: _avatarMenu(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
        children: [
          _HistoryTabs(
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
            allCount: _countForFilter(ArtistHistoryFilter.all),
            deliveredCount: _countForFilter(ArtistHistoryFilter.delivered),
            declinedCount: _countForFilter(ArtistHistoryFilter.declined),
            expiredCount: _countForFilter(ArtistHistoryFilter.expired),
            cancelledCount: _countForFilter(ArtistHistoryFilter.cancelled),
          ),
          const SizedBox(height: 16),
          if (_isLoadingDb && filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            _Card(
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 46,
                    color: AppColors.blackCat.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No history found',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Only real-time delivered, declined, expired, and cancelled orders appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.60),
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _HistorySection(
              title: 'Brand Requests',
              requests: brandRequests,
              byId: byId,
              onTap: (r) => _openHistoryPopup(context, r),
            ),
            const SizedBox(height: 14),
            _HistorySection(
              title: 'Client Requests',
              requests: clientRequests,
              byId: byId,
              onTap: (r) => _openHistoryPopup(context, r),
            ),
          ],
        ],
      ),
      bottomNavigationBar: widget.bottomNavigationBar ??
          (widget.showBottomNav
          ? BottomNavigationBar(
              currentIndex: widget.bottomNavIndex,
              selectedItemColor: AppColors.blackCat,
              unselectedItemColor: AppColors.blackCat.withValues(alpha: 0.35),
              type: BottomNavigationBarType.fixed,
              onTap: (i) {
                if (widget.onNavTap != null) {
                  widget.onNavTap!(i);
                  return;
                }
                if (i != widget.bottomNavIndex) {
                  Navigator.pop(context);
                }
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_filled),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline),
                  label: 'Design',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inbox_outlined),
                  label: 'Requests',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'Calendar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
              ],
            )
          : null),
    );
  }
}

enum ArtistHistoryFilter { all, delivered, declined, expired, cancelled }

class _HistoryTabs extends StatelessWidget {
  const _HistoryTabs({
    required this.selected,
    required this.onChanged,
    required this.allCount,
    required this.deliveredCount,
    required this.declinedCount,
    required this.expiredCount,
    required this.cancelledCount,
  });
  final ArtistHistoryFilter selected;
  final ValueChanged<ArtistHistoryFilter> onChanged;
  final int allCount;
  final int deliveredCount;
  final int declinedCount;
  final int expiredCount;
  final int cancelledCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tab('All', allCount, ArtistHistoryFilter.all),
            _tab('Delivered', deliveredCount, ArtistHistoryFilter.delivered),
            _tab('Declined', declinedCount, ArtistHistoryFilter.declined),
            _tab('Expired', expiredCount, ArtistHistoryFilter.expired),
            _tab('Cancelled', cancelledCount, ArtistHistoryFilter.cancelled),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, int count, ArtistHistoryFilter value) {
    final isSelected = selected == value;
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$label $count',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.blackCat
                    : AppColors.blackCat.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2.5,
              width: isSelected ? 24 : 0,
              decoration: BoxDecoration(
                color: AppColors.blackCat,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.order, required this.onTap});
  final ArtistOrderLite order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: MergeSemantics(
        child: Semantics(
          button: true,
          onTap: onTap,
          child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumb(
              imageAsset: order.imageAsset,
              clientEmail: order.clientEmail,
              clientName: order.clientName,
              fallbackLetter: order.clientName.trim().isEmpty
                  ? 'C'
                  : order.clientName.trim()[0].toUpperCase(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.blackCat,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _HistoryStatusChip(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.blackCat,
                      fontWeight: FontWeight.w400,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    order.statusText,
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w400,
                      fontSize: 13.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    this.imageAsset,
    required this.clientEmail,
    required this.clientName,
    required this.fallbackLetter,
  });
  final String? imageAsset;
  final String clientEmail;
  final String clientName;
  final String fallbackLetter;
  static const double _thumbSize = 56;
  static const int _thumbDecode = 256;

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

  @override
  Widget build(BuildContext context) {
    final raw = imageAsset?.trim().isNotEmpty == true ? imageAsset!.trim() : '';
    final p = _normalizeImagePath(raw);

    if (p.isEmpty) {
      return FutureBuilder<String>(
        future: _lookupClientProfileImage(
          email: clientEmail,
          name: clientName,
        ),
        builder: (_, snap) {
          final resolved = _normalizeImagePath((snap.data ?? '').trim());
          if (resolved.isEmpty) return _fallback();
          return _buildImage(resolved);
        },
      );
    }

    return _buildImage(p);
  }

  Widget _buildImage(String p) {

    final isNetwork = p.startsWith('http://') || p.startsWith('https://');
    final isAsset = p.startsWith('assets/');
    final isFileUri = p.startsWith('file://');
    final isFilePath = !kIsWeb && (p.startsWith('/') || p.contains(':\\'));

    final fallback = _fallback;

    final dataBytes = _decodeDataImageBytes(p);
    if (dataBytes != null && dataBytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.zero,
        child: Image.memory(
          dataBytes,
          height: _thumbSize,
          width: _thumbSize,
          fit: BoxFit.cover,
          cacheWidth: _thumbDecode,
          cacheHeight: _thumbDecode,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, _, _) => fallback(),
        ),
      );
    }

    Widget image;
    if (isNetwork) {
      image = Image.network(
        p,
        height: _thumbSize,
        width: _thumbSize,
        fit: BoxFit.cover,
        cacheWidth: _thumbDecode,
        cacheHeight: _thumbDecode,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else if (isAsset) {
      image = Image.asset(
        p,
        height: _thumbSize,
        width: _thumbSize,
        fit: BoxFit.cover,
        cacheWidth: _thumbDecode,
        cacheHeight: _thumbDecode,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else if (isFileUri || isFilePath) {
      final localPath = isFileUri ? p.replaceFirst('file://', '') : p;
      image = Image.file(
        File(localPath),
        height: _thumbSize,
        width: _thumbSize,
        fit: BoxFit.cover,
        cacheWidth: _thumbDecode,
        cacheHeight: _thumbDecode,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else {
      image = FutureBuilder<String>(
        future: StorageUrlResolver.resolve(p).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = (snap.data ?? '').trim();
          if (url.isEmpty) return fallback();
          return Image.network(
            url,
            height: _thumbSize,
            width: _thumbSize,
            fit: BoxFit.cover,
            cacheWidth: _thumbDecode,
            cacheHeight: _thumbDecode,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, _, _) => fallback(),
          );
        },
      );
    }

    return ClipRRect(borderRadius: BorderRadius.zero, child: image);
  }

  Widget _fallback() => Container(
      height: _thumbSize,
      width: _thumbSize,
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      alignment: Alignment.center,
      child: Text(
        fallbackLetter.trim().isEmpty ? 'C' : fallbackLetter.trim(),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: AppColors.blackCat,
        ),
      ),
    );

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
          final found = await lookupBy(table, column, email.trim().toLowerCase());
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
}

class _HistoryStatusChip extends StatelessWidget {
  const _HistoryStatusChip({required this.status});
  final ArtistOrderLiteStatus status;

  @override
  Widget build(BuildContext context) {
    late String text;

    switch (status) {
      case ArtistOrderLiteStatus.delivered:
        text = 'Delivered';
        break;
      case ArtistOrderLiteStatus.declined:
        text = 'Declined';
        break;
      case ArtistOrderLiteStatus.expired:
        text = 'Expired';
        break;
      case ArtistOrderLiteStatus.cancelled:
        text = 'Cancelled';
        break;
    }

    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: AppColors.blackCat,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

// Kept for compatibility with any existing imports/usages.
enum ArtistOrderLiteStatus { delivered, declined, expired, cancelled }

@immutable
class ArtistOrderLite {
  final String id;
  final String clientName;
  final String clientEmail;
  final String title;
  final String subtitle;
  final ArtistOrderLiteStatus status;
  final String statusText;
  final String? imageAsset;

  final int budgetMin;
  final int budgetMax;
  final String? carrier;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;

  final List<String> clientPhotos;
  final List<String> artistPhotos;
  final bool isBrandRequest;

  const ArtistOrderLite({
    required this.id,
    required this.clientName,
    this.clientEmail = '',
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusText,
    this.imageAsset,
    required this.budgetMin,
    required this.budgetMax,
    this.carrier,
    this.shippedAt,
    this.deliveredAt,
    this.clientPhotos = const [],
    this.artistPhotos = const [],
    this.isBrandRequest = false,
  });
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.title,
    required this.requests,
    required this.byId,
    required this.onTap,
  });

  final String title;
  final List<ClientRequestV2> requests;
  final Map<String, ArtistOrderLite> byId;
  final ValueChanged<ClientRequestV2> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${requests.length})',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.blackCat,
          ),
        ),
        const SizedBox(height: 10),
        if (requests.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'No $title found.',
              style: TextStyle(
                color: AppColors.blackCat.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          )
        else
          ...requests.map((r) {
            final lite = byId[r.id];
            if (lite == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HistoryCard(order: lite, onTap: () => onTap(r)),
            );
          }),
      ],
    );
  }
}

enum _HeaderAvatarAction {
  profile,
  history,
  calendar,
  artist,
  reviews,
  signOut,
}

class _HeaderMenuRow extends StatelessWidget {
  const _HeaderMenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? AppColors.blackCat),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: color ?? AppColors.blackCat,
          ),
        ),
      ],
    );
  }
}
