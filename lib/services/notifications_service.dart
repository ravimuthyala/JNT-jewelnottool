import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/scenario_4_1.dart';

class NotificationsService {
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static SupabaseClient get _supabase => Supabase.instance.client;

  static bool _asBool(Object? v, {bool fallback = true}) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.trim().toLowerCase();
      if (t == 'true' || t == '1' || t == 'yes') return true;
      if (t == 'false' || t == '0' || t == 'no') return false;
    }
    return fallback;
  }

  static bool _looksLikeUuid(String value) => _uuidPattern.hasMatch(value.trim());

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _rows(Object? value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    return <Map<String, dynamic>>[];
  }

  static String _email(Object? value) {
    final text = (value ?? '').toString().trim().toLowerCase();
    return text.contains('@') ? text : '';
  }

  static DateTime _dateFromRow(Map<String, dynamic> data) {
    final candidates = <Object?>[
      data['created_at'],
      data['createdAt'],
      data['created_at_client'],
      data['createdAtClient'],
      data['created_at_millis'],
      data['createdAtMillis'],
    ];
    for (final value in candidates) {
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static Map<String, dynamic> _notificationRow({
    required String receiverEmail,
    required String title,
    required String body,
    required String type,
    String orderId = '',
    String orderNumber = '',
    String sourceCollection = 'Client_Custom_Requests',
    Map<String, dynamic> extra = const <String, dynamic>{},
    bool includeCreated = true,
  }) {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final normalized = receiverEmail.trim().toLowerCase();
    final safeOrderId = _looksLikeUuid(orderId) ? orderId.trim() : '';
    final safeOrderNumber = orderNumber.trim();
    final extraPayload = <String, dynamic>{...extra};
    if (safeOrderId.isEmpty && orderId.trim().isNotEmpty) {
      extraPayload['legacyOrderId'] = orderId.trim();
    }
    if (safeOrderNumber.isEmpty && orderId.trim().isNotEmpty) {
      extraPayload['legacyOrderNumber'] = orderId.trim();
    }

    return <String, dynamic>{
      'receiver_email': normalized,
      'title': title,
      'body': body,
      'type': type,
      if (safeOrderId.isNotEmpty) 'order_id': safeOrderId,
      if (safeOrderNumber.isNotEmpty) 'order_number': safeOrderNumber,
      'source_collection': sourceCollection,
      'read': false,
      'extra': extraPayload,
      'updated_at': nowIso,
      if (includeCreated) 'created_at': nowIso,
      if (includeCreated) 'created_at_millis': now.millisecondsSinceEpoch,
    };
  }

  static Future<void> upsertUserNotification({
    required String receiverEmail,
    required String title,
    required String body,
    required String type,
    required String orderId,
    String orderNumber = '',
    String sourceCollection = 'Client_Custom_Requests',
  }) async {
    final normalized = receiverEmail.trim().toLowerCase();
    if (normalized.isEmpty) return;

    final safeOrderId = _looksLikeUuid(orderId) ? orderId.trim() : '';
    final safeOrderNumber = orderNumber.trim();

    dynamic query = _supabase
        .from('user_notifications')
        .select('id')
        .eq('receiver_email', normalized)
        .eq('type', type);

    if (safeOrderId.isNotEmpty) {
      query = query.eq('order_id', safeOrderId);
    } else if (safeOrderNumber.isNotEmpty) {
      query = query.eq('order_number', safeOrderNumber);
    }

    final existing = await query.limit(1);
    final row = _notificationRow(
      receiverEmail: normalized,
      title: title,
      body: body,
      type: type,
      orderId: safeOrderId,
      orderNumber: safeOrderNumber,
      sourceCollection: sourceCollection,
    );

    if (existing is List && existing.isNotEmpty) {
      final id = existing.first['id'];
      await _supabase.from('user_notifications').update(row..remove('created_at')..remove('created_at_millis')).eq('id', id);
    } else {
      await _supabase.from('user_notifications').insert(row);
    }

    await trimUserNotifications(receiverEmail: normalized, maxKeep: 25);
  }

  static Future<void> createUserNotification({
    required String receiverEmail,
    required String title,
    required String body,
    required String type,
    String orderId = '',
    String orderNumber = '',
    String sourceCollection = 'Client_Custom_Requests',
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) async {
    final normalized = receiverEmail.trim().toLowerCase();
    if (normalized.isEmpty) return;

    await _supabase.from('user_notifications').insert(
          _notificationRow(
            receiverEmail: normalized,
            title: title,
            body: body,
            type: type,
            orderId: orderId,
            orderNumber: orderNumber,
            sourceCollection: sourceCollection,
            extra: extra,
          ),
        );
    await trimUserNotifications(receiverEmail: normalized, maxKeep: 25);
  }

  static Stream<int> watchUnreadCount({required String receiverEmail}) {
    final normalized = receiverEmail.trim().toLowerCase();
    if (normalized.isEmpty) return Stream<int>.value(0);
    final controller = StreamController<int>.broadcast();

    Future<void> emit() async {
      try {
        final rows = _rows(
          await _supabase
              .from('user_notifications')
              .select('id, read')
              .eq('receiver_email', normalized)
              .limit(500),
        );
        final unread = rows.where((row) => row['read'] != true).length;
        if (!controller.isClosed) controller.add(unread);
      } catch (_) {
        if (!controller.isClosed) controller.add(0);
      }
    }

    unawaited(emit());

    final channel = _supabase
        .channel('user_notifications_unread_$normalized')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_email',
            value: normalized,
          ),
          callback: (_) => unawaited(emit()),
        )
        .subscribe();

    controller.onCancel = () async {
      await _supabase.removeChannel(channel);
    };

    return controller.stream;
  }

  static Future<int> markAllNotificationsRead({
    required String receiverEmail,
  }) async {
    final normalized = receiverEmail.trim().toLowerCase();
    if (normalized.isEmpty) return 0;

    final unreadRows = _rows(
      await _supabase
          .from('user_notifications')
          .select('id, read')
          .eq('receiver_email', normalized)
          .limit(500),
    );

    final unreadIds = unreadRows
        .where((row) => row['read'] != true)
        .map((row) => (row['id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (unreadIds.isEmpty) return 0;

    await _supabase
        .from('user_notifications')
        .update({'read': true, 'updated_at': DateTime.now().toIso8601String()})
        .inFilter('id', unreadIds);

    await trimUserNotifications(receiverEmail: normalized, maxKeep: 25);
    return unreadIds.length;
  }

  static Future<bool> markNotificationRead({
    required String receiverEmail,
    required String notificationId,
  }) async {
    final normalized = receiverEmail.trim().toLowerCase();
    final id = notificationId.trim();
    if (normalized.isEmpty || id.isEmpty) return false;

    await _supabase
        .from('user_notifications')
        .update({'read': true, 'updated_at': DateTime.now().toIso8601String()})
        .eq('receiver_email', normalized)
        .eq('id', id);

    await trimUserNotifications(receiverEmail: normalized, maxKeep: 25);
    return true;
  }

  static Future<void> trimUserNotifications({
    required String receiverEmail,
    int maxKeep = 25,
  }) async {
    final normalized = receiverEmail.trim().toLowerCase();
    if (normalized.isEmpty || maxKeep < 1) return;

    final rows = _rows(
      await _supabase
          .from('user_notifications')
          .select()
          .eq('receiver_email', normalized),
    );
    if (rows.length <= maxKeep) return;

    rows.sort((a, b) => _dateFromRow(a).compareTo(_dateFromRow(b)));

    final readRows = <Map<String, dynamic>>[];
    final unreadRows = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row['read'] == true) {
        readRows.add(row);
      } else {
        unreadRows.add(row);
      }
    }

    final idsToDelete = <Object>[];
    var overflow = rows.length - maxKeep;
    for (final row in readRows) {
      if (overflow <= 0) break;
      if (row['id'] != null) idsToDelete.add(row['id']);
      overflow--;
    }
    for (final row in unreadRows) {
      if (overflow <= 0) break;
      if (row['id'] != null) idsToDelete.add(row['id']);
      overflow--;
    }
    if (idsToDelete.isEmpty) return;

    await _supabase.from('user_notifications').delete().inFilter('id', idsToDelete);
  }

  static Future<void> notifyArtistsForNewClientRequest({
    required String clientName,
    required bool isDirectRequest,
    required String selectedArtistEmail,
    String selectedArtistName = '',
    required String orderId,
    required String sourceCollection,
    String orderNumber = '',
    bool allowNonLicensed = true,
    Iterable<String> excludeArtistEmails = const <String>[],
  }) async {
    final targets = await _resolveArtistNotificationTargets(
      isDirectRequest: isDirectRequest,
      selectedArtistEmail: selectedArtistEmail,
      selectedArtistName: selectedArtistName,
      allowNonLicensed: allowNonLicensed,
      excludeArtistEmails: excludeArtistEmails,
    );

    final name = clientName.trim().isEmpty ? 'Client' : clientName.trim();
    for (final email in targets) {
      final body = isDirectRequest
          ? 'You’ve received a direct request from $name (ID: $orderId).'
          : 'Great news! $name has submitted a new nail request';
      await createUserNotification(
        receiverEmail: email,
        title: 'New Request',
        body: body,
        type: 'new_client_request',
        orderId: orderId,
        orderNumber: orderNumber,
        sourceCollection: sourceCollection,
      );
    }
  }

  static Future<void> notifyArtistsForBrandClientAcceptedRequest({
    required String clientName,
    required String brandName,
    String campaignName = '',
    required bool isDirectRequest,
    required String selectedArtistEmail,
    String selectedArtistName = '',
    required String orderId,
    required String sourceCollection,
    String orderNumber = '',
    bool allowNonLicensed = true,
    bool requireBrandEligible = true,
    Iterable<String> excludeArtistEmails = const <String>[],
  }) async {
    final targets = await _resolveArtistNotificationTargets(
      isDirectRequest: isDirectRequest,
      selectedArtistEmail: selectedArtistEmail,
      selectedArtistName: selectedArtistName,
      allowNonLicensed: allowNonLicensed,
      requireBrandEligible: requireBrandEligible,
      excludeArtistEmails: excludeArtistEmails,
    );

    final client = clientName.trim().isEmpty ? 'Client' : clientName.trim();
    final brand = brandName.trim().isEmpty ? 'Brand' : brandName.trim();
    final campaign = campaignName.trim().isEmpty ? 'Campaign' : campaignName.trim();
    final orderRef = orderNumber.trim().isNotEmpty ? orderNumber.trim() : orderId;
    for (final email in targets) {
      await createUserNotification(
        receiverEmail: email,
        title: 'Brand Request Available',
        body: scenario41DirectArtistReceiveOnClientAcceptance(
          orderRef: orderRef,
          clientName: client,
          brandName: brand,
          campaignName: campaign,
        ),
        type: 'brand_request_for_artist_pool',
        orderId: orderId,
        orderNumber: orderNumber,
        sourceCollection: sourceCollection,
      );
    }
  }

  static Future<void> notifyArtistPoolBrandDelivered({
    required String clientName,
    required String campaignName,
    required String orderId,
    required String sourceCollection,
    String orderNumber = '',
    Iterable<String> excludeArtistEmails = const <String>[],
  }) async {
    final targets = await _resolveArtistNotificationTargets(
      isDirectRequest: false,
      selectedArtistEmail: '',
      selectedArtistName: '',
      allowNonLicensed: false,
      requireBrandEligible: true,
      excludeArtistEmails: excludeArtistEmails,
    );

    final client = clientName.trim().isEmpty ? 'Client' : clientName.trim();
    final campaign = campaignName.trim().isEmpty ? 'Campaign' : campaignName.trim();
    final orderRef = orderNumber.trim().isNotEmpty ? orderNumber.trim() : orderId;
    for (final email in targets) {
      await createUserNotification(
        receiverEmail: email,
        title: 'Brand Request Delivered',
        body: 'Delivered: $campaign brand request $orderRef to $client',
        type: 'brand_request_delivered_artist_pool',
        orderId: orderId,
        orderNumber: orderNumber,
        sourceCollection: sourceCollection,
      );
    }
  }

  static Future<void> notifyAdmins({
    required String title,
    required String body,
    required String type,
    String orderId = '',
    String orderNumber = '',
    String sourceCollection = 'Client_Custom_Requests',
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) async {
    final admins = await _loadAdminEmails();
    for (final email in admins) {
      await createUserNotification(
        receiverEmail: email,
        title: title,
        body: body,
        type: type,
        orderId: orderId,
        orderNumber: orderNumber,
        sourceCollection: sourceCollection,
        extra: extra,
      );
    }

    await _supabase.from('admin_notifications').insert({
      'type': type,
      'source': sourceCollection,
      'request_id': orderId,
      'title': title,
      'message': body,
      'date_label': DateTime.now().toIso8601String(),
      'event_at': DateTime.now().toIso8601String(),
      'payload': <String, dynamic>{
        ...extra,
        'orderId': orderId,
        'orderNumber': orderNumber,
        'sourceCollection': sourceCollection,
      },
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).catchError((_) {});
  }

  static Future<Set<String>> resolveBrandRecipientEmails({
    Map<String, dynamic> rootData = const <String, dynamic>{},
    Map<String, dynamic> detailsData = const <String, dynamic>{},
    Map<String, dynamic> orderData = const <String, dynamic>{},
    Iterable<String> excludeEmails = const <String>[],
  }) async {
    String norm(Object? v) => (v ?? '').toString().trim().toLowerCase();
    final excluded = excludeEmails.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
    final out = <String>{};

    void addEmail(Object? v) {
      final e = norm(v);
      if (e.isEmpty || excluded.contains(e) || !e.contains('@')) return;
      out.add(e);
    }

    void addCommonFrom(Map<String, dynamic> data) {
      addEmail(data['company_email']);
      addEmail(data['companyEmail']);
      addEmail(data['brand_email']);
      addEmail(data['brandEmail']);
      addEmail(data['requester_email']);
      addEmail(data['requesterEmail']);
      addEmail(data['created_by_email']);
      addEmail(data['createdByEmail']);
      addEmail(data['owner_email']);
      addEmail(data['ownerEmail']);
      addEmail(data['email']);
      addEmail(data['panel_contact_email']);
      addEmail(data['panel_contactEmail']);
      addEmail(data['contact_email']);
      addEmail(data['contactEmail']);
    }

    addCommonFrom(rootData);
    addCommonFrom(detailsData);
    addCommonFrom(orderData);

    final orderMeta = _map(detailsData['order']);
    addCommonFrom(orderMeta);

    final companyUidCandidates = <String>{
      norm(rootData['company_uid']),
      norm(rootData['companyUid']),
      norm(detailsData['company_uid']),
      norm(detailsData['companyUid']),
      norm(orderData['company_uid']),
      norm(orderData['companyUid']),
      norm(orderMeta['company_uid']),
      norm(orderMeta['companyUid']),
    }..removeWhere((e) => e.isEmpty);

    final companyEmailCandidates = <String>{
      norm(rootData['company_email']),
      norm(rootData['companyEmail']),
      norm(detailsData['company_email']),
      norm(detailsData['companyEmail']),
      norm(orderData['company_email']),
      norm(orderData['companyEmail']),
      norm(orderMeta['company_email']),
      norm(orderMeta['companyEmail']),
      norm(rootData['brand_email']),
      norm(rootData['brandEmail']),
      norm(detailsData['brand_email']),
      norm(detailsData['brandEmail']),
      norm(orderData['brand_email']),
      norm(orderData['brandEmail']),
      norm(orderMeta['brand_email']),
      norm(orderMeta['brandEmail']),
      norm(rootData['panel_contact_email']),
      norm(rootData['panel_contactEmail']),
      norm(detailsData['panel_contact_email']),
      norm(detailsData['panel_contactEmail']),
      norm(orderData['panel_contact_email']),
      norm(orderData['panel_contactEmail']),
    }..removeWhere((e) => e.isEmpty);

    void addNestedEmails(Object? value) {
      if (value == null) return;
      if (value is String) {
        if (value.contains('@')) addEmail(value);
        return;
      }
      if (value is Iterable) {
        for (final item in value) addNestedEmails(item);
        return;
      }
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        for (final entry in map.entries) {
          final key = entry.key.toLowerCase();
          if (key.contains('email') ||
              key.contains('member') ||
              key.contains('team') ||
              key.contains('user') ||
              key.contains('owner') ||
              key.contains('admin') ||
              key.contains('contact')) {
            addNestedEmails(entry.value);
          }
        }
      }
    }

    void addFromCompanyRow(Map<String, dynamic> data) {
      addCommonFrom(data);
      addCommonFrom(_map(data['profile']));
      addCommonFrom(_map(data['company']));
      addCommonFrom(_map(data['basic']));
      addNestedEmails(data['team_members']);
      addNestedEmails(data['teamMembers']);
      addNestedEmails(data['members']);
      addNestedEmails(data['users']);
      addNestedEmails(data['admins']);
      addNestedEmails(data['owners']);
      addNestedEmails(data['contacts']);
    }

    for (final uid in companyUidCandidates) {
      try {
        if (_looksLikeUuid(uid)) {
          final row = await _supabase.from('company').select().eq('id', uid).maybeSingle();
          if (row != null) addFromCompanyRow(Map<String, dynamic>.from(row));
        }
      } catch (_) {}
      try {
        final rows = _rows(await _supabase.from('company').select().eq('company_uid', uid).limit(50));
        for (final row in rows) addFromCompanyRow(row);
      } catch (_) {}
      try {
        final rows = _rows(await _supabase.from('company').select().eq('uid', uid).limit(50));
        for (final row in rows) addFromCompanyRow(row);
      } catch (_) {}
    }

    for (final email in companyEmailCandidates) {
      try {
        final rows = _rows(await _supabase.from('company').select().ilike('email', email).limit(50));
        for (final row in rows) addFromCompanyRow(row);
      } catch (_) {}
      try {
        final rows = _rows(await _supabase.from('company').select().ilike('company_email', email).limit(50));
        for (final row in rows) addFromCompanyRow(row);
      } catch (_) {}
      try {
        final rows = _rows(await _supabase.from('company').select().ilike('panel_contact_email', email).limit(50));
        for (final row in rows) addFromCompanyRow(row);
      } catch (_) {}
    }

    return out;
  }

  static Future<Set<String>> _resolveArtistNotificationTargets({
    required bool isDirectRequest,
    required String selectedArtistEmail,
    required String selectedArtistName,
    required bool allowNonLicensed,
    bool requireBrandEligible = false,
    Iterable<String> excludeArtistEmails = const <String>[],
  }) async {
    final targets = <String>{};
    final normalizedSelected = selectedArtistEmail.trim().toLowerCase();
    final normalizedSelectedName = selectedArtistName.trim().toLowerCase();
    final excluded = excludeArtistEmails.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();

    bool isLicensedArtist(Map<String, dynamic> data) {
      final profile = _map(data['profile']);
      final credentials = _map(data['credentials']);
      final nestedCredentials = _map(profile['credentials']);
      final candidates = <Object?>[
        credentials['nailTechType'],
        credentials['nail_tech_type'],
        nestedCredentials['nailTechType'],
        nestedCredentials['nail_tech_type'],
        profile['nailTechType'],
        profile['nail_tech_type'],
        data['panel_nail_tech_type'],
        data['panel_nailTechType'],
        data['nail_tech_type'],
        data['nailTechType'],
        data['credential'],
      ];
      String type = '';
      for (final raw in candidates) {
        final value = (raw ?? '').toString().trim();
        if (value.isNotEmpty) {
          type = value.toLowerCase();
          break;
        }
      }
      if (type.isEmpty) return true;
      final isUnlicensed = type.contains('student') || type.contains('non-licensed') || type.contains('unlicensed');
      return !isUnlicensed;
    }

    bool isBrandEligibleArtist(Map<String, dynamic> data) {
      final profile = _map(data['profile']);
      final basic = _map(data['basic']);
      final ascension = _map(data['ascension']);
      final sponsorshipRequest = _map(data['sponsorshipRequest'].toString().isNotEmpty ? data['sponsorshipRequest'] : data['sponsorship_request']);
      final tierCandidates = <Object?>[
        ascension['tier'],
        ascension['levelName'],
        ascension['level_name'],
        ascension['level'],
        ascension['name'],
        data['sponsorship_tier'],
        data['sponsorshipTier'],
        sponsorshipRequest['tier'],
        profile['ascensionTier'],
        profile['ascension_tier'],
        profile['tier'],
        basic['ascensionTier'],
        basic['ascension_tier'],
        basic['tier'],
        data['panel_ascension_level'],
        data['panel_ascensionLevel'],
        data['panel_ascension_tier'],
        data['panel_ascensionTier'],
        data['ascension_tier'],
        data['ascensionTier'],
        data['tier'],
      ];
      for (final raw in tierCandidates) {
        final tier = (raw ?? '').toString().trim().toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
        if (tier == 'goldsmith' || tier == 'crowned') return true;
        if (tier.contains('goldsmith') || tier.contains('crowned')) return true;
      }
      final eligibleCandidates = <Object?>[
        ascension['sponsorshipEligible'],
        ascension['sponsorship_eligible'],
        data['panel_brand_eligible'],
        data['panel_brandEligible'],
        profile['sponsorshipEligible'],
        profile['sponsorship_eligible'],
        basic['sponsorshipEligible'],
        basic['sponsorship_eligible'],
        data['brand_eligible'],
        data['brandEligible'],
        data['is_brand_eligible'],
        data['isBrandEligible'],
      ];
      for (final raw in eligibleCandidates) {
        if (_asBool(raw, fallback: false)) return true;
      }
      return false;
    }

    Future<void> scanTable(String table) async {
      final rows = _rows(await _supabase.from(table).select());
      for (final data in rows) {
        final email = _email(data['email']);
        if (email.isEmpty || excluded.contains(email)) continue;
        final name = (data['name'] ?? data['display_name'] ?? data['displayName'] ?? '').toString().trim().toLowerCase();
        final notifications = _map(data['notifications']);
        final allEnabled = _asBool(
          data['panel_all_client_request_notifications_enabled'] ??
              data['panel_allClientRequestNotificationsEnabled'] ??
              notifications['allClientRequestsEnabled'] ??
              notifications['all_client_requests_enabled'],
          fallback: true,
        );
        final directEnabled = _asBool(
          notifications['directRequestNotificationsEnabled'] ?? notifications['direct_request_notifications_enabled'],
          fallback: true,
        );

        if (isDirectRequest) {
          if (requireBrandEligible && !isBrandEligibleArtist(data)) continue;
          final emailMatch = normalizedSelected.isNotEmpty && email == normalizedSelected;
          final nameMatch = normalizedSelected.isEmpty && normalizedSelectedName.isNotEmpty && name == normalizedSelectedName;
          if ((emailMatch || nameMatch) && directEnabled) targets.add(email);
        } else {
          if (!allowNonLicensed && !isLicensedArtist(data)) continue;
          if (requireBrandEligible && !isBrandEligibleArtist(data)) continue;
          if (allEnabled) targets.add(email);
        }
      }
    }

    await scanTable('artist').catchError((_) {});
    await scanTable('client_artist').catchError((_) {});

    if (isDirectRequest && normalizedSelected.isNotEmpty && targets.isEmpty) {
      if (!excluded.contains(normalizedSelected)) targets.add(normalizedSelected);
    }
    return targets;
  }

  static Future<Set<String>> _loadAdminEmails() async {
    final out = <String>{};

    String pickEmail(Map<String, dynamic> data) {
      final profile = _map(data['profile']);
      final basic = _map(data['basic']);
      final candidates = <Object?>[
        data['email'],
        data['admin_email'],
        data['adminEmail'],
        data['contact_email'],
        data['contactEmail'],
        profile['email'],
        basic['email'],
      ];
      for (final raw in candidates) {
        final email = _email(raw);
        if (email.isNotEmpty) return email;
      }
      return '';
    }

    bool isAdminLike(Map<String, dynamic> data) {
      final role = (data['role'] ?? data['userRole'] ?? data['user_role'] ?? data['type'] ?? '').toString().trim().toLowerCase();
      if (role.contains('admin')) return true;
      final roles = (data['roles'] is List) ? (data['roles'] as List) : const <dynamic>[];
      for (final raw in roles) {
        if (raw.toString().trim().toLowerCase().contains('admin')) return true;
      }
      return false;
    }

    Future<void> scanTable(String name, {bool requireAdminRole = false}) async {
      try {
        final rows = _rows(await _supabase.from(name).select());
        for (final row in rows) {
          if ((row['is_active'] == false) || (row['active'] == false)) continue;
          if (requireAdminRole && !isAdminLike(row)) continue;
          final email = pickEmail(row);
          if (email.isNotEmpty) out.add(email);
        }
      } catch (_) {}
    }

    await scanTable('admin_users');
    await scanTable('admin');
    await scanTable('admins');
    await scanTable('users', requireAdminRole: true);
    return out;
  }

  static Future<void> queueEmail({
    required String to,
    required String subject,
    required String text,
    String? html,
  }) async {
    final normalized = to.trim().toLowerCase();
    if (normalized.isEmpty) return;

    await _supabase.from('mail_queue').insert({
      'to_email': normalized,
      'to_list': <String>[normalized],
      'subject': subject,
      'text': text,
      if (html != null && html.trim().isNotEmpty) 'html': html.trim(),
      'status': 'queued',
      'created_at': DateTime.now().toIso8601String(),
      'payload': <String, dynamic>{
        'to': <String>[normalized],
        'message': {
          'subject': subject,
          'text': text,
          if (html != null && html.trim().isNotEmpty) 'html': html.trim(),
        },
      },
    });
  }

  static Future<void> queueTemplatedEmail({
    required String to,
    required String templateName,
    required Map<String, dynamic> data,
  }) async {
    final normalized = to.trim().toLowerCase();
    if (normalized.isEmpty || templateName.trim().isEmpty) return;

    await _supabase.from('mail_queue').insert({
      'to_email': normalized,
      'to_list': <String>[normalized],
      'template_name': templateName.trim(),
      'template_data': data,
      'status': 'queued',
      'created_at': DateTime.now().toIso8601String(),
      'payload': <String, dynamic>{
        'to': <String>[normalized],
        'toEmail': normalized,
        'template': {'name': templateName.trim(), 'data': data},
      },
    });
  }

  static Future<void> queueSms({
    required String to,
    required String text,
  }) async {
    final normalized = to.trim();
    if (normalized.isEmpty) return;

    await _supabase.from('sms_outbox').insert({
      'to_number': normalized,
      'message': text.trim(),
      'status': 'queued',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
