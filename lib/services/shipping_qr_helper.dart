import 'package:cloud_firestore/cloud_firestore.dart';

String generateShippingQrPayload({
  required String collectionName,
  required String orderDocId,
  required String orderNumber,
  required String artistId,
}) {
  return 'JNT_SHIP|collection=$collectionName|orderDocId=$orderDocId|orderNumber=$orderNumber|artistId=$artistId|action=confirm_shipment';
}

String generateShippingQrCode({
  required String collectionName,
  required String orderDocId,
  required String orderNumber,
  required String artistId,
}) {
  return generateShippingQrPayload(
    collectionName: collectionName,
    orderDocId: orderDocId,
    orderNumber: orderNumber,
    artistId: artistId,
  );
}

Map<String, dynamic> buildShippingPayload({
  required String collectionName,
  required String orderDocId,
  required String orderNumber,
  required String artistId,
  required String artistEmail,
  bool shippingAddressDifferentFromProfile = false,
  String shippingStreet = '',
  String shippingCity = '',
  String shippingState = '',
  String shippingZip = '',
  String shippingCountry = '',
}) {
  final qrCode = generateShippingQrCode(
    collectionName: collectionName,
    orderDocId: orderDocId,
    orderNumber: orderNumber,
    artistId: artistId,
  );
  return <String, dynamic>{
    'required': true,
    'status': 'label_ready',
    'qrCode': qrCode,
    'qrPayload': <String, dynamic>{
      'requestId': orderDocId,
      'orderDocId': orderDocId,
      'collectionName': collectionName,
      'orderNumber': orderNumber,
      'artistId': artistId,
      'artistEmail': artistEmail,
      'shippingAddressDifferentFromProfile':
          shippingAddressDifferentFromProfile,
      'shippingAddress': <String, dynamic>{
        'street': shippingStreet.trim(),
        'city': shippingCity.trim(),
        'state': shippingState.trim(),
        'zip': shippingZip.trim(),
        'country': shippingCountry.trim(),
      },
      'action': 'confirm_shipment',
    },
    'shippingAddressDifferentFromProfile': shippingAddressDifferentFromProfile,
    'shippingAddress': <String, dynamic>{
      'street': shippingStreet.trim(),
      'city': shippingCity.trim(),
      'state': shippingState.trim(),
      'zip': shippingZip.trim(),
      'country': shippingCountry.trim(),
    },
    'createdAt': FieldValue.serverTimestamp(),
    'createdBy': 'system',
    'labelUrl': '',
    'trackingNumber': '',
    'carrier': '',
    'shippedAt': null,
    'deliveredAt': null,
    'lastUpdatedAt': FieldValue.serverTimestamp(),
  };
}
