import 'supabase_firebase_compat.dart';
import '../utils/scenario_4_1.dart';

class NotificationsService {
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
    if (normalized.isEmpty || orderId.trim().isEmpty) return;

    final snap = await FirebaseFirestore.instance
        .collection('user_notifications')
        .where('receiverEmail', isEqualTo: normalized)
        .where('orderId', isEqualTo: orderId)
        .where('type', isEqualTo: type)
        .limit(1)
        .get();

    final data = {
      'receiverEmail': normalized,
      'title': title,
      'body': body,
      'type': type,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'sourceCollection': sourceCollection,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtClient': Timestamp.now(),
      'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
    };

    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.set(data, SetOptions(merge: true));
    } else {
      await FirebaseFirestore.instance
          .collection('user_notifications')
          .add(data);
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

    final now = Timestamp.now();
    await FirebaseFirestore.instance.collection('user_notifications').add({
      'receiverEmail': normalized,
      'title': title,
      'body': body,
      'type': type,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'sourceCollection': sourceCollection,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtClient': now,
      'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
      ...extra,
    });
    await trimUserNotifications(receiverEmail: normalized, maxKeep: 25);
  }

  static Stream<int> watchUnreadCount({required String receiverEmail}) {
    final normalized = receiverEmail.trim().toLowerCase();
    if (normalized.isEmpty) return Stream<int>.value(0);
    return FirebaseFirestore.instance
        .collection('user_notifications')
        .where('receiverEmail', isEqualTo: normalized)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  static Future<void> trimUserNotifications({
    required String receiverEmail,
    int maxKeep = 25,
  }) async {
    final normalized = receiverEmail.trim().toLowerCase();
    if (normalized.isEmpty || maxKeep < 1) return;

    final snap = await FirebaseFirestore.instance
        .collection('user_notifications')
        .where('receiverEmail', isEqualTo: normalized)
        .get();
    if (snap.docs.length <= maxKeep) return;

    DateTime resolveCreatedAt(Map<String, dynamic> data) {
      final server = data['createdAt'];
      if (server is Timestamp) return server.toDate();
      final client = data['createdAtClient'];
      if (client is Timestamp) return client.toDate();
      final millis = data['createdAtMillis'];
      if (millis is num) {
        return DateTime.fromMillisecondsSinceEpoch(millis.toInt());
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final docs = snap.docs.toList(growable: false);
    docs.sort(
      (a, b) =>
          resolveCreatedAt(a.data()).compareTo(resolveCreatedAt(b.data())),
    );

    final readDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final unreadDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final d in docs) {
      if (d.data()['read'] == true) {
        readDocs.add(d);
      } else {
        unreadDocs.add(d);
      }
    }

    final toDelete = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var overflow = docs.length - maxKeep;
    for (final d in readDocs) {
      if (overflow <= 0) break;
      toDelete.add(d);
      overflow--;
    }
    for (final d in unreadDocs) {
      if (overflow <= 0) break;
      toDelete.add(d);
      overflow--;
    }
    if (toDelete.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final d in toDelete) {
      batch.delete(d.reference);
    }
    await batch.commit();
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
    final campaign = campaignName.trim().isEmpty
        ? 'Campaign'
        : campaignName.trim();
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
    final campaign = campaignName.trim().isEmpty
        ? 'Campaign'
        : campaignName.trim();
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
  }

  static Future<Set<String>> resolveBrandRecipientEmails({
    Map<String, dynamic> rootData = const <String, dynamic>{},
    Map<String, dynamic> detailsData = const <String, dynamic>{},
    Map<String, dynamic> orderData = const <String, dynamic>{},
    Iterable<String> excludeEmails = const <String>[],
  }) async {
    String norm(Object? v) => (v ?? '').toString().trim().toLowerCase();
    final excluded = excludeEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final out = <String>{};

    void addEmail(Object? v) {
      final e = norm(v);
      if (e.isEmpty) return;
      if (excluded.contains(e)) return;
      out.add(e);
    }

    void addCommonFrom(Map<String, dynamic> data) {
      addEmail(data['companyEmail']);
      addEmail(data['brandEmail']);
      addEmail(data['requesterEmail']);
      addEmail(data['createdByEmail']);
      addEmail(data['ownerEmail']);
      addEmail(data['email']);
      addEmail(data['panel_contactEmail']);
      addEmail(data['contactEmail']);
    }

    addCommonFrom(rootData);
    addCommonFrom(detailsData);
    addCommonFrom(orderData);

    final orderMeta =
        (detailsData['order'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    addCommonFrom(orderMeta);

    final companyUidCandidates = <String>{
      norm(rootData['companyUid']),
      norm(detailsData['companyUid']),
      norm(orderData['companyUid']),
      norm(orderMeta['companyUid']),
    }..removeWhere((e) => e.isEmpty);

    final companyEmailCandidates = <String>{
      norm(rootData['companyEmail']),
      norm(detailsData['companyEmail']),
      norm(orderData['companyEmail']),
      norm(orderMeta['companyEmail']),
      norm(rootData['brandEmail']),
      norm(detailsData['brandEmail']),
      norm(orderData['brandEmail']),
      norm(orderMeta['brandEmail']),
      norm(rootData['panel_contactEmail']),
      norm(detailsData['panel_contactEmail']),
      norm(orderData['panel_contactEmail']),
    }..removeWhere((e) => e.isEmpty);

    void addNestedEmails(dynamic value) {
      if (value == null) return;
      if (value is String) {
        if (value.contains('@')) addEmail(value);
        return;
      }
      if (value is Iterable) {
        for (final item in value) {
          addNestedEmails(item);
        }
        return;
      }
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        for (final entry in map.entries) {
          final key = entry.key.toLowerCase();
          if (key.contains('email')) {
            addNestedEmails(entry.value);
          } else if (key.contains('member') ||
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

    Future<void> addFromCompanyDoc(DocumentSnapshot<Map<String, dynamic>> snap) async {
      if (!snap.exists) return;
      final data = snap.data() ?? const <String, dynamic>{};
      addCommonFrom(data);
      final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
      final company = (data['company'] as Map<String, dynamic>?) ?? const {};
      addCommonFrom(profile);
      addCommonFrom(company);
      addNestedEmails(data['teamMembers']);
      addNestedEmails(data['members']);
      addNestedEmails(data['users']);
      addNestedEmails(data['admins']);
      addNestedEmails(data['owners']);
      addNestedEmails(data['contacts']);
    }

    final db = FirebaseFirestore.instance;

    for (final uid in companyUidCandidates) {
      try {
        final byId = await db.collection('company').doc(uid).get();
        await addFromCompanyDoc(byId);
      } catch (_) {}
      try {
        final byCompanyUid = await db
            .collection('company')
            .where('companyUid', isEqualTo: uid)
            .limit(50)
            .get();
        for (final doc in byCompanyUid.docs) {
          await addFromCompanyDoc(doc);
        }
      } catch (_) {}
    }

    for (final email in companyEmailCandidates) {
      try {
        final byEmail = await db
            .collection('company')
            .where('email', isEqualTo: email)
            .limit(50)
            .get();
        for (final doc in byEmail.docs) {
          await addFromCompanyDoc(doc);
        }
      } catch (_) {}
      try {
        final byCompanyEmail = await db
            .collection('company')
            .where('companyEmail', isEqualTo: email)
            .limit(50)
            .get();
        for (final doc in byCompanyEmail.docs) {
          await addFromCompanyDoc(doc);
        }
      } catch (_) {}
      try {
        final byPanelContact = await db
            .collection('company')
            .where('panel_contactEmail', isEqualTo: email)
            .limit(50)
            .get();
        for (final doc in byPanelContact.docs) {
          await addFromCompanyDoc(doc);
        }
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
    final db = FirebaseFirestore.instance;
    final targets = <String>{};
    final normalizedSelected = selectedArtistEmail.trim().toLowerCase();
    final normalizedSelectedName = selectedArtistName.trim().toLowerCase();
    final excluded = excludeArtistEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    bool isLicensedArtist(Map<String, dynamic> data) {
      final profile =
          (data['profile'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final credentials =
          (data['credentials'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final nestedCredentials =
          (profile['credentials'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final candidates = <Object?>[
        credentials['nailTechType'],
        nestedCredentials['nailTechType'],
        profile['nailTechType'],
        data['panel_nailTechType'],
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
      final isUnlicensed =
          type.contains('student') ||
          type.contains('non-licensed') ||
          type.contains('unlicensed');
      return !isUnlicensed;
    }

    bool isBrandEligibleArtist(Map<String, dynamic> data) {
      final profile =
          (data['profile'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final basic =
          (data['basic'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final ascension =
          (data['ascension'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final sponsorshipRequest =
          (data['sponsorshipRequest'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final tierCandidates = <Object?>[
        ascension['tier'],
        ascension['levelName'],
        ascension['level'],
        ascension['name'],
        data['sponsorshipTier'],
        sponsorshipRequest['tier'],
        profile['ascensionTier'],
        profile['tier'],
        basic['ascensionTier'],
        basic['tier'],
        data['panel_ascensionLevel'],
        data['panel_ascensionTier'],
        data['ascensionTier'],
        data['tier'],
      ];
      for (final raw in tierCandidates) {
        final tier = (raw ?? '')
            .toString()
            .trim()
            .toLowerCase()
            .replaceAll('_', ' ')
            .replaceAll('-', ' ');
        if (tier == 'goldsmith' || tier == 'crowned') return true;
        if (tier.contains('goldsmith') || tier.contains('crowned')) return true;
      }
      final eligibleCandidates = <Object?>[
        ascension['sponsorshipEligible'],
        data['panel_brandEligible'],
        profile['sponsorshipEligible'],
        basic['sponsorshipEligible'],
        data['brandEligible'],
        data['isBrandEligible'],
      ];
      for (final raw in eligibleCandidates) {
        if (_asBool(raw, fallback: false)) return true;
      }
      return false;
    }

    Future<void> scanCollection(String collection) async {
      final snap = await db.collection(collection).get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final email = ((data['email'] ?? '') as Object).toString().trim().toLowerCase();
        if (email.isEmpty) continue;
        if (excluded.contains(email)) continue;
        final name = ((data['name'] ?? data['displayName'] ?? '') as Object)
            .toString()
            .trim()
            .toLowerCase();
        final notifications =
            (data['notifications'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
        final allEnabled = _asBool(
          data['panel_allClientRequestNotificationsEnabled'] ??
              notifications['allClientRequestsEnabled'],
          fallback: true,
        );
        final directEnabled = _asBool(
          notifications['directRequestNotificationsEnabled'],
          fallback: true,
        );

        if (isDirectRequest) {
          if (requireBrandEligible && !isBrandEligibleArtist(data)) continue;
          final emailMatch =
              normalizedSelected.isNotEmpty && email == normalizedSelected;
          final nameMatch = normalizedSelected.isEmpty &&
              normalizedSelectedName.isNotEmpty &&
              name == normalizedSelectedName;
          if ((emailMatch || nameMatch) && directEnabled) {
            targets.add(email);
          }
        } else {
          if (!allowNonLicensed && !isLicensedArtist(data)) continue;
          if (requireBrandEligible && !isBrandEligibleArtist(data)) continue;
          if (allEnabled) {
            targets.add(email);
          }
        }
      }
    }

    await scanCollection('artist');
    await scanCollection('client_artist');

    if (isDirectRequest && normalizedSelected.isNotEmpty && targets.isEmpty) {
      if (!excluded.contains(normalizedSelected)) {
        targets.add(normalizedSelected);
      }
    }
    return targets;
  }

  static Future<Set<String>> _loadAdminEmails() async {
    final db = FirebaseFirestore.instance;
    final out = <String>{};

    String pickEmail(Map<String, dynamic> data) {
      final profile =
          (data['profile'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final basic =
          (data['basic'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      final candidates = <Object?>[
        data['email'],
        data['adminEmail'],
        data['contactEmail'],
        profile['email'],
        basic['email'],
      ];
      for (final raw in candidates) {
        final email = (raw ?? '').toString().trim().toLowerCase();
        if (email.contains('@')) return email;
      }
      return '';
    }

    bool isAdminLike(Map<String, dynamic> data) {
      final role = (data['role'] ?? data['userRole'] ?? data['type'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (role.contains('admin')) return true;
      final roles = (data['roles'] is List)
          ? (data['roles'] as List)
          : const <dynamic>[];
      for (final raw in roles) {
        final item = raw.toString().trim().toLowerCase();
        if (item.contains('admin')) return true;
      }
      return false;
    }

    Future<void> scanCollection(
      String name, {
      bool requireAdminRole = false,
    }) async {
      try {
        final snap = await db.collection(name).get();
        for (final doc in snap.docs) {
          final data = doc.data();
          if (requireAdminRole && !isAdminLike(data)) continue;
          final email = pickEmail(data);
          if (email.isNotEmpty) out.add(email);
        }
      } catch (_) {}
    }

    await scanCollection('admin');
    await scanCollection('admins');
    await scanCollection('users', requireAdminRole: true);
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

    await FirebaseFirestore.instance.collection('mail').add({
      'to': <String>[normalized],
      'message': {
        'subject': subject,
        'text': text,
        if (html != null && html.trim().isNotEmpty) 'html': html.trim(),
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

    await FirebaseFirestore.instance.collection('mail').add({
      // Keep recipient shape consistent with queueEmail (Firebase Trigger Email extension compatible).
      'to': <String>[normalized],
      // Backward-compatible single recipient field for any custom readers.
      'toEmail': normalized,
      'template': {
        'name': templateName.trim(),
        'data': data,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> queueSms({
    required String to,
    required String text,
  }) async {
    final normalized = to.trim();
    if (normalized.isEmpty) return;

    await FirebaseFirestore.instance.collection('sms_outbox').add({
      'to': normalized,
      'message': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
