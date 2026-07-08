import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client_request_v2.dart';
import '../models/client_profile_models.dart';
import '../theme/app_colors.dart';
import '../services/notifications_service.dart';
import '../widgets/company_shell_chrome.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/jnt_standard_app_bar.dart';
import 'client_custom_request_page.dart';
import 'notifications_page.dart';
import 'simple_status_request_sheet.dart';
import 'track_order_page.dart';
import 'order_details_pages.dart';
import 'artist_reviews_page.dart';

enum OrdersAudience { client, clientArtist, brand }


class SubmittedOrderClientSummary {
  const SubmittedOrderClientSummary({
    this.clientId = '',
    this.clientName = '',
    this.clientEmail = '',
    this.responseStatus = '',
    this.nailShape = '',
    this.nailLength = '',
    this.leftHandDimensions = const <String, String>{},
    this.rightHandDimensions = const <String, String>{},
  });

  final String clientId;
  final String clientName;
  final String clientEmail;
  final String responseStatus;
  final String nailShape;
  final String nailLength;
  final Map<String, String> leftHandDimensions;
  final Map<String, String> rightHandDimensions;
}

class SubmittedClientRequestSummary {
  const SubmittedClientRequestSummary({
    required this.id,
    required this.sourceCollection,
    this.orderNumber = '',
    this.requestNumber = '',
    this.clientEmail = '',
    this.clientName = '',
    this.contactName = '',
    this.campaignName = '',
    this.selectedArtist = '',
    this.acceptedByArtistName = '',
    this.acceptedByArtistEmail = '',
    this.acceptedByClientEmail = '',
    this.clientResponseStatus = '',
    this.directClientStatus = '',
    this.status = 'pending',
    this.orderType = 'single',
    this.description = '',
    this.descriptionPreview = '',
    this.cancelReason = '',
    this.needByDisplay = '',
    this.requestAcceptByDisplay = '',
    this.nailShape = '',
    this.nailLength = '',
    this.paymentStatus = '',
    this.paymentLink = '',
    this.shippedByCourier = '',
    this.trackingNumber = '',
    this.completionReviewStatus = '',
    this.completionDeclineReason = '',
    this.completionDeclineDescription = '',
    this.designApprovalStatus = '',
    this.clientReviewText = '',
    this.clientRating,
    this.artistFinalAmount,
    this.budgetMin,
    this.budgetMax,
    this.clientSubmittedAt,
    this.needBy,
    this.requestAcceptBy,
    this.paidAt,
    this.cancelledAt,
    this.shippedAt,
    this.deliveredAt,
    this.designApprovedAt,
    this.designSubmittedAt,
    this.designApprovalDueAt,
    this.designReminderSentAt,
    this.completionDeclinedAt,
    this.clientReviewSubmittedAt,
    this.inspirationPhotos = const <String>[],
    this.artistCompletedPhotos = const <String>[],
    this.designPreviewPhotos = const <String>[],
    this.leftHandDimensions = const <String, String>{},
    this.rightHandDimensions = const <String, String>{},
    this.groupClients = const <SubmittedOrderClientSummary>[],
    this.declinedByClientEmails = const <String>[],
    this.declinedByArtistEmails = const <String>[],
    this.clientProfileImage = '',
    this.artistProfileImage = '',
  });

  final String id;
  final String sourceCollection;
  final String orderNumber;
  final String requestNumber;
  final String clientEmail;
  final String clientName;
  final String contactName;
  final String campaignName;
  final String selectedArtist;
  final String acceptedByArtistName;
  final String acceptedByArtistEmail;
  final String acceptedByClientEmail;
  final String clientResponseStatus;
  final String directClientStatus;
  final String status;
  final String orderType;
  final String description;
  final String descriptionPreview;
  final String cancelReason;
  final String needByDisplay;
  final String requestAcceptByDisplay;
  final String nailShape;
  final String nailLength;
  final String paymentStatus;
  final String paymentLink;
  final String shippedByCourier;
  final String trackingNumber;
  final String completionReviewStatus;
  final String completionDeclineReason;
  final String completionDeclineDescription;
  final String designApprovalStatus;
  final String clientReviewText;
  final int? clientRating;
  final num? artistFinalAmount;
  final int? budgetMin;
  final int? budgetMax;
  final DateTime? clientSubmittedAt;
  final DateTime? needBy;
  final DateTime? requestAcceptBy;
  final DateTime? paidAt;
  final DateTime? cancelledAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? designApprovedAt;
  final DateTime? designSubmittedAt;
  final DateTime? designApprovalDueAt;
  final DateTime? designReminderSentAt;
  final DateTime? completionDeclinedAt;
  final DateTime? clientReviewSubmittedAt;
  final List<String> inspirationPhotos;
  final List<String> artistCompletedPhotos;
  final List<String> designPreviewPhotos;
  final Map<String, String> leftHandDimensions;
  final Map<String, String> rightHandDimensions;
  final List<SubmittedOrderClientSummary> groupClients;
  final List<String> declinedByClientEmails;
  final List<String> declinedByArtistEmails;
  final String clientProfileImage;
  final String artistProfileImage;
}

class _SupabaseOrderService {
  static final SupabaseClient _db = Supabase.instance.client;

  static String tableForCollection(String collection) {
    switch (collection) {
      case 'Company_Custom_Requests':
      case 'company_custom_requests':
        return 'company_custom_requests';
      case 'Client_Custom_Requests':
      case 'client_custom_requests':
      default:
        return 'client_custom_requests';
    }
  }

  static String collectionForTable(String table) {
    return table == 'company_custom_requests'
        ? 'Company_Custom_Requests'
        : 'Client_Custom_Requests';
  }

  static Map<String, dynamic> asMap(Object? value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return <String, dynamic>{};
  }

  static List<String> asStringList(Object? value) {
    if (value is List) {
      return value.map((e) => (e ?? '').toString()).where((e) => e.trim().isNotEmpty).toList(growable: false);
    }
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? const <String>[] : <String>[text];
  }

