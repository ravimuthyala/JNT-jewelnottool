import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';

class TipArtistPage extends StatefulWidget {
  const TipArtistPage({
    super.key,
    required this.orderId,
    required this.artistId,
    required this.tipPercent,
  });

  final String orderId;
  final String artistId;
  final int tipPercent;

  @override
  State<TipArtistPage> createState() => _TipArtistPageState();
}

class _TipArtistPageState extends State<TipArtistPage> {
  static const _requestTables = <String, String>{
    'client_custom_requests': 'client_custom_requests_details',
    'company_custom_requests': 'company_custom_requests_details',
  };

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _submitting = false;

  double _orderTotal = 0;
  late int _selectedPercent;
  _TipOrderRecord? _order;

  @override
  void initState() {
    super.initState();
    _selectedPercent = widget.tipPercent;
    _loadOrder();
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

  Future<_TipOrderRecord?> _findOrderInTable(
    String table,
    String detailsTable,
  ) async {
    final id = widget.orderId.trim();
    if (id.isEmpty) return null;

    Future<Map<String, dynamic>?> byColumn(String column, String value) async {
      if (value.isEmpty) return null;
      final row = await _supabase.from(table).select().eq(column, value).maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    }

    final row =
        await byColumn('id', id) ??
        await byColumn('order_number', id) ??
        await byColumn('request_number', id);
    if (row == null) return null;

    return _TipOrderRecord(
      table: table,
      detailsTable: detailsTable,
      row: row,
    );
  }

  Future<_TipOrderRecord?> _resolveOrderRecord() async {
    for (final entry in _requestTables.entries) {
      final record = await _findOrderInTable(entry.key, entry.value);
      if (record != null) return record;
    }
    return null;
  }

  Future<void> _loadOrder() async {
    try {
      final order = await _resolveOrderRecord();
      if (order == null) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }

      final data = order.row;
      final details = _asMap(data['details']);
      final payload = _asMap(data['payload']);
      final tip = _asMap(data['clientTip'])..addAll(_asMap(details['clientTip']))..addAll(_asMap(payload['clientTip']));

      final total =
          _asDouble(data['total_amount']) ??
          _asDouble(data['totalAmount']) ??
          _asDouble(data['payment_amount']) ??
          _asDouble(data['paymentAmount']) ??
          _asDouble(data['paid_amount']) ??
          _asDouble(data['paidAmount']) ??
          _asDouble(data['artist_final_amount']) ??
          _asDouble(data['artistFinalAmount']) ??
          _asDouble(data['budget_max']) ??
          _asDouble(data['budgetMax']) ??
          _asDouble(tip['orderTotal']) ??
          0;

      final existingPercentRaw =
          data['client_tip_percent'] ?? data['clientTipPercent'] ?? tip['percent'];
      final existingPercent =
          existingPercentRaw is num
              ? existingPercentRaw.toInt()
              : int.tryParse(_asText(existingPercentRaw));

      if (!mounted) return;
      setState(() {
        _order = order;
        _orderTotal = total < 0 ? 0 : total;
        if ((existingPercent ?? 0) > 0) {
          _selectedPercent = existingPercent!;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _tipAmount => _orderTotal * (_selectedPercent / 100);

  Future<Map<String, dynamic>?> _resolveArtistRowById() async {
    final artistId = widget.artistId.trim();
    if (artistId.isEmpty) return null;
    for (final table in const <String>['artist', 'client_artist']) {
      final row = await _supabase.from(table).select().eq('id', artistId).maybeSingle();
      if (row != null) {
        return <String, dynamic>{
          ...Map<String, dynamic>.from(row),
          '_table': table,
        };
      }
    }
    return null;
  }

  Future<void> _submitTip() async {
    final order = _order;
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order not found for this tip link.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final nowIso = DateTime.now().toIso8601String();
      final orderData = order.row;
      final details = _asMap(orderData['details']);
      final payload = _asMap(orderData['payload']);

      final clientTip = <String, dynamic>{
        'amount': _tipAmount,
        'percent': _selectedPercent,
        'customAmount': 0,
        'fundingSource': 'bank_account',
        'status': 'queued',
        'submittedAt': nowIso,
      };

      await _supabase.from(order.table).update({
        'client_tip_amount': _tipAmount,
        'client_tip_percent': _selectedPercent,
        'client_tip_custom_amount': 0,
        'client_tip_submitted_at': nowIso,
        'updated_at': nowIso,
        'details': {
          ...details,
          'clientTipAmount': _tipAmount,
          'clientTipPercent': _selectedPercent,
          'clientTipCustomAmount': 0,
          'clientTipSubmittedAt': nowIso,
          'clientTip': clientTip,
        },
        'payload': {
          ...payload,
          'clientTipAmount': _tipAmount,
          'clientTipPercent': _selectedPercent,
          'clientTipCustomAmount': 0,
          'clientTipSubmittedAt': nowIso,
          'clientTip': clientTip,
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
        'clientTip': clientTip,
        'clientTipAmount': _tipAmount,
        'clientTipPercent': _selectedPercent,
        'clientTipCustomAmount': 0,
        'clientTipSubmittedAt': nowIso,
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

      final artistRow = await _resolveArtistRowById();
      final artistEmail =
          _asText(orderData['accepted_by_artist_email']).toLowerCase().isNotEmpty
              ? _asText(orderData['accepted_by_artist_email']).toLowerCase()
              : _asText(orderData['artist_email']).toLowerCase().isNotEmpty
              ? _asText(orderData['artist_email']).toLowerCase()
              : _asText(artistRow?['email']).toLowerCase();
      final artistName =
          _asText(orderData['accepted_by_artist_name']).isNotEmpty
              ? _asText(orderData['accepted_by_artist_name'])
              : _asText(orderData['artist_name']).isNotEmpty
              ? _asText(orderData['artist_name'])
              : _asText(artistRow?['name']);
      final clientEmail =
          (_supabase.auth.currentUser?.email ?? '').trim().toLowerCase();

      await _supabase.from('tip_payout_queue').insert({
        'order_id': order.id,
        'order_number': order.orderNumber,
        'source_collection': order.sourceCollection,
        'artist_email': artistEmail,
        'artist_name': artistName,
        'client_email': clientEmail,
        'tip_amount': _tipAmount,
        'tip_percent': _selectedPercent,
        'custom_tip_amount': 0,
        'funding_source': 'bank_account',
        'status': 'queued',
        'created_at': nowIso,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tip added. Continue to payment.')),
      );

      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add tip.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _tipChip(int percent) {
    final selected = _selectedPercent == percent;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$percent% tip',
        value: selected ? 'Selected' : 'Not selected',
        onTap: () => setState(() => _selectedPercent = percent),
        child: ExcludeSemantics(
          child: InkWell(
            onTap: () => setState(() => _selectedPercent = percent),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.blackCat : AppColors.snow,
                border: Border.all(color: AppColors.blackCat),
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                '$percent%',
                style: TextStyle(
                  color: selected ? AppColors.snow : AppColors.blackCat,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
        namesRoute: true,
        label: 'Tip artist',
        child: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_order == null) {
      return Semantics(
        scopesRoute: true,
        namesRoute: true,
        label: 'Tip artist',
        child: Scaffold(
          backgroundColor: AppColors.snow,
          appBar: AppBar(
            title: const Text('Tip Artist'),
            backgroundColor: AppColors.alabaster,
          ),
          body: const SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'We could not find this order for tipping.',
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
      namesRoute: true,
      label: 'Tip artist',
      child: Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        title: const Text('Tip Artist'),
        backgroundColor: AppColors.alabaster,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Leave a tip',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Order #${_order!.orderNumber}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _tipChip(10),
                const SizedBox(width: 8),
                _tipChip(15),
                const SizedBox(width: 8),
                _tipChip(20),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.alabaster,
                border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.12)),
                borderRadius: BorderRadius.zero,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order Total: \$${_orderTotal.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  Text(
                    'Tip Amount: \$${_tipAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitTip,
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
                    : const Text('Continue to Tip'),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _TipOrderRecord {
  const _TipOrderRecord({
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
