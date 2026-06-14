import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_colors.dart';

class ShippingStatusChip extends StatelessWidget {
  const ShippingStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    Color bg;
    Color fg;
    String label;
    if (normalized == 'delivered') {
      bg = const Color(0xFFDFF4E8);
      fg = const Color(0xFF1E6F43);
      label = 'Delivered';
    } else if (normalized == 'shipped') {
      bg = const Color(0xFFE7F0FF);
      fg = const Color(0xFF1C4AA5);
      label = 'Shipped';
    } else {
      bg = const Color(0xFFF6EEDB);
      fg = const Color(0xFF6C4C08);
      label = 'Label Ready';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w700, color: fg, fontSize: 12),
      ),
    );
  }
}

class ShippingQrCard extends StatelessWidget {
  const ShippingQrCard({
    super.key,
    required this.qrCode,
    required this.orderNumber,
    required this.artistId,
    this.onDownload,
    this.onPrint,
    this.onConfirmShipment,
    this.confirmLabel = 'Mark as Shipped / Confirm Shipment',
  });

  final String qrCode;
  final String orderNumber;
  final String artistId;
  final VoidCallback? onDownload;
  final VoidCallback? onPrint;
  final VoidCallback? onConfirmShipment;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Shipping Ready', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const ShippingStatusChip(status: 'label_ready'),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: QrImageView(
              data: qrCode,
              size: 190,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
            ),
          ),
          const SizedBox(height: 12),
          Text('Order Number: $orderNumber', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Artist ID: $artistId', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(onPressed: onDownload, child: const Text('Download QR')),
              OutlinedButton(onPressed: onPrint, child: const Text('Print QR')),
              ElevatedButton(
                onPressed: onConfirmShipment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: AppColors.snow,
                ),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ShippingQrSection extends StatelessWidget {
  const ShippingQrSection({
    super.key,
    required this.shippingStatus,
    required this.qrCode,
    required this.orderNumber,
    required this.artistId,
    this.onDownload,
    this.onPrint,
    this.onConfirmShipment,
  });

  final String shippingStatus;
  final String qrCode;
  final String orderNumber;
  final String artistId;
  final VoidCallback? onDownload;
  final VoidCallback? onPrint;
  final VoidCallback? onConfirmShipment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Shipping QR / Label', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(width: 8),
            ShippingStatusChip(status: shippingStatus),
          ],
        ),
        const SizedBox(height: 10),
        ShippingQrCard(
          qrCode: qrCode,
          orderNumber: orderNumber,
          artistId: artistId,
          onDownload: onDownload,
          onPrint: onPrint,
          onConfirmShipment: onConfirmShipment,
        ),
      ],
    );
  }
}

class AddTrackingNumberDialog extends StatefulWidget {
  const AddTrackingNumberDialog({
    super.key,
    this.initialCarrier = '',
    this.initialTrackingNumber = '',
  });

  final String initialCarrier;
  final String initialTrackingNumber;

  @override
  State<AddTrackingNumberDialog> createState() => _AddTrackingNumberDialogState();
}

class _AddTrackingNumberDialogState extends State<AddTrackingNumberDialog> {
  late final TextEditingController _carrierController;
  late final TextEditingController _trackingController;

  @override
  void initState() {
    super.initState();
    _carrierController = TextEditingController(text: widget.initialCarrier);
    _trackingController = TextEditingController(text: widget.initialTrackingNumber);
  }

  @override
  void dispose() {
    _carrierController.dispose();
    _trackingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Tracking Number'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _carrierController,
            decoration: const InputDecoration(labelText: 'Carrier'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _trackingController,
            decoration: const InputDecoration(labelText: 'Tracking Number'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(<String, String>{
              'carrier': _carrierController.text.trim(),
              'trackingNumber': _trackingController.text.trim(),
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<void> showSimpleQrPrintDialog(BuildContext context, String qrCode) async {
  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Print / Download QR'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(data: qrCode, size: 220, backgroundColor: Colors.white),
          const SizedBox(height: 8),
          const Text(
            'MVP: long-press or screenshot to save on mobile. Use browser print on web.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    ),
  );
}