  static DateTime? asDate(Object? value) {
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static String pickText(List<Object?> values) {
    for (final v in values) {
      final text = (v ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static int? asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse((value ?? '').toString());
  }

  static num? asNum(Object? value) {
    if (value is num) return value;
    return num.tryParse((value ?? '').toString());
  }

  static Future<Map<String, dynamic>> getRequest(String collection, String id) async {
    final table = tableForCollection(collection);
    final row = await _db.from(table).select().eq('id', id).maybeSingle();
    return asMap(row);
  }

  static Future<List<SubmittedClientRequestSummary>> loadRequestsForClient({
    required String clientEmail,
    required String alternateClientEmail,
    required String clientName,
    String? userUid,
  }) async {
    final emails = <String>{
      clientEmail.trim().toLowerCase(),
      alternateClientEmail.trim().toLowerCase(),
    }..removeWhere((e) => e.isEmpty);
    final uid = (userUid ?? '').trim();
    final name = clientName.trim().toLowerCase();

    Future<Map<String, Map<String, dynamic>>> loadDetails(String table) async {
      final result = <String, Map<String, dynamic>>{};
      try {
        final rows = await _db.from(table).select();
        for (final raw in rows) {
          final row = asMap(raw);
          final requestId = (row['request_id'] ?? '').toString().trim();
          if (requestId.isEmpty) continue;
          final data = asMap(row['data']);
          if (data.isEmpty) continue;
          final detailKey = (row['detail_key'] ?? '').toString().trim();
          final existing = result[requestId] ?? <String, dynamic>{};
          final merged = <String, dynamic>{
            ...existing,
            ...data,
          };
          if (detailKey.isNotEmpty) {
            merged[detailKey] = <String, dynamic>{
              ...asMap(existing[detailKey]),
              ...data,
            };
          }
          result[requestId] = merged;
        }
      } catch (_) {}
      return result;
    }

    final clientDetails = await loadDetails('client_custom_requests_details');
    final brandDetails = await loadDetails('company_custom_requests_details');

    Future<List<Map<String, dynamic>>> fetchMergedRows(
      String table,
      Map<String, Map<String, dynamic>> detailsById,
    ) async {
      final rows = await _db
          .from(table)
          .select()
          .order('created_at', ascending: false);
      final out = <Map<String, dynamic>>[];
      for (final raw in rows) {
        final row = asMap(raw);
        final id = (row['id'] ?? '').toString().trim();
        final detail = detailsById[id];
        if (detail != null && detail.isNotEmpty) {
          final mergedDetails = <String, dynamic>{
            ...asMap(row['details']),
            ...detail,
          };
          final mergedPayload = <String, dynamic>{
            ...asMap(row['payload']),
            ...asMap(detail['payload']),
            ...detail,
          };
          row['details'] = mergedDetails;
          row['payload'] = mergedPayload;
        }
        out.add(row);
      }
      return out;
    }

    final clientRows = await fetchMergedRows(
      'client_custom_requests',
      clientDetails,
    );
    final brandRows = await fetchMergedRows(
      'company_custom_requests',
      brandDetails,
    );

    bool belongs(Map<String, dynamic> row) {
      final summary = asMap(row['summary']);
      final details = asMap(row['details']);
      final payload = asMap(row['payload']);
      
      final requestDetails = asMap(row['request_details']);
      final detailsOrder = asMap(details['order']);
      final payloadOrder = asMap(payload['order']);
      final acceptance = <String, dynamic>{
        ...asMap(summary['acceptance']),
        ...asMap(details['acceptance']),
        ...asMap(payload['acceptance']),
      };
      final allEmailCandidates = <String>{
        (row['client_email'] ?? '').toString(),
        (row['selected_client_email'] ?? '').toString(),
        (summary['clientEmail'] ?? '').toString(),
        (summary['selectedClientEmail'] ?? '').toString(),
        (details['clientEmail'] ?? '').toString(),
        (details['selectedClientEmail'] ?? '').toString(),
        (payload['clientEmail'] ?? '').toString(),
        (payload['selectedClientEmail'] ?? '').toString(),
        (detailsOrder['selectedClientEmail'] ?? '').toString(),
        (payloadOrder['selectedClientEmail'] ?? '').toString(),
        (row['accepted_by_client_email'] ?? '').toString(),
        (summary['acceptedByClientEmail'] ?? '').toString(),
        (details['acceptedByClientEmail'] ?? '').toString(),
        (payload['acceptedByClientEmail'] ?? '').toString(),
        (acceptance['acceptedByClientEmail'] ?? '').toString(),
        (requestDetails['clientEmail'] ?? '').toString(),
      }.map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();

      if (emails.intersection(allEmailCandidates).isNotEmpty) {
        return true;
      }
      final candidates = <String>{
        pickText([row['client_email'], summary['clientEmail'], details['clientEmail'], payload['clientEmail'], requestDetails['clientEmail']]).toLowerCase(),
        pickText([row['selected_client_email'], summary['selectedClientEmail'], details['selectedClientEmail'], payload['selectedClientEmail'], detailsOrder['selectedClientEmail'], payloadOrder['selectedClientEmail']]).toLowerCase(),
        pickText([row['accepted_by_client_email'], summary['acceptedByClientEmail'], details['acceptedByClientEmail'], payload['acceptedByClientEmail'], acceptance['acceptedByClientEmail']]).toLowerCase(),
      }..removeWhere((e) => e.isEmpty);
      if (emails.intersection(candidates).isNotEmpty) return true;
      if (uid.isNotEmpty) {
        final ids = <String>{
          pickText([row['client_id'], row['client_uid'], summary['clientId'], details['clientId'], payload['clientId']]),
          pickText([summary['clientUid'], details['clientUid'], payload['clientUid']]),
          pickText([row['accepted_by_client_id'], summary['acceptedByClientId'], details['acceptedByClientId'], payload['acceptedByClientId'], acceptance['acceptedByClientId']]),
          pickText([row['accepted_by_client_uid'], summary['acceptedByClientUid'], details['acceptedByClientUid'], payload['acceptedByClientUid'], acceptance['acceptedByClientUid']]),
        }..removeWhere((e) => e.isEmpty);
        if (ids.contains(uid)) return true;
      }
      if (name.isNotEmpty) {
        final names = <String>{
          pickText([row['client_name'], summary['clientName'], details['clientName'], payload['clientName']]).toLowerCase(),
          pickText([row['selected_client'], summary['selectedClient'], details['selectedClient'], payload['selectedClient']]).toLowerCase(),
        }..removeWhere((e) => e.isEmpty);
        if (names.contains(name)) return true;
      }
      return false;
    }

    final out = <SubmittedClientRequestSummary>[];
    for (final raw in clientRows) {
      final row = asMap(raw);
      if (belongs(row)) out.add(fromRow(row, 'client_custom_requests'));
    }
    for (final raw in brandRows) {
      final row = asMap(raw);
      if (belongs(row)) out.add(fromRow(row, 'company_custom_requests'));
    }
    return out;
  }

  static SubmittedClientRequestSummary fromRow(Map<String, dynamic> row, String table) {
    final summary = asMap(row['summary']);
    final details = asMap(row['details']);
    final payload = asMap(row['payload']);
    final requestDetails = asMap(row['request_details']);
    final detailsOrder = asMap(details['order']);
    final payloadOrder = asMap(payload['order']);
    final order = <String, dynamic>{
      ...asMap(row['order']),
      ...detailsOrder,
      ...payloadOrder,
    };
    final acceptance = <String, dynamic>{
      ...asMap(summary['acceptance']),
      ...asMap(details['acceptance']),
      ...asMap(payload['acceptance']),
    };
    final payment = asMap(row['payment']);
    final shipping = asMap(row['shipping']);
    final review = asMap(row['review']);
    final clientReview = asMap(row['client_review']);
    final designApproval = asMap(row['designApproval']).isNotEmpty ? asMap(row['designApproval']) : asMap(row['design_approval']);
    final completion = asMap(row['completion']);

    String text(List<Object?> values) => pickText(values);
    DateTime? date(List<Object?> values) {
      for (final value in values) {
        final d = asDate(value);
        if (d != null) return d;
      }
      return null;
    }
    int? integer(List<Object?> values) {
      for (final value in values) {
        final i = asInt(value);
        if (i != null) return i;
      }
      return null;
    }
    num? number(List<Object?> values) {
      for (final value in values) {
        final n = asNum(value);
        if (n != null) return n;
      }
      return null;
    }
    List<String> list(List<Object?> values) {
      for (final value in values) {
        final l = asStringList(value);
        if (l.isNotEmpty) return l;
      }
    return const <String>[];
  }

    Map<String, String> stringMap(List<Object?> values) {
      for (final value in values) {
        final m = asMap(value);
        if (m.isNotEmpty) return m.map((k, v) => MapEntry(k, (v ?? '').toString()));
      }
      return const <String, String>{};
    }
    String dimText(Object? value) {
      if (value is num) {
        return value == value.roundToDouble()
            ? value.toInt().toString()
            : value.toString();
      }
      final text = (value ?? '').toString().trim();
      return text;
    }
    Map<String, String> handDimensionMap(
      bool isLeft,
      List<Object?> directValues,
      List<Object?> nestedSources,
    ) {
      final direct = stringMap(directValues);
      if (direct.isNotEmpty) return direct;

      for (final source in nestedSources) {
        final map = asMap(source);
        if (map.isEmpty) continue;
        final nailPreferences = asMap(map['nailPreferences']);
        final dimensions = asMap(nailPreferences['dimensions']).isNotEmpty
            ? asMap(nailPreferences['dimensions'])
            : asMap(map['dimensions']);
        if (dimensions.isEmpty) continue;

        final prefix = isLeft ? 'l' : 'r';
        final hand = <String, String>{
          'thumb': dimText(dimensions['${prefix}Thumb']),
          'index': dimText(dimensions['${prefix}Index']),
          'middle': dimText(dimensions['${prefix}Middle']),
          'ring': dimText(dimensions['${prefix}Ring']),
          'pinky': dimText(dimensions['${prefix}Pinky']),
        };
        if (hand.values.any((value) => value.isNotEmpty)) return hand;
      }

      return const <String, String>{};
    }

    List<SubmittedOrderClientSummary> groupClients() {
      final detailsGroupOrder = asMap(details['groupOrder']);
      final payloadGroupOrder = asMap(payload['groupOrder']);
      final requestGroupOrder = asMap(requestDetails['groupOrder']);
      List<dynamic>? firstNonEmptyList(List<Object?> candidates) {
        for (final candidate in candidates) {
          if (candidate is List && candidate.isNotEmpty) {
            return candidate.cast<dynamic>();
          }
        }
        for (final candidate in candidates) {
          if (candidate is List) {
            return candidate.cast<dynamic>();
          }
        }
        return null;
      }

      final raw = firstNonEmptyList([
        row['group_clients'],
        summary['groupClients'],
        details['groupClients'],
        payload['groupClients'],
        detailsGroupOrder['clients'],
        payloadGroupOrder['clients'],
        requestGroupOrder['clients'],
        order['clients'],
      ]);
      if (raw is! List) return const <SubmittedOrderClientSummary>[];
      return raw.whereType<Object>().map((item) {
        final m = asMap(item);
        final savedNails = asMap(m['savedNails']);
        final draftNails = asMap(m['draftNails']);
        final nailPreferences = savedNails.isNotEmpty
            ? savedNails
            : draftNails;
        return SubmittedOrderClientSummary(
          clientId: text([m['clientId'], m['client_id'], m['id']]),
          clientName: text([m['clientName'], m['client_name'], m['name']]),
          clientEmail: text([m['clientEmail'], m['client_email'], m['email']]),
          responseStatus: text([m['responseStatus'], m['response_status'], m['status']]),
          nailShape: text([
            m['nailShape'],
            m['nail_shape'],
            nailPreferences['shape'],
          ]),
          nailLength: text([
            m['nailLength'],
            m['nail_length'],
            nailPreferences['length'],
          ]),
          leftHandDimensions: handDimensionMap(
            true,
            [m['leftHandDimensions'], m['left_hand_dimensions'], m['leftHand']],
            [m, draftNails, savedNails, nailPreferences],
          ),
          rightHandDimensions: handDimensionMap(
            false,
            [m['rightHandDimensions'], m['right_hand_dimensions'], m['rightHand']],
            [m, draftNails, savedNails, nailPreferences],
          ),
        );
      }).toList(growable: false);
    }

    return SubmittedClientRequestSummary(
      id: text([row['id']]),
      sourceCollection: collectionForTable(table),
      orderNumber: text([row['order_number'], summary['orderNumber'], details['orderNumber'], payload['orderNumber'], row['request_number'], row['client_request_number']]),
      requestNumber: text([row['request_number'], summary['requestNumber'], details['requestNumber'], payload['requestNumber']]),
      clientEmail: text([row['client_email'], summary['clientEmail'], details['clientEmail'], payload['clientEmail']]),
      clientName: text([row['client_name'], summary['clientName'], details['clientName'], payload['clientName']]),
      contactName: text([row['company_name'], row['brand_name'], summary['companyName'], details['companyName'], payload['companyName']]),
      campaignName: text([row['campaign_name'], summary['campaignName'], details['campaignName'], payload['campaignName'], row['title']]),
      selectedArtist: text([
        row['selected_artist'],
        summary['selectedArtist'],
        details['selectedArtist'],
        payload['selectedArtist'],
      ]),
      acceptedByArtistName: text([
        row['accepted_by_artist_name'],
        row['artist_name'],
        summary['acceptedByArtistName'],
        details['acceptedByArtistName'],
        payload['acceptedByArtistName'],
      ]),
      acceptedByArtistEmail: text([
        row['accepted_by_artist_email'],
        row['artist_email'],
        summary['acceptedByArtistEmail'],
        details['acceptedByArtistEmail'],
        payload['acceptedByArtistEmail'],
      ]),
      acceptedByClientEmail: text([
        row['accepted_by_client_email'],
        summary['acceptedByClientEmail'],
        details['acceptedByClientEmail'],
        payload['acceptedByClientEmail'],
        acceptance['acceptedByClientEmail'],
      ]),
      clientResponseStatus: text([
        row['client_response_status'],
        summary['clientResponseStatus'],
        details['clientResponseStatus'],
        payload['clientResponseStatus'],
        acceptance['clientResponseStatus'],
      ]),
      directClientStatus: text([row['direct_client_status'], summary['directClientStatus'], details['directClientStatus'], payload['directClientStatus']]),
      status: text([row['status'], summary['status'], details['status'], payload['status'], 'pending']),
      orderType: text([row['order_type'], summary['orderType'], details['orderType'], payload['orderType'], order['type'], 'single']),
      description: text([row['description'], requestDetails['description'], details['description'], payload['description'], summary['description']]),
      descriptionPreview: text([row['description_preview'], summary['descriptionPreview'], details['descriptionPreview'], payload['descriptionPreview'], row['description']]),
      cancelReason: text([row['cancel_reason'], row['cancelReason'], summary['cancelReason'], details['cancelReason'], payload['cancelReason']]),
      needByDisplay: text([row['need_by_display'], summary['needByDisplay'], details['needByDisplay'], payload['needByDisplay']]),
      requestAcceptByDisplay: text([row['request_accept_by_display'], summary['requestAcceptByDisplay'], details['requestAcceptByDisplay'], payload['requestAcceptByDisplay']]),
      nailShape: text([row['nail_shape'], summary['nailShape'], details['nailShape'], payload['nailShape']]),
      nailLength: text([row['nail_length'], summary['nailLength'], details['nailLength'], payload['nailLength']]),
      paymentStatus: text([row['payment_status'], payment['status'], summary['paymentStatus'], details['paymentStatus'], payload['paymentStatus']]),
      paymentLink: text([row['payment_link'], payment['link'], payment['paymentLink'], details['paymentLink'], payload['paymentLink']]),
      shippedByCourier: text([row['shipped_by_courier'], row['courier'], shipping['courier'], details['shippedByCourier'], payload['shippedByCourier']]),
      trackingNumber: text([row['tracking_number'], shipping['trackingNumber'], details['trackingNumber'], payload['trackingNumber']]),
      completionReviewStatus: text([row['completion_review_status'], completion['reviewStatus'], details['completionReviewStatus'], payload['completionReviewStatus']]),
      completionDeclineReason: text([row['completion_decline_reason'], completion['declineReason'], details['completionDeclineReason'], payload['completionDeclineReason']]),
      completionDeclineDescription: text([row['completion_decline_description'], completion['declineDescription'], details['completionDeclineDescription'], payload['completionDeclineDescription']]),
      designApprovalStatus: text([row['design_approval_status'], designApproval['status'], details['designApprovalStatus'], payload['designApprovalStatus']]),
      clientReviewText: text([row['client_review_comment'], row['review_comment'], clientReview['comment'], review['comment'], details['clientReviewText'], payload['clientReviewText']]),
      clientRating: integer([row['client_review_stars'], row['review_stars'], clientReview['stars'], review['stars'], details['clientRating'], payload['clientRating']]),
      artistFinalAmount: number([row['artist_final_amount'], row['final_amount_by_artist'], payment['artistFinalAmount'], details['artistFinalAmount'], payload['artistFinalAmount']]),
      budgetMin: integer([row['budget_min'], summary['budgetMin'], details['budgetMin'], payload['budgetMin']]),
      budgetMax: integer([row['budget_max'], summary['budgetMax'], details['budgetMax'], payload['budgetMax']]),
      clientSubmittedAt: date([row['created_at'], summary['createdAt'], details['createdAt'], payload['createdAt']]),
      needBy: date([row['need_by'], summary['needBy'], details['needBy'], payload['needBy']]),
      requestAcceptBy: date([row['request_accept_by'], summary['requestAcceptBy'], details['requestAcceptBy'], payload['requestAcceptBy']]),
      paidAt: date([row['paid_at'], payment['paidAt'], details['paidAt'], payload['paidAt']]),
      cancelledAt: date([row['cancelled_at'], row['cancelledAt'], details['cancelledAt'], payload['cancelledAt']]),
      shippedAt: date([row['shipped_at'], shipping['shippedAt'], details['shippedAt'], payload['shippedAt']]),
      deliveredAt: date([row['delivered_at'], shipping['deliveredAt'], details['deliveredAt'], payload['deliveredAt']]),
      designApprovedAt: date([row['design_approved_at'], designApproval['approvedAt'], details['designApprovedAt'], payload['designApprovedAt']]),
      designSubmittedAt: date([row['design_submitted_at'], designApproval['submittedAt'], details['designSubmittedAt'], payload['designSubmittedAt']]),
      designApprovalDueAt: date([row['design_approval_due_at'], designApproval['dueAt'], details['designApprovalDueAt'], payload['designApprovalDueAt']]),
      designReminderSentAt: date([row['design_reminder_sent_at'], designApproval['reminderSentAt'], details['designReminderSentAt'], payload['designReminderSentAt']]),
      completionDeclinedAt: date([row['completion_declined_at'], completion['declinedAt'], details['completionDeclinedAt'], payload['completionDeclinedAt']]),
      clientReviewSubmittedAt: date([row['client_review_submitted_at'], row['review_submitted_at'], clientReview['submittedAt'], review['submittedAt'], details['clientReviewSubmittedAt'], payload['clientReviewSubmittedAt']]),
      inspirationPhotos: list([row['inspiration_photos'], summary['inspirationPhotos'], details['inspirationPhotos'], payload['inspirationPhotos']]),
      artistCompletedPhotos: list([row['artist_completed_photos'], details['artistCompletedPhotos'], payload['artistCompletedPhotos']]),
      designPreviewPhotos: list([row['design_preview_photos'], details['designPreviewPhotos'], payload['designPreviewPhotos']]),
      leftHandDimensions: handDimensionMap(
        true,
        [
          row['left_hand_dimensions'],
          summary['leftHandDimensions'],
          details['leftHandDimensions'],
          payload['leftHandDimensions'],
        ],
        [row, summary, details, payload, requestDetails, order],
      ),
      rightHandDimensions: handDimensionMap(
        false,
        [
          row['right_hand_dimensions'],
          summary['rightHandDimensions'],
          details['rightHandDimensions'],
          payload['rightHandDimensions'],
        ],
        [row, summary, details, payload, requestDetails, order],
      ),
      groupClients: groupClients(),
      declinedByClientEmails: list([row['declined_by_client_emails'], summary['declinedByClientEmails'], details['declinedByClientEmails'], payload['declinedByClientEmails']]),
      declinedByArtistEmails: list([row['declined_by_artist_emails'], summary['declinedByArtistEmails'], details['declinedByArtistEmails'], payload['declinedByArtistEmails']]),
      clientProfileImage: text([row['client_profile_image'], summary['clientProfileImage'], details['clientProfileImage'], payload['clientProfileImage']]),
      artistProfileImage: text([row['artist_profile_image'], summary['artistProfileImage'], details['artistProfileImage'], payload['artistProfileImage']]),
    );
  }

  static Future<String?> resolveStorageUrl(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://') || value.startsWith('data:') || value.startsWith('blob:')) return value;
    if (value.startsWith('gs://')) return null;
    final cleaned = value.startsWith('/') ? value.substring(1) : value;
    final parts = cleaned.split('/');
    if (parts.length < 2) return value;
    final bucket = parts.first;
    final path = parts.sublist(1).join('/');
    try {
      return _db.storage.from(bucket).getPublicUrl(path);
    } catch (_) {
      try {
        return await _db.storage.from(bucket).createSignedUrl(path, 3600);
      } catch (_) {
        return value;
      }
    }
  }
}


class _CompositeStreamSubscription<T> implements StreamSubscription<T> {
  _CompositeStreamSubscription(this._inner, {required this.onCancelExtra});
  final StreamSubscription<T> _inner;
  final Future<void> Function() onCancelExtra;
  @override
  Future<void> cancel() async { await _inner.cancel(); await onCancelExtra(); }
  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);
  @override
  void onError(Function? handleError) => _inner.onError(handleError);
  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);
  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);
  @override
  void resume() => _inner.resume();
  @override
  bool get isPaused => _inner.isPaused;
  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture<E>(futureValue);
}

