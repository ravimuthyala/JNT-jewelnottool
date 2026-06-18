import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  bool _loading = true;
  bool _submitting = false;

  double _orderTotal = 0;
  late int _selectedPercent;

  @override
  void initState() {
    super.initState();
    _selectedPercent = widget.tipPercent;
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      final data = doc.data() ?? {};

      final total = data['totalAmount'] ?? data['orderTotal'] ?? 0;

      setState(() {
        _orderTotal = total is num ? total.toDouble() : 0;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  double get _tipAmount {
    return _orderTotal * (_selectedPercent / 100);
  }

  Future<void> _submitTip() async {
    setState(() => _submitting = true);

    try {
      await FirebaseFirestore.instance.collection('tips').add({
        'orderId': widget.orderId,
        'artistId': widget.artistId,
        'tipPercent': _selectedPercent,
        'tipAmount': _tipAmount,
        'status': 'pending_payment',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .set({
        'tip': {
          'selected': true,
          'percent': _selectedPercent,
          'amount': _tipAmount,
          'status': 'pending_payment',
          'createdAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
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
              'Order #${widget.orderId}',
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
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
    );
  }
}