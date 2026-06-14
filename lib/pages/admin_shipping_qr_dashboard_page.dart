import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/notifications_service.dart';
import '../services/shipping_qr_helper.dart';
import '../theme/app_colors.dart';
import '../widgets/shipping_qr_widgets.dart';

class AdminShippingQrDashboardPage extends StatelessWidget {
  const AdminShippingQrDashboardPage({
    super.key,
    required this.collectionName,
    required this.orderDocId,
  });

  final String collectionName;
  final String orderDocId;

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection(collectionName).doc(orderDocId);
    return Scaffold(
      backgroundColor: AppColors.balletSlippers,
      appBar: AppBar(
        title: const Text('Shipping QR / Label'),
        backgroundColor: AppColors.balletSlippers,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final shipping = (data['shipping'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
          final orderNumber = (data['orderNumber'] ?? orderDocId).toString();
          final artistId = (shipping['qrPayload'] is Map ? (shipping['qrPayload'] as Map)['artistId'] : data['acceptedByArtistEmail'] ?? '').toString();
          final qrCode = (shipping['qrCode'] ?? '').toString().trim().isEmpty
              ? generateShippingQrCode(
                  collectionName: collectionName,
                  orderDocId: orderDocId,
                  orderNumber: orderNumber,
                  artistId: artistId,
                )
              : (shipping['qrCode'] ?? '').toString();
          final shippingStatus = (shipping['status'] ?? data['shippingStatus'] ?? '').toString();

          Future<void> update(Map<String, dynamic> payload) async {
            await docRef.set(payload, SetOptions(merge: true));
            await docRef.collection('details').doc('payload').set(payload, SetOptions(merge: true));
          }

          Future<void> regenerateQr() async {
            final nextQr = generateShippingQrCode(
              collectionName: collectionName,
              orderDocId: orderDocId,
              orderNumber: orderNumber,
              artistId: artistId,
            );
            await update({
              'shippingStatus': 'label_ready',
              'shipping': {
                'status': 'label_ready',
                'qrCode': nextQr,
                'qrPayload': {
                  'requestId': orderDocId,
                  'orderDocId': orderDocId,
                  'collectionName': collectionName,
                  'orderNumber': orderNumber,
                  'artistId': artistId,
                  'artistEmail': (shipping['qrPayload'] is Map ? (shipping['qrPayload'] as Map)['artistEmail'] : '').toString(),
                  'action': 'confirm_shipment',
                },
                'lastUpdatedAt': FieldValue.serverTimestamp(),
                'regeneratedAt': FieldValue.serverTimestamp(),
                'regeneratedBy': 'Admin User',
              },
            });
          }

          Future<void> addTracking() async {
            final result = await showDialog<Map<String, String>>(
              context: context,
              builder: (_) => AddTrackingNumberDialog(
                initialCarrier: (shipping['carrier'] ?? '').toString(),
                initialTrackingNumber: (shipping['trackingNumber'] ?? '').toString(),
              ),
            );
            if (result == null) return;
            await update({
              'shipping': {
                'carrier': (result['carrier'] ?? '').trim(),
                'trackingNumber': (result['trackingNumber'] ?? '').trim(),
                'lastUpdatedAt': FieldValue.serverTimestamp(),
              },
            });
          }

          Future<void> markShipped() async {
            await update({
              'status': 'shipped',
              'artistStatus': 'Shipped',
              'clientStatus': 'Shipped',
              'shippingStatus': 'shipped',
              'shipping': {
                'status': 'shipped',
                'shippedAt': FieldValue.serverTimestamp(),
                'lastUpdatedAt': FieldValue.serverTimestamp(),
              },
            });
          }

          Future<void> markDelivered() async {
            await update({
              'status': 'delivered',
              'artistStatus': 'Delivered',
              'clientStatus': 'Delivered',
              'shippingStatus': 'delivered',
              'shipping': {
                'status': 'delivered',
                'deliveredAt': FieldValue.serverTimestamp(),
                'lastUpdatedAt': FieldValue.serverTimestamp(),
              },
            });

            final clientEmail = (data['clientEmail'] ?? '').toString().trim().toLowerCase();
            if (clientEmail.isNotEmpty) {
              final artistName = (data['selectedArtist'] ?? data['acceptedByArtistEmail'] ?? '')
                  .toString()
                  .trim();
              final tracking = (shipping['trackingNumber'] ?? data['trackingNumber'] ?? '')
                  .toString()
                  .trim();
              final reviewUrl =
                  'https://jnt-app-c3097.web.app/open-app?type=review-order&orderId=${Uri.encodeComponent(orderDocId)}';
              final appLink =
                  'https://jnt-app-c3097.web.app/open-app?type=order-details&orderId=${Uri.encodeComponent(orderDocId)}';
              await NotificationsService.queueTemplatedEmail(
                to: clientEmail,
                templateName: 'client_order_delivered_review_tip',
                data: <String, dynamic>{
                  'clientName': (data['clientName'] ?? 'Client').toString(),
                  'orderId': orderNumber,
                  'artistName': artistName.isEmpty ? 'Your artist' : artistName,
                  'deliveredDate': DateTime.now().toIso8601String(),
                  'trackingNumber': tracking,
                  'reviewUrl': reviewUrl,
                  'tip10Url': '$reviewUrl&tip=10',
                  'tip15Url': '$reviewUrl&tip=15',
                  'tip20Url': '$reviewUrl&tip=20',
                  'appLink': appLink,
                },
              );
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ShippingQrSection(
                shippingStatus: shippingStatus,
                qrCode: qrCode,
                orderNumber: orderNumber,
                artistId: artistId,
                onDownload: () => showSimpleQrPrintDialog(context, qrCode),
                onPrint: () => showSimpleQrPrintDialog(context, qrCode),
                onConfirmShipment: markShipped,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.blackCatBorderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Shipping Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Status: ${shippingStatus.isEmpty ? '-' : shippingStatus}'),
                    Text('Carrier: ${(shipping['carrier'] ?? '-').toString()}'),
                    Text('Tracking Number: ${(shipping['trackingNumber'] ?? '-').toString()}'),
                    Text('Created At: ${(shipping['createdAt'] ?? '-').toString()}'),
                    Text('Shipped At: ${(shipping['shippedAt'] ?? '-').toString()}'),
                    Text('Delivered At: ${(shipping['deliveredAt'] ?? '-').toString()}'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(onPressed: () => showSimpleQrPrintDialog(context, qrCode), child: const Text('View QR')),
                        OutlinedButton(onPressed: () => showSimpleQrPrintDialog(context, qrCode), child: const Text('Print QR')),
                        OutlinedButton(onPressed: () => showSimpleQrPrintDialog(context, qrCode), child: const Text('Download QR')),
                        ElevatedButton(onPressed: regenerateQr, child: const Text('Regenerate QR')),
                        OutlinedButton(onPressed: addTracking, child: const Text('Add Tracking Number')),
                        OutlinedButton(onPressed: markShipped, child: const Text('Mark as Shipped')),
                        ElevatedButton(onPressed: markDelivered, child: const Text('Mark as Delivered')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