class ClientOrdersPage extends StatefulWidget {
  const ClientOrdersPage({
    super.key,
    required this.profile,
    this.onBackHome,
    this.showCompanyChrome = false,
    this.companyName,
    this.onOpenProfile,
    this.onOpenEarnings,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onLogout,
    this.showExtendedAvatarMenu = false,
    this.showProfileMenu = false,
    this.bottomNavIndex = 3,
    this.onNavTap,
    this.audience = OrdersAudience.client,
    this.isActiveTab = true,
  });

  final ClientProfileDraft profile;
  final VoidCallback? onBackHome;
  final bool showCompanyChrome;
  final String? companyName;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenEarnings;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final Future<void> Function()? onLogout;
  final bool showExtendedAvatarMenu;
  final bool showProfileMenu;
  final int bottomNavIndex;
  final ValueChanged<int>? onNavTap;
  final OrdersAudience audience;
  final bool isActiveTab;

  @override
  State<ClientOrdersPage> createState() => _ClientOrdersPageState();
}

class _ClientOrdersPageState extends State<ClientOrdersPage> {
  OrdersFilter _filter = OrdersFilter.all;
  StreamSubscription<List<SubmittedClientRequestSummary>>?
  _submittedRequestsSub;
  StreamSubscription<dynamic>? _brandPartnerStatusSub;
  List<ClientOrder> _submittedOrders = const [];
  final FocusNode _notificationsFocusNode = FocusNode(
    debugLabel: 'ordersNotifications',
  );
  bool _didSetInitialA11yFocus = false;
  bool _focusRequestQueued = false;
  @override
  void initState() {
    super.initState();
    unawaited(_listenBrandPartnerStatus());
    _subscribeSubmittedOrders();
    _scheduleInitialA11yFocus();
  }

