import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  final _commentCtrl = TextEditingController();

  int _rating = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    setState(() => _submitting = true);

    try {
      await FirebaseFirestore.instance.collection('reviews').add({
        'orderId': widget.orderId,
        'artistId': widget.artistId,
        'rating': _rating,
        'comment': _commentCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .set({
        'review': {
          'submitted': true,
          'rating': _rating,
          'submittedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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

    return IconButton(
      onPressed: () => setState(() => _rating = value),
      icon: Icon(
        selected ? Icons.star : Icons.star_border,
        size: 34,
        color: AppColors.blackCat,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              'Order #${widget.orderId}',
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
    );
  }
}
