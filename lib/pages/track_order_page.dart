import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// If you already have ClientOrder model, keep this import.
// Update path if needed:
// import 'client_orders_page.dart' show ClientOrder;

class TrackOrderPage extends StatelessWidget {
  const TrackOrderPage({
    super.key,
    this.onBackHome,
    this.order, // ✅ optional now
  });

  final VoidCallback? onBackHome;

  /// If your app has a real order model, you can pass it.
  /// Otherwise it can be null and we show a friendly screen.
  final dynamic
  order; // ✅ keeps it compatible even if you don't import the model here

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.alabaster,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            onBackHome?.call();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Track Order',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          order == null
              ? 'No order selected.\nGo to Orders and choose an order to track.'
              : 'Tracking details for this order will appear here.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