  @override
  void didUpdateWidget(covariant ClientOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.basic.email != widget.profile.basic.email) {
      _subscribeSubmittedOrders();
    }
    if (!oldWidget.isActiveTab && widget.isActiveTab) {
      _didSetInitialA11yFocus = false;
      _scheduleInitialA11yFocus();

      // Refresh orders whenever user returns to Orders tab.
      _subscribeSubmittedOrders();
    }
  }

  @override
  void dispose() {
    _submittedRequestsSub?.cancel();
    _brandPartnerStatusSub?.cancel();
    _notificationsFocusNode.dispose();
    super.dispose();
  }

  void _scheduleInitialA11yFocus() {
    if (_didSetInitialA11yFocus || _focusRequestQueued || !widget.isActiveTab) {
      return;
    }
    _focusRequestQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _didSetInitialA11yFocus || !widget.isActiveTab) {
        _focusRequestQueued = false;
        return;
      }
      final route = ModalRoute.of(context);
      if (route?.isCurrent != true) {
        _focusRequestQueued = false;
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted || _didSetInitialA11yFocus || !widget.isActiveTab) {
        _focusRequestQueued = false;
        return;
      }
      if (!MediaQuery.of(context).accessibleNavigation) {
        _focusRequestQueued = false;
        return;
      }
      _didSetInitialA11yFocus = true;
      _focusRequestQueued = false;
      _notificationsFocusNode.requestFocus();
    });
  }

  Future<void> _listenBrandPartnerStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    final uid = user?.id;
    final email = (user?.email ?? widget.profile.basic.email).trim().toLowerCase();
    if ((uid == null || uid.isEmpty) && email.isEmpty) return;

    try {
      Map<String, dynamic>? row;
      if (uid != null && uid.isNotEmpty) {
        row = await Supabase.instance.client
            .from('client')
            .select()
            .eq('id', uid)
            .maybeSingle();
        row ??= await Supabase.instance.client
            .from('client_artist')
            .select()
            .eq('id', uid)
            .maybeSingle();
      }
      if (row == null && email.isNotEmpty) {
        row = await Supabase.instance.client
            .from('client')
            .select()
            .ilike('email', email)
            .maybeSingle();
        row ??= await Supabase.instance.client
            .from('client_artist')
            .select()
            .ilike('email', email)
            .maybeSingle();
      }
    } catch (_) {}
  }

  void _subscribeSubmittedOrders() {
    _submittedRequestsSub?.cancel();
    final authEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    final profileEmail = widget.profile.basic.email.trim().toLowerCase();
    final effectiveEmail = profileEmail.isNotEmpty ? profileEmail : authEmail;
    final profileName = widget.profile.basic.name.trim();
    final effectiveName = profileName.isNotEmpty
        ? profileName
        : ((widget.companyName ?? '').trim());
    final currentUserEmail = authEmail.isNotEmpty ? authEmail : effectiveEmail;
    final controller = StreamController<List<SubmittedClientRequestSummary>>();
    var cancelled = false;

    Future<void> load() async {
      try {
        final items = await _SupabaseOrderService.loadRequestsForClient(
          clientEmail: effectiveEmail,
          alternateClientEmail: authEmail,
          clientName: effectiveName,
          userUid: Supabase.instance.client.auth.currentUser?.id,
        );
        if (!cancelled && !controller.isClosed) controller.add(items);
      } catch (e, st) {
        if (!cancelled && !controller.isClosed) controller.addError(e, st);
      }
    }

    unawaited(load());
    final realtimeSub = Supabase.instance.client
        .channel('client-orders-${effectiveEmail.hashCode}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'client_custom_requests',
          callback: (_) => unawaited(load()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'company_custom_requests',
          callback: (_) => unawaited(load()),
        )
        .subscribe();

    _submittedRequestsSub = controller.stream.listen((items) {
      final filteredItems = items
          .where(
            (req) =>
                _isVisibleForAudience(req, widget.audience) &&
                !_shouldHideFromClientArtistOrders(req, currentUserEmail),
          )
          .toList(growable: false);
      unawaited(_syncExpiredRequests(filteredItems));
      final orders = filteredItems
          .map((req) => _mapSubmittedRequestToOrder(req, currentUserEmail))
          .toList()
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
            a.createdAt ?? DateTime(1970),
          ),
        );
      if (!mounted) return;
      setState(() => _submittedOrders = orders);
    }, onError: (_) {
      if (!mounted) return;
      setState(() => _submittedOrders = const []);
    });

    _submittedRequestsSub = _CompositeStreamSubscription(
      _submittedRequestsSub!,
      onCancelExtra: () async {
        cancelled = true;
        await Supabase.instance.client.removeChannel(realtimeSub);
        await controller.close();
      },
    );
  }

  bool _isVisibleForAudience(
    SubmittedClientRequestSummary req,
    OrdersAudience audience,
  ) {
    switch (audience) {
      case OrdersAudience.brand:
        return req.sourceCollection == 'Company_Custom_Requests';

      case OrdersAudience.client:
      case OrdersAudience.clientArtist:
        return req.sourceCollection == 'Client_Custom_Requests' ||
            req.sourceCollection == 'Company_Custom_Requests';
    }
  }

  bool _shouldHideFromClientArtistOrders(
    SubmittedClientRequestSummary req,
    String currentUserEmail,
  ) {
    if (widget.audience != OrdersAudience.clientArtist) return false;
    final normalizedCurrent = currentUserEmail.trim().toLowerCase();
    if (normalizedCurrent.isEmpty) return false;
    final acceptedByArtist = req.acceptedByArtistEmail.trim().toLowerCase();
    return acceptedByArtist.isNotEmpty && acceptedByArtist == normalizedCurrent;
  }

  Future<void> _syncExpiredRequests(
    List<SubmittedClientRequestSummary> items,
  ) async {
    final now = DateTime.now();
    for (final req in items) {
      final raw = req.status.trim().toLowerCase();
      final terminal =
          raw == 'expired' ||
          raw == 'cancelled' ||
          raw == 'canceled' ||
          raw == 'declined' ||
          raw == 'delivered' ||
          raw == 'shipped';
      if (terminal) continue;
      final sourceCollection = req.sourceCollection.trim();
      final isBrandRequest = sourceCollection == 'Company_Custom_Requests';
      final acceptBy = req.requestAcceptBy ?? req.needBy;
      final pastAcceptBy =
          acceptBy != null &&
          now.isAfter(
            DateTime(
              acceptBy.year,
              acceptBy.month,
              acceptBy.day,
            ).add(const Duration(days: 1)),
          );
      if (!isBrandRequest) {
        final artistAccepted = req.acceptedByArtistEmail.trim().isNotEmpty;
        if (artistAccepted) continue;
        final due = req.needBy;
        if (due == null) continue;
        final pastDue = now.isAfter(
          DateTime(due.year, due.month, due.day).add(const Duration(days: 1)),
        );
        if (!pastDue) continue;
      } else {
        if (!pastAcceptBy) continue;
      }

      try {
        final collection = req.sourceCollection.trim().isNotEmpty
            ? req.sourceCollection.trim()
            : 'Client_Custom_Requests';
        final table = _SupabaseOrderService.tableForCollection(collection);
        final current = await _SupabaseOrderService.getRequest(collection, req.id);
        String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
          for (final value in values) {
            final text = (value ?? '').toString().trim();
            if (text.isNotEmpty) return text;
          }
          return fallback;
        }

        final acceptedClientEmail = firstNonEmpty(<Object?>[
          current['acceptedByClientEmail'],
          req.acceptedByClientEmail,
        ]).toLowerCase();
        final currentStatus = ((current['status'] ?? '') as Object)
            .toString()
            .trim()
            .toLowerCase();
        final acceptByLabel = req.requestAcceptByDisplay.trim().isNotEmpty
            ? req.requestAcceptByDisplay.trim()
            : (acceptBy == null
                  ? ''
                  : '${acceptBy.month.toString().padLeft(2, '0')}/${acceptBy.day.toString().padLeft(2, '0')}/${acceptBy.year}');
        final cancellationReason = isBrandRequest
            ? 'Request was not accepted/rejected by $acceptByLabel'
            : 'Request was not accepted by artist, and it is past due.';
        if (currentStatus == 'expired' &&
            current['expiredNotifiedClient'] == true &&
            (!isBrandRequest ||
                (current['expiredNotifiedBrandAdmin'] == true &&
                    (acceptedClientEmail.isEmpty ||
                        current['expiredNotifiedAcceptedClient'] == true)))) {
          continue;
        }
        final nowIso = DateTime.now().toIso8601String();
        final updatePayload = <String, dynamic>{
          'status': isBrandRequest ? 'cancelled' : 'expired',
          if (isBrandRequest) 'cancel_reason': cancellationReason,
          if (isBrandRequest) 'cancelled_at': nowIso,
          if (!isBrandRequest) 'expired_at': nowIso,
          'expired_notified_client': true,
          if (isBrandRequest) 'expired_notified_brand_admin': true,
          if (isBrandRequest && acceptedClientEmail.isNotEmpty)
            'expired_notified_accepted_client': true,
          'updated_at': nowIso,
        };
        final details = _SupabaseOrderService.asMap(current['details']);
        final payload = _SupabaseOrderService.asMap(current['payload']);
        details.addAll(<String, dynamic>{
          'status': isBrandRequest ? 'cancelled' : 'expired',
          if (isBrandRequest) 'cancelReason': cancellationReason,
          if (isBrandRequest) 'cancelledAt': nowIso,
          if (!isBrandRequest)
            'expiredReason':
                'Request was not accepted by artist, and it is past due.',
        });
        payload.addAll(details);
        updatePayload['details'] = details;
        updatePayload['payload'] = payload;
        await Supabase.instance.client.from(table).update(updatePayload).eq('id', req.id);

        if (!isBrandRequest && (req.clientEmail).trim().isNotEmpty) {
          await NotificationsService.createUserNotification(
            receiverEmail: req.clientEmail.trim().toLowerCase(),
            title: 'Request Expired',
            body: 'Your request is expired. Please resubmit',
            type: 'request_expired',
            orderId: req.id,
            orderNumber: req.orderNumber,
            sourceCollection: collection,
          );
        }

        if (isBrandRequest) {
          final campaignName = firstNonEmpty(<Object?>[
            current['campaignName'],
            current['title'],
            req.campaignName,
          ], fallback: 'Campaign');
          final brandCompany = firstNonEmpty(<Object?>[
            current['companyName'],
            current['brandName'],
            req.contactName,
          ], fallback: 'Brand Company');
          final orderRef = req.orderNumber.trim().isNotEmpty
              ? req.orderNumber.trim()
              : req.id;

          final brandRecipientEmails =
              await NotificationsService.resolveBrandRecipientEmails(
                rootData: current,
                excludeEmails: <String>[acceptedClientEmail],
              );

          for (final brandEmail in brandRecipientEmails) {
            await NotificationsService.createUserNotification(
              receiverEmail: brandEmail,
              title: 'Brand Request Cancelled',
              body:
                  'Your $campaignName brand request $orderRef has been cancelled $cancellationReason',
              type: 'brand_request_cancelled_by_timeout',
              orderId: req.id,
              orderNumber: req.orderNumber,
              sourceCollection: collection,
              extra: <String, dynamic>{'reason': cancellationReason},
            );
          }

          final clientEmail = req.clientEmail.trim().toLowerCase();
          if (clientEmail.isNotEmpty) {
            await NotificationsService.createUserNotification(
              receiverEmail: clientEmail,
              title: 'Brand Request Cancelled',
              body:
                  'Your $brandCompany $campaignName brand request $orderRef has been cancelled $cancellationReason',
              type: 'client_brand_request_cancelled_by_timeout',
              orderId: req.id,
              orderNumber: req.orderNumber,
              sourceCollection: collection,
              extra: <String, dynamic>{'reason': cancellationReason},
            );
          }

          await NotificationsService.notifyAdmins(
            title: 'Brand Request Cancelled',
            body:
                '$brandCompany $campaignName brand request $orderRef has been cancelled $cancellationReason',
            type: 'admin_brand_request_cancelled_by_timeout',
            orderId: req.id,
            orderNumber: req.orderNumber,
            sourceCollection: collection,
            extra: <String, dynamic>{'reason': cancellationReason},
          );
        }
      } catch (_) {}
    }
  }

  ClientOrder _mapSubmittedRequestToOrder(
    SubmittedClientRequestSummary req,
    String currentUserEmail,
  ) {
    final submittedAt = req.clientSubmittedAt;
    final submittedText = submittedAt == null
        ? 'Submitted'
        : 'Submitted ${_monthShort(submittedAt.month)} ${submittedAt.day}';
    final clientName = widget.profile.basic.name.trim().isNotEmpty
        ? widget.profile.basic.name.trim()
        : 'Client';

    final normalizedRawStatus = req.status.trim().toLowerCase();
    final acceptedByClientEmail = req.acceptedByClientEmail
        .trim()
        .toLowerCase();
    final clientResponseStatus = req.clientResponseStatus.trim().toLowerCase();
    final isGroupOrder = req.orderType.trim().toLowerCase() == 'group';
    final acceptedByCurrentClient =
        ((acceptedByClientEmail.isNotEmpty &&
            acceptedByClientEmail == currentUserEmail.trim().toLowerCase()) ||
        (!isGroupOrder && clientResponseStatus == 'accepted'));
    final declinedByCurrentClient =
        req.declinedByClientEmails
            .map((e) => e.trim().toLowerCase())
            .contains(currentUserEmail.trim().toLowerCase()) ||
        (!isGroupOrder && clientResponseStatus == 'declined');
    final cancelledByClientReason =
        req.cancelReason.trim().toLowerCase().startsWith(
          'cancelled by client on ',
        ) ||
        req.cancelReason.trim().toLowerCase() == 'cancelled by client.' ||
        req.cancelReason.trim().toLowerCase() == 'cancelled by client';
    final hasStaleClientAcceptance =
        acceptedByCurrentClient && declinedByCurrentClient;
    final isBrandAudience = widget.audience == OrdersAudience.brand;
    final directClientDeclined =
        req.directClientStatus.trim().toLowerCase() == 'declined';
    final isTerminalRawStatus =
        normalizedRawStatus == 'cancelled' ||
        normalizedRawStatus == 'canceled' ||
        normalizedRawStatus == 'declined' ||
        normalizedRawStatus == 'expired' ||
        normalizedRawStatus == 'delivered' ||
        normalizedRawStatus == 'shipped';
    String effectiveRawStatus = normalizedRawStatus;
    if (req.sourceCollection == 'Company_Custom_Requests' &&
        isBrandAudience &&
        directClientDeclined) {
      effectiveRawStatus = 'declined';
    } else if (req.sourceCollection == 'Company_Custom_Requests' &&
        declinedByCurrentClient &&
        cancelledByClientReason) {
      effectiveRawStatus = 'cancelled';
    } else if (req.sourceCollection == 'Company_Custom_Requests' &&
        declinedByCurrentClient) {
      effectiveRawStatus = 'declined';
    } else if (req.sourceCollection == 'Company_Custom_Requests' &&
        !isTerminalRawStatus &&
        !hasStaleClientAcceptance &&
        acceptedByCurrentClient) {
      effectiveRawStatus = 'pending';
    }

    final mappedStatus = _resolveOrderStatus(
      req,
      rawStatusOverride: effectiveRawStatus,
    );
    final acceptedFinalAmount = req.artistFinalAmount;
    final hasAcceptedFinalAmount =
        acceptedFinalAmount != null &&
        acceptedFinalAmount > 0 &&
        (mappedStatus == OrderStatus.inProgress ||
            mappedStatus == OrderStatus.shipped ||
            mappedStatus == OrderStatus.delivered);
    final acceptedAmountInt = hasAcceptedFinalAmount
        ? acceptedFinalAmount.round()
        : null;

    final statusText = _statusLabelForCard(
      req: req,
      status: mappedStatus,
      submittedFallback: submittedText,
    );
    final selectedArtistName = _normalizeSelectedArtistName(req.selectedArtist);

    return ClientOrder(
      id: req.id,
      sourceCollection: req.sourceCollection,
      rawStatus: effectiveRawStatus,
      orderNumber: req.orderNumber,
      brandName: req.sourceCollection == 'Company_Custom_Requests'
          ? req.contactName
          : '',
      campaignName: req.sourceCollection == 'Company_Custom_Requests'
          ? req.campaignName
          : '',
      title: clientName,
      subtitle: req.descriptionPreview,
      hasAssignedArtist: selectedArtistName.isNotEmpty,
      orderType: req.orderType,
      groupClients: req.groupClients
          .map(
            (client) => OrderClientMeasurement(
              clientId: client.clientId,
              clientName: client.clientName,
              clientEmail: client.clientEmail,
              responseStatus: client.responseStatus,
              nailShape: client.nailShape,
              nailLength: client.nailLength,
              leftHandDimensions: client.leftHandDimensions,
              rightHandDimensions: client.rightHandDimensions,
            ),
          )
          .toList(growable: false),
      clientDescription: req.description.isNotEmpty
          ? req.description
          : req.descriptionPreview,
      cancelReason: req.cancelReason,
      inspirationPhotos: req.inspirationPhotos,
      needByDisplay: req.needByDisplay,
      nailShape: req.nailShape,
      nailLength: req.nailLength,
      budgetMin: req.budgetMin,
      budgetMax: req.budgetMax,
      leftHandDimensions: req.leftHandDimensions,
      rightHandDimensions: req.rightHandDimensions,
      status: mappedStatus,
      expectedOrDeliveredText: statusText,
      imageAsset: _safeCardAvatar(profileImage: req.clientProfileImage),
      artistName: req.acceptedByArtistName.isNotEmpty
          ? req.acceptedByArtistName
          : req.selectedArtist,
      selectedArtistName: selectedArtistName,
      artistProfileImage: req.artistProfileImage,
      createdAt: submittedAt,
      artistAcceptedAmount: acceptedAmountInt,
      paymentStatus: req.paymentStatus,
      paymentLink: req.paymentLink,
      paidAt: req.paidAt,
      clientProfileImage: req.clientProfileImage,
      artistCompletedPhotos: req.artistCompletedPhotos,
      completionReviewStatus: req.completionReviewStatus,
      completionDeclineReason: req.completionDeclineReason,
      completionDeclineDescription: req.completionDeclineDescription,
      completionDeclinedAt: req.completionDeclinedAt,
      designApprovalStatus: req.designApprovalStatus,
      designApprovedAt: req.designApprovedAt,
      clientDesignApprovedAt: req.designApprovedAt,
      designSubmittedAt: req.designSubmittedAt,
      designApprovalDueAt: req.designApprovalDueAt,
      designReminderSentAt: req.designReminderSentAt,
      designPreviewPhotos: req.designPreviewPhotos,
      clientEmail: req.clientEmail,
      acceptedByArtistEmail: req.acceptedByArtistEmail,
      declinedByClientEmails: req.declinedByClientEmails,
      declinedByArtistEmails: req.declinedByArtistEmails,
      directClientStatus: req.directClientStatus,
      rating: req.clientRating?.toDouble(),
      reviewText: req.clientReviewText,
      reviewSubmittedAt: req.clientReviewSubmittedAt,
      cancelledAt: req.cancelledAt,
      needBy: req.needBy,
      shippedByCourier: req.shippedByCourier,
      trackingNumber: req.trackingNumber,
      shippedAt: req.shippedAt,
      deliveredAt: req.deliveredAt,
    );
  }

  String _normalizeSelectedArtistName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return '';
    final lower = name.toLowerCase();
    if (lower == 'artist' ||
        lower == 'select one' ||
        lower == 'n/a' ||
        lower == '-') {
      return '';
    }
    return name;
  }

  OrderStatus _resolveOrderStatus(
    SubmittedClientRequestSummary req, {
    String? rawStatusOverride,
  }) {
    final mapped = _statusFromRequestStatus(rawStatusOverride ?? req.status);

    if (mapped == OrderStatus.cancelled ||
        mapped == OrderStatus.shipped ||
        mapped == OrderStatus.delivered ||
        mapped == OrderStatus.expired) {
      return mapped;
    }

    final accepted =
        req.acceptedByArtistEmail.trim().isNotEmpty ||
        (req.artistFinalAmount != null && req.artistFinalAmount! > 0);

    if (accepted) {
      return OrderStatus.inProgress;
    }

    final due = req.needBy;
    final isPastDue =
        due != null &&
        DateTime.now().isAfter(
          DateTime(due.year, due.month, due.day).add(const Duration(days: 1)),
        );

    if (isPastDue) {
      return OrderStatus.expired;
    }

    return mapped;
  }

  String _statusLabelForCard({
    required SubmittedClientRequestSummary req,
    required OrderStatus status,
    required String submittedFallback,
  }) {
    if (status == OrderStatus.expired) {
      final due = req.needBy;
      if (due != null) {
        return 'Expired ${_monthShort(due.month)} ${due.day}, ${due.year}';
      }
      return 'Expired';
    }

    if (status == OrderStatus.cancelled) {
      final cancelledAt = req.cancelledAt;
      final when = cancelledAt == null
          ? 'Cancelled'
          : 'Cancelled ${_monthShort(cancelledAt.month)} ${cancelledAt.day}, ${cancelledAt.year}';
      final reason = req.cancelReason.trim();
      if (reason.isNotEmpty) {
        return '$when • Reason: $reason';
      }
      return when;
    }

    return submittedFallback;
  }

  String _pickProfileImage(String raw) {
    final p = raw.trim();
    if (p.isEmpty) return '';
    if (p.startsWith('http://') ||
        p.startsWith('https://') ||
        p.startsWith('gs://') ||
        p.startsWith('blob:') ||
        p.startsWith('data:') ||
        p.startsWith('content://') ||
        p.startsWith('file://') ||
        p.startsWith('assets/')) {
      return p;
    }
    if (!kIsWeb && (p.startsWith('/') || p.contains(':\\'))) {
      return p;
    }
    return '';
  }

  String _safeCardAvatar({required String profileImage}) {
    return _pickProfileImage(profileImage);
  }

  OrderStatus _statusFromRequestStatus(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'pending':
      case 'submitted':
      case 'new':
      case 'new_request':
      case 'newrequest':
        return OrderStatus.inReview;
      case 'in_review':
      case 'in review':
      case 'inreview':
        return OrderStatus.inReview;
      case 'in_progress':
      case 'in progress':
      case 'inprogress':
      case 'accepted':
      case 'designing':
      case 'completed':
        return OrderStatus.inProgress;
      case 'shipped':
        return OrderStatus.shipped;
      case 'delivered':
        return OrderStatus.delivered;
      case 'expired':
        return OrderStatus.expired;
      case 'cancelled':
      case 'canceled':
        return OrderStatus.cancelled;
      case 'declined':
        return OrderStatus.declined;
      default:
        return OrderStatus.inReview;
    }
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

  List<ClientOrder> get _orders {
    return _submittedOrders;
  }

  List<ClientOrder> get _filteredOrders {
    switch (_filter) {
      case OrdersFilter.all:
        return _orders;
      case OrdersFilter.pending:
        return _orders.where(_isSubmittedOrder).toList(growable: false);
      case OrdersFilter.submitted:
        return _orders.where(_isSubmittedOrder).toList();
      case OrdersFilter.inProgress:
        return _orders
            .where((o) => o.status == OrderStatus.inProgress)
            .toList();
      case OrdersFilter.shipped:
        return _orders.where((o) => o.status == OrderStatus.shipped).toList();
      case OrdersFilter.delivered:
        return _orders.where((o) => o.status == OrderStatus.delivered).toList();
      case OrdersFilter.declined:
        return _orders.where((o) => o.status == OrderStatus.declined).toList();
      case OrdersFilter.cancelledExpired:
        return _orders
            .where(
              (o) =>
                  o.status == OrderStatus.cancelled ||
                  o.status == OrderStatus.expired,
            )
            .toList();
    }
  }

  bool _isSubmittedOrder(ClientOrder order) =>
      order.status == OrderStatus.newOrder ||
      order.status == OrderStatus.inReview;

  // Pending = Submitted + In Progress + Shipped
  List<ClientOrder> get _pending => _filteredOrders
      .where(
        (o) =>
            _isSubmittedOrder(o) ||
            o.status == OrderStatus.inProgress ||
            o.status == OrderStatus.shipped,
      )
      .toList();

  // Past = Delivered + Expired + Cancelled
  List<ClientOrder> get _past => _filteredOrders
      .where(
        (o) =>
            o.status == OrderStatus.delivered ||
            o.status == OrderStatus.expired ||
            o.status == OrderStatus.declined ||
            o.status == OrderStatus.cancelled,
      )
      .toList();

  void _onAvatarMenuSelected(String value) {
    if (value == 'profile') {
      widget.onOpenProfile?.call();
      return;
    }
    if (value == 'earnings') {
      widget.onOpenEarnings?.call();
      return;
    }
    if (value == 'history') {
      widget.onOpenHistory?.call();
      return;
    }
    if (value == 'calendar') {
      widget.onOpenCalendar?.call();
      return;
    }
    if (value == 'artist') {
      widget.onOpenArtist?.call();
      return;
    }
    if (value == 'reviews') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ArtistReviewsPage()));
      return;
    }
    if (value == 'logout') {
      _logout();
    }
  }

  Future<void> _logout() async {
    if (widget.onLogout != null) {
      await widget.onLogout!.call();
      return;
    }
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,

      // ✅ Header same as Artists page: logo + centered title + notification + avatar menu
      appBar: widget.showCompanyChrome && widget.companyName != null
          ? CompanyHeader(
              companyName: widget.companyName!,
              onOpenProfile: widget.onOpenProfile,
              onLogout: widget.onLogout,
            )
          : JntStandardAppBar(
              onNotifications: () {
                NotificationsPage.showAsModal(context);
              },
              notificationFocusNode: _notificationsFocusNode,
              trailing: _AvatarMenu(
                onSelected: _onAvatarMenuSelected,
                avatarUrl: widget.profile.basic.profileImageUrl,
                displayName: widget.profile.basic.name,
                showProfile: widget.showProfileMenu,
                showEarnings: widget.onOpenEarnings != null,
                showHistory: widget.showExtendedAvatarMenu,
                showCalendar: widget.showExtendedAvatarMenu,
                showArtist: widget.showExtendedAvatarMenu,
                showReviews: widget.showExtendedAvatarMenu,
              ),
            ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
        children: [
          _FilterTabs(
            selected: _filter,
            counts: <OrdersFilter, int>{
              OrdersFilter.all: _orders.length,
              OrdersFilter.pending: _orders.where(_isSubmittedOrder).length,
              OrdersFilter.submitted: _orders
                  .where(
                    (o) =>
                        o.status == OrderStatus.newOrder ||
                        o.status == OrderStatus.inReview,
                  )
                  .length,
              OrdersFilter.inProgress: _orders
                  .where((o) => o.status == OrderStatus.inProgress)
                  .length,
              OrdersFilter.shipped: _orders
                  .where((o) => o.status == OrderStatus.shipped)
                  .length,
              OrdersFilter.delivered: _orders
                  .where((o) => o.status == OrderStatus.delivered)
                  .length,
              OrdersFilter.declined: _orders
                  .where((o) => o.status == OrderStatus.declined)
                  .length,
              OrdersFilter.cancelledExpired: _orders
                  .where(
                    (o) =>
                        o.status == OrderStatus.cancelled ||
                        o.status == OrderStatus.expired,
                  )
                  .length,
            },
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 16),

          if (_pending.isNotEmpty) ...[
            const Text(
              'All Orders',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.blackCat,
              ),
            ),
            const SizedBox(height: 10),
            ..._pending.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _OrderCard(
                  order: o,
                  showLeadingThumb: widget.showCompanyChrome,
                  onDetails: () => _openOrderDetails(context, o),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (_past.isNotEmpty) ...[
            const Text(
              'Past Orders',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.blackCat,
              ),
            ),
            const SizedBox(height: 10),
            ..._past.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _OrderCard(
                  order: o,
                  showLeadingThumb: widget.showCompanyChrome,
                  onDetails: () => _openOrderDetails(context, o),
                ),
              ),
            ),
          ],

          if (_pending.isEmpty && _past.isEmpty) ...[
            const SizedBox(height: 28),
            _Card(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 46,
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No orders found',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.blackCat,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try changing filters or place a new design request.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.60),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: widget.showCompanyChrome
          ? CompanyBottomNav(
              currentIndex: widget.bottomNavIndex,
              onTap: (i) => widget.onNavTap?.call(i),
            )
          : null,
    );
  }

  void _openOrderDetails(BuildContext context, ClientOrder order) {
    if (order.status == OrderStatus.declined) {
      unawaited(_openDeclinedRequestSheet(context, order));
      return;
    }

    Widget page;
    final isBrandViewer = widget.audience == OrdersAudience.brand;

    switch (order.status) {
      case OrderStatus.newOrder:
        page = InReviewOrderDetailsPage(
          order: order,
          isBrandViewer: isBrandViewer,
        );
        break;
      case OrderStatus.inReview:
        page = InReviewOrderDetailsPage(
          order: order,
          isBrandViewer: isBrandViewer,
        );
        break;
      case OrderStatus.inProgress:
        page = InProgressOrderDetailsPage(
          order: order,
          isBrandViewer: isBrandViewer,
        );
        break;
      case OrderStatus.shipped:
        page = ShippedOrderDetailsPage(
          order: order,
          isBrandViewer: isBrandViewer,
        );
        break;
      case OrderStatus.delivered:
        page = DeliveredOrderDetailsPage(
          order: order,
          isBrandViewer: isBrandViewer,
        );
        break;
      case OrderStatus.expired:
        page = ExpiredOrderDetailsPage(
          order: order,
          isBrandViewer: isBrandViewer,
          onResubmit: () => _resubmitCancelledOrder(order),
        );
        break;
      case OrderStatus.cancelled:
        page = CancelledOrderDetailsPage(
          order: order,
          isBrandViewer: isBrandViewer,
          onResubmit: () => _resubmitCancelledOrder(order),
        );
        break;
      case OrderStatus.declined:
        page = InReviewOrderDetailsPage(
          order: order,
          isBrandViewer: isBrandViewer,
        );
        break;
    }

    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Order details',
      barrierDismissible: true,
      barrierColor: AppColors.blackCat.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Material(
                  color: AppColors.alabaster,
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: page,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _openDeclinedRequestSheet(
    BuildContext context,
    ClientOrder order,
  ) async {
    final req = _toSimpleClientRequest(order);
    final declinedAt = order.cancelledAt ?? order.createdAt ?? DateTime.now();
    await showSimpleStatusRequestSheet(
      context: context,
      request: req,
      status: SimpleRequestStatus.declined,
      date: declinedAt,
    );
  }

  ClientRequestV2 _toSimpleClientRequest(ClientOrder order) {
    NailDimensionsV2 mapHand(Map<String, String> hand) => NailDimensionsV2(
      thumb: hand['thumb'] ?? hand['lThumb'] ?? hand['rThumb'] ?? '',
      index: hand['index'] ?? hand['lIndex'] ?? hand['rIndex'] ?? '',
      middle: hand['middle'] ?? hand['lMiddle'] ?? hand['rMiddle'] ?? '',
      ring: hand['ring'] ?? hand['lRing'] ?? hand['rRing'] ?? '',
      pinky: hand['pinky'] ?? hand['lPinky'] ?? hand['rPinky'] ?? '',
    );

    return ClientRequestV2(
      id: order.id,
      sourceCollection: order.sourceCollection,
      orderNumber: order.orderNumber,
      clientEmail: order.clientEmail,
      clientName: order.title,
      title: order.title,
      subtitle: order.subtitle,
      neededBy: order.needBy ?? DateTime.now(),
      submittedAt: order.createdAt,
      budgetMin: order.budgetMin ?? 0,
      budgetMax: order.budgetMax ?? 0,
      status: RequestStatusV2.declined,
      isDirectRequest: false,
      hasInspo: order.inspirationPhotos.isNotEmpty,
      clientLocation: '',
      previewImageAsset: order.imageAsset,
      clientProfileImage: order.clientProfileImage,
      bio: order.clientDescription,
      nailShape: order.nailShape,
      nailLength: order.nailLength,
      leftHand: mapHand(order.leftHandDimensions),
      rightHand: mapHand(order.rightHandDimensions),
      clientImages: order.inspirationPhotos,
      orderType: order.orderType.trim().toLowerCase() == 'group'
          ? RequestOrderTypeV2.group
          : RequestOrderTypeV2.single,
      groupClients: order.groupClients
          .asMap()
          .entries
          .map(
            (entry) => GroupOrderClientV2(
              slotIndex: entry.key + 1,
              clientId: entry.value.clientId,
              clientName: entry.value.clientName,
              nailShape: entry.value.nailShape,
              nailLength: entry.value.nailLength,
              leftHand: mapHand(entry.value.leftHandDimensions),
              rightHand: mapHand(entry.value.rightHandDimensions),
            ),
          )
          .toList(growable: false),
      cancelReason: order.cancelReason,
      declineReason: order.cancelReason.trim().isNotEmpty
          ? order.cancelReason.trim()
          : 'Declined by client',
    );
  }

  Future<void> _resubmitCancelledOrder(ClientOrder order) async {
    try {
      final rootData = await _SupabaseOrderService.getRequest(
        order.sourceCollection.trim().isNotEmpty
            ? order.sourceCollection.trim()
            : 'Client_Custom_Requests',
        order.id,
      );
      final detailData = <String, dynamic>{
        ..._SupabaseOrderService.asMap(rootData['details']),
        ..._SupabaseOrderService.asMap(rootData['payload']),
        ..._SupabaseOrderService.asMap(rootData['request_details']),
        ..._SupabaseOrderService.asMap(rootData['summary']),
      };

      Map<String, dynamic> asMap(dynamic value) {
        if (value is Map<String, dynamic>) {
          return Map<String, dynamic>.from(value);
        }
        if (value is Map) {
          return value.map((k, v) => MapEntry(k.toString(), v));
        }
        return <String, dynamic>{};
      }

      final requestDetails = <String, dynamic>{
        ...asMap(rootData['requestDetails']),
        ...asMap(detailData['requestDetails']),
      };
      requestDetails['description'] ??=
          detailData['description'] ??
          rootData['description'] ??
          rootData['descriptionPreview'];

      final budget = <String, dynamic>{
        ...asMap(rootData['budget']),
        ...asMap(detailData['budget']),
      };
      budget['min'] ??= rootData['budgetMin'];
      budget['max'] ??= rootData['budgetMax'];

      final orderMap = <String, dynamic>{
        ...asMap(rootData['order']),
        ...asMap(detailData['order']),
      };
      orderMap['type'] ??= detailData['orderType'] ?? rootData['orderType'];
      orderMap['allowNonLicensed'] ??=
          detailData['allowNonLicensed'] ?? rootData['allowNonLicensed'];
      orderMap['selectedArtist'] ??=
          detailData['selectedArtist'] ?? rootData['selectedArtist'];
      orderMap['selectedArtistEmail'] ??=
          detailData['selectedArtistEmail'] ?? rootData['selectedArtistEmail'];
      orderMap['isDirectRequest'] ??=
          detailData['isDirectRequest'] ?? rootData['isDirectRequest'];
      orderMap['fallbackToPool'] ??=
          detailData['fallbackToPool'] ?? rootData['fallbackToPool'];

      final groupOrder = <String, dynamic>{
        ...asMap(rootData['groupOrder']),
        ...asMap(detailData['groupOrder']),
      };
      if (groupOrder['clients'] == null) {
        groupOrder['clients'] =
            orderMap['clients'] ??
            detailData['groupClients'] ??
            rootData['groupClients'];
      }
      groupOrder['isGroupOrder'] ??=
          detailData['isGroupOrder'] ?? rootData['isGroupOrder'];

      final initialRequestData = <String, dynamic>{
        ...rootData,
        ...detailData,
        'requestDetails': requestDetails,
        'budget': budget,
        'order': orderMap,
        'shipping': <String, dynamic>{
          ...asMap(rootData['shipping']),
          ...asMap(detailData['shipping']),
        },
        'groupOrder': groupOrder,
        'nailPreferences': <String, dynamic>{
          ...asMap(rootData['nailPreferences']),
          ...asMap(detailData['nailPreferences']),
        },
        'inspirationPhotos':
            (detailData['inspirationPhotos'] as List<dynamic>?) ??
            (rootData['inspirationPhotos'] as List<dynamic>?) ??
            const <dynamic>[],
      };

      // Keep all prior request data for resubmit, but force Need By to be empty.
      requestDetails.remove('needBy');
      requestDetails.remove('needByDisplay');
      initialRequestData.remove('needBy');
      initialRequestData.remove('needByDisplay');

      if (!mounted) return;
      Navigator.of(context).pop();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClientCustomRequestPage(
            profile: widget.profile,
            initialRequestData: initialRequestData,
            onBackHome: () => Navigator.of(context).pop(),
            showBottomNav: true,
            bottomNavIndex: 1,
            onNavTap: widget.onNavTap,
            onOpenProfile: widget.onOpenProfile,
            onOpenHistory: widget.onOpenHistory,
            onOpenCalendar: widget.onOpenCalendar,
            onOpenArtist: widget.onOpenArtist,
            onLogout: widget.onLogout,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load request for resubmit: $e')),
      );
    }
  }
}

/// ✅ Avatar dropdown (Logout)
class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({
    required this.onSelected,
    this.avatarUrl = '',
    this.displayName = '',
    this.showProfile = true,
    this.showEarnings = false,
    this.showHistory = true,
    this.showCalendar = true,
    this.showArtist = true,
    this.showReviews = true,
  });
  final ValueChanged<String> onSelected;
  final String avatarUrl;
  final String displayName;
  final bool showProfile;
  final bool showEarnings;
  final bool showHistory;
  final bool showCalendar;
  final bool showArtist;
  final bool showReviews;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 55),
      elevation: 8,
      color: AppColors.snow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      onSelected: onSelected,
      itemBuilder: (context) => [
        if (showProfile)
          PopupMenuItem<String>(
            value: 'profile',
            child: Row(
              children: const [
                Icon(Icons.person_outline, size: 22),
                SizedBox(width: 14),
                Text(
                  'Profile',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (showEarnings)
          PopupMenuItem<String>(
            value: 'earnings',
            child: Row(
              children: const [
                Icon(Icons.attach_money_outlined, size: 22),
                SizedBox(width: 14),
                Text(
                  'Earnings',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (showHistory)
          PopupMenuItem<String>(
            value: 'history',
            child: Row(
              children: const [
                Icon(Icons.history, size: 22),
                SizedBox(width: 14),
                Text(
                  'History',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (showCalendar)
          PopupMenuItem<String>(
            value: 'calendar',
            child: Row(
              children: const [
                Icon(Icons.calendar_month_outlined, size: 22),
                SizedBox(width: 14),
                Text(
                  'Calendar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (showArtist)
          PopupMenuItem<String>(
            value: 'artist',
            child: Row(
              children: const [
                Icon(Icons.brush_outlined, size: 22),
                SizedBox(width: 14),
                Text(
                  'Artist',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (showReviews)
          PopupMenuItem<String>(
            value: 'reviews',
            child: Row(
              children: const [
                Icon(Icons.star_border, size: 22),
                SizedBox(width: 14),
                Text(
                  'Reviews',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (showProfile ||
            showEarnings ||
            showHistory ||
            showCalendar ||
            showArtist ||
            showReviews)
          const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: const [
              Icon(Icons.logout_rounded, size: 22, color: AppColors.blackCat),
              SizedBox(width: 14),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackCat,
                ),
              ),
            ],
          ),
        ),
      ],
      child: SizedBox(
        height: JntHeaderMetrics.avatarSize,
        width: JntHeaderMetrics.avatarSize,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: ClientProfileAvatarIcon(
            imageUrl: avatarUrl,
            displayName: displayName,
            size: JntHeaderMetrics.avatarSize,
          ),
        ),
      ),
    );
  }
}

/// ---------------------------
/// Filter Pills
/// ---------------------------
class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final OrdersFilter selected;
  final Map<OrdersFilter, int> counts;
  final ValueChanged<OrdersFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _tab('All Orders', OrdersFilter.all),
            _tab('Pending', OrdersFilter.pending),
            _tab('In Progress', OrdersFilter.inProgress),
            _tab('Shipped', OrdersFilter.shipped),
            _tab('Delivered', OrdersFilter.delivered),
            _tab('Declined', OrdersFilter.declined),
            _tab('Cancelled/Expired', OrdersFilter.cancelledExpired),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, OrdersFilter value) {
    final bool isSelected = selected == value;
    final count = counts[value] ?? 0;
    final semanticLabel = '$label, $count ${count == 1 ? 'order' : 'orders'}';

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel,
      hint: isSelected ? 'Selected filter' : 'Double tap to filter orders',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.zero,
          hoverColor: AppColors.balletSlippers.withValues(alpha: 0.35),
          splashColor: AppColors.balletSlippers.withValues(alpha: 0.45),
          highlightColor: AppColors.balletSlippers.withValues(alpha: 0.30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 5,
                  ),
                  child: Text(
                    '$label #$count',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'ArialBold',
                      color: isSelected
                          ? AppColors.blackCat
                          : AppColors.blackCat.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  width: isSelected ? 34 : 0,
                  decoration: BoxDecoration(
                    color: AppColors.balletSlippers,
                    borderRadius: BorderRadius.zero,
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

/// ---------------------------
/// Order Card
/// ---------------------------
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onDetails,
    required this.showLeadingThumb,
  });

  final ClientOrder order;
  final VoidCallback onDetails;
  final bool showLeadingThumb;

  @override
  Widget build(BuildContext context) {
    final isBrandRequest =
        order.sourceCollection.trim() == 'Company_Custom_Requests';

    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLeadingThumb) ...[
            ExcludeSemantics(child: _Thumb(imageAsset: order.imageAsset)),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (order.status == OrderStatus.shipped) ...[
                      SizedBox(
                        height: 30,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blackCat,
                            foregroundColor: AppColors.snow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TrackOrderPage(order: order),
                              ),
                            );
                          },
                          child: const Text(
                            'Track Order',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.snow,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _StatusChip(status: order.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  order.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.blackCat,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    fontFamily: 'Arial',
                  ),
                ),
                _OrderNfcChipLine(order: order),
                const SizedBox(height: 8),
                if (isBrandRequest)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.balletSlippers,
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: AppColors.blackCatBorderLight,
                        ),
                      ),
                      child: const Text(
                        'Brand Request',
                        style: TextStyle(
                          color: AppColors.blackCat,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Arial',
                        ),
                      ),
                    ),
                  ),
                if (isBrandRequest) ...[
                  const SizedBox(height: 6),
                  if ((order.brandName ?? '').trim().isNotEmpty)
                    Text(
                      'Brand: ${(order.brandName ?? '').trim()}',
                      style: TextStyle(
                        color: AppColors.blackCat.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        fontFamily: 'Arial',
                      ),
                    ),
                  if ((order.campaignName ?? '').trim().isNotEmpty)
                    Text(
                      'Campaign: ${(order.campaignName ?? '').trim()}',
                      style: TextStyle(
                        color: AppColors.blackCat.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        fontFamily: 'Arial',
                      ),
                    ),
                ],
                const SizedBox(height: 10),
                if (order.orderNumber.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Order #: ${order.orderNumber}',
                    style: TextStyle(
                      color: AppColors.blackCat,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      fontFamily: 'Arial',
                    ),
                  ),
                ],
                if (order.artistAcceptedAmount != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Final Amount: \$${order.artistAcceptedAmount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blackCat,
                      fontFamily: 'Arial',
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                /*if (isProgress) ...[
                  _ProgressBar(value: (order.progress ?? 0.0).clamp(0.0, 1.0)),
                  const SizedBox(height: 4),
                ],*/
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          order.expectedOrDeliveredText,
                          style: TextStyle(
                            color: AppColors.blackCat.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            fontFamily: 'Arial',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _OrderDetailsLink(onTap: onDetails),
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

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageAsset});
  final String imageAsset;

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
        p.startsWith('gs%3A') ||
        p.startsWith('blob%3A') ||
        p.startsWith('http%3A') ||
        p.startsWith('https%3A')) {
      p = Uri.decodeFull(p);
    }
    for (var i = 0; i < 2; i++) {
      final decoded = Uri.decodeFull(p);
      if (decoded == p) break;
      p = decoded;
    }
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final p = _normalizeImagePath(imageAsset);
    final isNetwork =
        p.startsWith('http://') ||
        p.startsWith('https://') ||
        p.startsWith('gs://') ||
        p.startsWith('blob:') ||
        p.startsWith('data:') ||
        p.startsWith('content://');
    final isStoragePath = _looksLikeStoragePath(p);
    final isAsset = p.startsWith('assets/');
    final isFileUri = p.startsWith('file://');
    final isFile = !kIsWeb && (p.startsWith('/') || p.contains(':\\'));
    Widget fallback() => Container(
      height: 64,
      width: 64,
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.blackCat.withValues(alpha: 0.35),
      ),
    );
    Widget image;
    if (p.startsWith('gs://')) {
      image = FutureBuilder<String>(
        future: _SupabaseOrderService.resolveStorageUrl(p).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = snap.data?.trim() ?? '';
          if (url.isEmpty) return fallback();
          return Image.network(
            url,
            height: 64,
            width: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          );
        },
      );
    } else if (isStoragePath) {
      image = FutureBuilder<String>(
        future: _SupabaseOrderService.resolveStorageUrl(p).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = snap.data?.trim() ?? '';
          if (url.isEmpty) return fallback();
          return Image.network(
            url,
            height: 64,
            width: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          );
        },
      );
    } else if (isNetwork) {
      image = Image.network(
        p,
        height: 64,
        width: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else if (isAsset) {
      image = Image.asset(
        p,
        height: 64,
        width: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else if (isFileUri || isFile) {
      final localPath = isFileUri ? p.replaceFirst('file://', '') : p;
      image = Image.file(
        File(localPath),
        height: 64,
        width: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else {
      image = fallback();
    }
    return ClipRRect(borderRadius: BorderRadius.zero, child: image);
  }

  bool _looksLikeStoragePath(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (v.startsWith('/') ||
        v.startsWith('assets/') ||
        v.startsWith('file://') ||
        v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('gs://') ||
        v.startsWith('data:') ||
        v.startsWith('blob:') ||
        v.startsWith('content://')) {
      return false;
    }
    if (v.contains(':\\')) return false;
    return v.contains('/');
  }
}

class _OrderNfcChipLine extends StatelessWidget {
  const _OrderNfcChipLine({required this.order});

  final ClientOrder order;

  @override
  Widget build(BuildContext context) {
    final collection = order.sourceCollection.trim().isNotEmpty
        ? order.sourceCollection.trim()
        : 'Client_Custom_Requests';
    final id = order.id.trim();
    if (id.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: _shouldShowNfcChip(collection: collection, id: id),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Align(alignment: Alignment.centerLeft, child: _NfcChip()),
        );
      },
    );
  }

  static Future<bool> _shouldShowNfcChip({
    required String collection,
    required String id,
  }) async {
    try {
      final root = await _SupabaseOrderService.getRequest(collection, id);
      final details = <String, dynamic>{
        ..._SupabaseOrderService.asMap(root['details']),
        ..._SupabaseOrderService.asMap(root['payload']),
        ..._SupabaseOrderService.asMap(root['summary']),
      };
      return _hasEligibleRequestedNfc(root, details);
    } catch (_) {
      return false;
    }
  }

  static bool _hasEligibleRequestedNfc(
    Map<String, dynamic> root,
    Map<String, dynamic> details,
  ) {
    final requested = _readBoolFromAny(root, details, const [
      'nfcRequested',
      'isNfcRequested',
      'hasNfc',
      'hasNFC',
      'nfcSelected',
      'nfc_requested',
      'nfc_selected',
      'has_nfc',
    ]);
    final requestedInMeta =
        _readBoolFromNestedNfcMeta(root) || _readBoolFromNestedNfcMeta(details);
    return requested || requestedInMeta;
  }

  static bool _readBoolFromAny(
    Map<String, dynamic> root,
    Map<String, dynamic> details,
    List<String> keys,
  ) {
    for (final source in <Map<String, dynamic>>[root, details]) {
      if (_readBool(source, keys)) return true;
      for (final nestedKey in const <String>[
        'nfc',
        'nfcMeta',
        'nfcData',
        'nailPreferences',
        'requestDetails',
        'order',
      ]) {
        final nested = source[nestedKey];
        if (nested is Map && _readBool(_stringKeyMap(nested), keys)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _readBool(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      if (_asBool(source[key])) return true;
    }
    return false;
  }

  static bool _readBoolFromNestedNfcMeta(Map<String, dynamic> source) {
    for (final nestedKey in const <String>[
      'nfc',
      'nfcMeta',
      'nfcData',
      'summary',
      'requestDetails',
      'order',
    ]) {
      final nested = source[nestedKey];
      if (nested is Map) {
        final map = _stringKeyMap(nested);
        if (_readBool(map, const [
          'requested',
          'selected',
          'nfcRequested',
          'nfcSelected',
          'hasNfc',
          'has_nfc',
          'nfc_requested',
          'nfc_selected',
        ])) {
          return true;
        }
      }
    }
    return false;
  }

  static Map<String, dynamic> _stringKeyMap(Map source) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == 'yes' ||
          normalized == '1' ||
          normalized == 'selected';
    }
    return false;
  }

}

class _NfcChip extends StatelessWidget {
  const _NfcChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: const Text(
        'NFC',
        style: TextStyle(
          color: AppColors.blackCat,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'Arial',
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    late final String text;
    switch (status) {
      case OrderStatus.newOrder:
        text = 'Pending';
        break;
      case OrderStatus.inReview:
        text = 'Pending';
        break;
      case OrderStatus.inProgress:
        text = 'In Progress';
        break;
      case OrderStatus.shipped:
        text = 'Shipped';
        break;
      case OrderStatus.delivered:
        text = 'Delivered';
        break;
      case OrderStatus.expired:
        text = 'Expired';
        break;
      case OrderStatus.declined:
        text = 'Declined';
        break;
      case OrderStatus.cancelled:
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

class _OrderDetailsLink extends StatelessWidget {
  const _OrderDetailsLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Order details',
      hint: 'Double tap to view order details',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          hoverColor: AppColors.balletSlippers.withValues(alpha: 0.35),
          splashColor: AppColors.balletSlippers.withValues(alpha: 0.45),
          highlightColor: AppColors.balletSlippers.withValues(alpha: 0.30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Order details',
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.blackCat.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------
/// Shared Card Container
/// ---------------------------
class _Card extends StatelessWidget {
  // ignore: unused_element_parameter
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.80)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// ---------------------------
/// Models
/// ---------------------------
enum OrdersFilter {
  all,
  pending,
  submitted,
  inProgress,
  shipped,
  delivered,
  declined,
  cancelledExpired,
}

enum OrderStatus {
  newOrder,
  inReview,
  inProgress,
  shipped,
  delivered,
  expired,
  declined,
  cancelled,
}

class ClientOrder {
  final String id;
  final String sourceCollection;
  final String rawStatus;
  final String orderNumber;
  final String? brandName;
  final String? campaignName;
  final String title;
  final String subtitle;
  final bool hasAssignedArtist;
  final String orderType;
  final List<OrderClientMeasurement> groupClients;
  final String clientDescription;
  final String cancelReason;
  final List<String> inspirationPhotos;
  final String needByDisplay;
  final String nailShape;
  final String nailLength;
  final int? budgetMin;
  final int? budgetMax;
  final Map<String, String> leftHandDimensions;
  final Map<String, String> rightHandDimensions;
  final OrderStatus status;
  final String expectedOrDeliveredText;
  final DateTime? createdAt;
  final int? artistAcceptedAmount;
  final String paymentStatus;
  final String paymentLink;
  final DateTime? paidAt;
  final String clientProfileImage;
  final List<String> artistCompletedPhotos;
  final String completionReviewStatus;
  final String completionDeclineReason;
  final String completionDeclineDescription;
  final DateTime? completionDeclinedAt;
  final String designApprovalStatus;
  final DateTime? designApprovedAt;
  final DateTime? clientDesignApprovedAt;
  final DateTime? designSubmittedAt;
  final DateTime? designApprovalDueAt;
  final DateTime? designReminderSentAt;
  final List<String> designPreviewPhotos;
  final String clientEmail;
  final String acceptedByArtistEmail;
  final List<String> declinedByClientEmails;
  final List<String> declinedByArtistEmails;
  final String directClientStatus;
  final String artistName;
  final String selectedArtistName;
  final String artistProfileImage;
  final DateTime? cancelledAt;
  final DateTime? needBy;
  final String shippedByCourier;
  final String trackingNumber;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;

  /// 0..1 progress for in-progress only
  final double? progress;

  /// rating for delivered only
  final double? rating;
  final String reviewText;
  final DateTime? reviewSubmittedAt;

  final String imageAsset;

  const ClientOrder({
    required this.id,
    this.sourceCollection = '',
    this.rawStatus = '',
    this.orderNumber = '',
    this.brandName,
    this.campaignName,
    required this.title,
    required this.subtitle,
    this.hasAssignedArtist = true,
    this.orderType = 'single',
    this.groupClients = const <OrderClientMeasurement>[],
    this.clientDescription = '',
    this.cancelReason = '',
    this.inspirationPhotos = const [],
    this.needByDisplay = '',
    this.nailShape = '',
    this.nailLength = '',
    this.budgetMin,
    this.budgetMax,
    this.leftHandDimensions = const {},
    this.rightHandDimensions = const {},
    required this.status,
    required this.expectedOrDeliveredText,
    required this.imageAsset,
    this.createdAt,
    this.artistAcceptedAmount,
    this.paymentStatus = '',
    this.paymentLink = '',
    this.paidAt,
    this.clientProfileImage = '',
    this.artistCompletedPhotos = const [],
    this.completionReviewStatus = '',
    this.completionDeclineReason = '',
    this.completionDeclineDescription = '',
    this.completionDeclinedAt,
    this.designApprovalStatus = '',
    this.designApprovedAt,
    this.clientDesignApprovedAt,
    this.designSubmittedAt,
    this.designApprovalDueAt,
    this.designReminderSentAt,
    this.designPreviewPhotos = const [],
    this.clientEmail = '',
    this.acceptedByArtistEmail = '',
    this.declinedByClientEmails = const <String>[],
    this.declinedByArtistEmails = const <String>[],
    this.directClientStatus = '',
    this.artistName = '',
    this.selectedArtistName = '',
    this.artistProfileImage = '',
    this.cancelledAt,
    this.needBy,
    this.shippedByCourier = '',
    this.trackingNumber = '',
    this.shippedAt,
    this.deliveredAt,
    this.progress,
    this.rating,
    this.reviewText = '',
    this.reviewSubmittedAt,
  });
}

class OrderClientMeasurement {
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String responseStatus;
  final String nailShape;
  final String nailLength;
  final Map<String, String> leftHandDimensions;
  final Map<String, String> rightHandDimensions;

  const OrderClientMeasurement({
    this.clientId = '',
    this.clientName = '',
    this.clientEmail = '',
    this.responseStatus = '',
    this.nailShape = '',
    this.nailLength = '',
    this.leftHandDimensions = const <String, String>{},
    this.rightHandDimensions = const <String, String>{},
  });
}
