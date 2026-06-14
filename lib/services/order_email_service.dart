import 'package:cloud_firestore/cloud_firestore.dart';

class OrderEmailService {
  static Future<void> sendDeliveredReviewTipEmail({
    required String clientEmail,
    required String clientName,
    required String artistName,
    required String orderId,
    required String artistId,
    required String deliveredDate,
    required String trackingNumber,
  }) async {
    final encodedOrderId = Uri.encodeComponent(orderId);
    final encodedArtistId = Uri.encodeComponent(artistId);

    final reviewUrl =
        'https://jnt-app-c3097.web.app/review-order'
        '?orderId=$encodedOrderId'
        '&artistId=$encodedArtistId';

    final tip10Url =
        'https://jnt-app-c3097.web.app/tip-artist'
        '?orderId=$encodedOrderId'
        '&artistId=$encodedArtistId'
        '&tipPercent=10';

    final tip15Url =
        'https://jnt-app-c3097.web.app/tip-artist'
        '?orderId=$encodedOrderId'
        '&artistId=$encodedArtistId'
        '&tipPercent=15';

    final tip20Url =
        'https://jnt-app-c3097.web.app/tip-artist'
        '?orderId=$encodedOrderId'
        '&artistId=$encodedArtistId'
        '&tipPercent=20';

    const appLink = 'https://jnt-app-c3097.web.app/open-app';

    await FirebaseFirestore.instance.collection('mail').add({
      'to': clientEmail,
      'template': {
        'name': 'client_order_delivered_review_tip',
        'data': {
          'clientName': clientName,
          'artistName': artistName,
          'orderId': orderId,
          'artistId': artistId,
          'deliveredDate': deliveredDate,
          'trackingNumber': trackingNumber,
          'reviewUrl': reviewUrl,
          'tip10Url': tip10Url,
          'tip15Url': tip15Url,
          'tip20Url': tip20Url,
          'appLink': appLink,
        },
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}