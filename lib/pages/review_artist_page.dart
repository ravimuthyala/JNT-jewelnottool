import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notifications_service.dart';
import '../theme/app_colors.dart';
import '../widgets/notification_bell_button.dart';
import 'notifications_page.dart';

class ReviewArtistPage extends StatefulWidget {
  const ReviewArtistPage({
    super.key,
    required this.orderId,
    required this.artistId,
  });

  final String orderId;
  final String artistId;

  @override
  State<ReviewArtistPage> createState() => _ReviewArtistPageState();
}

class _ReviewArtistPageState extends State<ReviewArtistPage> {
  static const _requestTables = <String, String>{
    'client_custom_requests': 'client_custom_requests_details',
    'company_custom_requests': 'company_custom_requests_details',
  };

  final SupabaseClient _supabase = Supabase.instance.client;
  final _commentCtrl = TextEditingController();

  int _rating = 5;
  bool _loading = true;
  bool _submitting = false;
  _ReviewOrderRecord? _order;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().trim());
  }

  String _asText(Object? value) => (value ?? '').toString().trim();

  int _asNonNegativeInt(Object? value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is num) return value < 0 ? 0 : value.toInt();
    final parsed = int.tryParse((value ?? '').toString().trim()) ?? 0;
    return parsed < 0 ? 0 : parsed;
  }

  Future<void> _bestEffort(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _findRowByColumn(
    String table,
    String column,
    String value,
  ) async {
    if (value.isEmpty) return null;
    final row = await _supabase.from(table).select().eq(column, value).maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<_ReviewOrderRecord?> _resolveOrderRecord() async {
    final lookup = widget.orderId.trim();
    if (lookup.isEmpty) return null;

    for (final entry in _requestTables.entries) {
      final row =
          await _findRowByColumn(entry.key, 'id', lookup) ??
          await _findRowByColumn(entry.key, 'order_number', lookup) ??
          await _findRowByColumn(entry.key, 'request_number', lookup);
      if (row != null) {
        return _ReviewOrderRecord(
          table: entry.key,
          detailsTable: entry.value,
          row: row,
        );
      }
    }
    return null;
  }

  Future<void> _loadOrder() async {
    try {
      final order = await _resolveOrderRecord();
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _resolveArtistRow(String artistEmail) async {
    final normalizedEmail = artistEmail.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;

    Map<String, dynamic>? artistRow = await _supabase
        .from('artist')
        .select()
        .ilike('email', normalizedEmail)
        .maybeSingle();
    var artistTable = 'artist';

    artistRow ??= await _supabase
        .from('client_artist')
        .select()
        .ilike('email', normalizedEmail)
        .maybeSingle();
    if (artistRow != null && artistRow.containsKey('account_type')) {
      artistTable = 'client_artist';
    }

    if (artistRow == null) return null;
    return <String, dynamic>{
      ...Map<String, dynamic>.from(artistRow),
      '_table': artistTable,
    };
  }

  Future<void> _submitReview() async {
    final order = _order;
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order not found for this review link.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final comment = _commentCtrl.text.trim();
      final nowIso = DateTime.now().toIso8601String();
      final orderData = order.row;
      final details = _asMap(orderData['details']);
      final payload = _asMap(orderData['payload']);

      final existingClientReview =
          _asMap(orderData['client_review']).isNotEmpty
              ? _asMap(orderData['client_review'])
              : _asMap(orderData['clientReview']).isNotEmpty
              ? _asMap(orderData['clientReview'])
              : _asMap(details['clientReview']).isNotEmpty
              ? _asMap(details['clientReview'])
              : _asMap(payload['clientReview']);

      final previousRatingValue =
          _asDouble(orderData['client_rating']) ??
          _asDouble(orderData['clientRating']) ??
          _asDouble(existingClientReview['rating']);

      final clientReview = <String, dynamic>{
        'rating': _rating,
        'comment': comment,
        'submittedAt': nowIso,
      };

      await _supabase.from(order.table).update({
        'client_rating': _rating,
        'client_review_text': comment,
        'client_review_submitted_at': nowIso,
        'updated_at': nowIso,
        'details': {
          ...details,
          'clientRating': _rating,
          'clientReviewText': comment,
          'clientReviewSubmittedAt': nowIso,
          'clientReview': clientReview,
        },
        'payload': {
          ...payload,
          'clientRating': _rating,
          'clientReviewText': comment,
          'clientReviewSubmittedAt': nowIso,
          'clientReview': clientReview,
        },
      }).eq('id', order.id);

      final existingDetail = await _supabase
          .from(order.detailsTable)
          .select()
          .eq('request_id', order.id)
          .eq('detail_key', 'payload')
          .maybeSingle();

      final detailData =
          existingDetail == null
              ? <String, dynamic>{}
              : _asMap(existingDetail['data']);
      final nextDetail = <String, dynamic>{
        ...detailData,
        'clientReview': clientReview,
        'clientRating': _rating,
        'clientReviewText': comment,
        'clientReviewSubmittedAt': nowIso,
        'updatedAt': nowIso,
      };

      if (existingDetail == null) {
        await _supabase.from(order.detailsTable).insert({
          'request_id': order.id,
          'detail_key': 'payload',
          'data': nextDetail,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
      } else {
        await _supabase
            .from(order.detailsTable)
            .update({
              'data': nextDetail,
              'updated_at': nowIso,
            })
            .eq('id', existingDetail['id']);
      }

      final artistEmail =
          _asText(orderData['accepted_by_artist_email']).toLowerCase().isNotEmpty
              ? _asText(orderData['accepted_by_artist_email']).toLowerCase()
              : _asText(orderData['artist_email']).toLowerCase();
      final artistName =
          _asText(orderData['accepted_by_artist_name']).isNotEmpty
              ? _asText(orderData['accepted_by_artist_name'])
              : _asText(orderData['artist_name']);

      if (artistEmail.isNotEmpty) {
        await _bestEffort(() async {
          final artistRow = await _resolveArtistRow(artistEmail);
          if (artistRow == null || artistRow['id'] == null) return;

          final artistTable = _asText(artistRow['_table']).isEmpty
              ? 'artist'
              : _asText(artistRow['_table']);
          final stats = _asMap(artistRow['stats']);

          final currentCount = _asNonNegativeInt(
            stats['reviewCount'] ??
                stats['reviews'] ??
                artistRow['review_count'] ??
                artistRow['reviewCount'] ??
                artistRow['reviews'] ??
                artistRow['panel_reviews'],
          );

          final currentRating =
              _asDouble(
                stats['rating'] ??
                    stats['averageRating'] ??
                    artistRow['rating'] ??
                    artistRow['average_rating'] ??
                    artistRow['averageRating'] ??
                    artistRow['panel_rating'],
              ) ??
              0.0;

          final hadPrevious = (previousRatingValue ?? 0) > 0;
          final safeCount = currentCount <= 0 ? (hadPrevious ? 1 : 0) : currentCount;
          final nextCount = hadPrevious ? safeCount : (safeCount + 1);
          final nextRating = currentRating >= _rating ? currentRating : _rating.toDouble();

          await _supabase.from(artistTable).update({
            'stats': {
              ...stats,
              'rating': nextRating,
              'averageRating': nextRating,
              'reviewCount': nextCount,
              'reviews': nextCount,
            },
            'rating': nextRating,
            'average_rating': nextRating,
            'review_count': nextCount,
            'reviews': nextCount,
            'panel_rating': nextRating,
            'panel_reviews': nextCount,
            'updated_at': nowIso,
          }).eq('id', artistRow['id']);
        });

        await _bestEffort(() async {
          await NotificationsService.createUserNotification(
            receiverEmail: artistEmail,
            title: 'New Client Review',
            body:
                'A client left a ${_rating.toStringAsFixed(1)} star review on a delivered order.',
            type: 'client_review_submitted',
            orderId: order.id,
            sourceCollection: order.sourceCollection,
          );
        });
      }

      await _bestEffort(() async {
        await NotificationsService.notifyAdmins(
          title: 'Client Review Submitted',
          body:
              'Client submitted a ${_rating.toStringAsFixed(1)} star review for delivered order ${order.orderNumber} (Artist: $artistName).',
          type: 'admin_client_review_submitted',
          orderId: order.id,
          orderNumber: order.orderNumber,
          sourceCollection: order.sourceCollection,
          extra: <String, dynamic>{'rating': _rating, 'comment': comment},
        );
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted. Thank you!')),
      );

      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit review.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _star(int value) {
    final selected = value <= _rating;

    return Semantics(
      button: true,
      selected: value == _rating,
      label: '$value ${value == 1 ? 'star' : 'stars'}',
      value: value == _rating ? 'Selected' : null,
      onTap: () => setState(() => _rating = value),
      child: ExcludeSemantics(
        child: IconButton(
          onPressed: () => setState(() => _rating = value),
          icon: Icon(
            selected ? Icons.star : Icons.star_border,
            size: 34,
            color: AppColors.blackCat,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: 'Review artist',
        child: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_order == null) {
      return Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: 'Review artist',
        child: Scaffold(
          backgroundColor: AppColors.snow,
          appBar: AppBar(
            title: const Text('Rate Artist'),
            backgroundColor: AppColors.alabaster,
          ),
          body: const SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'We could not find this order for review.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Review artist',
      child: Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.alabaster,
        surfaceTintColor: AppColors.alabaster,
        leadingWidth: 58,
        leading: NotificationBellButton(
          onTap: () => NotificationsPage.showAsModal(context),
          iconSize: 22,
        ),
        title: const Text('Rate Artist'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Close review',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'How was your experience?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Order #${_order!.orderNumber}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.blackCat,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => _star(i + 1)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Write a review',
                hintText: 'Share your experience with this artist',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: AppColors.snow,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.snow,
                        ),
                      )
                    : const Text('Submit Review'),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _ReviewOrderRecord {
  const _ReviewOrderRecord({
    required this.table,
    required this.detailsTable,
    required this.row,
  });

  final String table;
  final String detailsTable;
  final Map<String, dynamic> row;

  String get id => (row['id'] ?? '').toString().trim();

  String get orderNumber {
    final candidates = <Object?>[
      row['order_number'],
      row['orderNumber'],
      row['request_number'],
      row['requestNumber'],
      row['client_request_number'],
      row['clientRequestNumber'],
      row['brand_request_number'],
      row['brandRequestNumber'],
      row['id'],
    ];
    for (final value in candidates) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String get sourceCollection =>
      table == 'company_custom_requests'
          ? 'Company_Custom_Requests'
          : 'Client_Custom_Requests';
}
