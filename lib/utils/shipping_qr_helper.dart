String generateShippingQrPayload({
  required String collectionName,
  required String orderDocId,
  required String orderNumber,
  required String artistId,
}) {
  return 'JNT_SHIP|collection=$collectionName|orderDocId=$orderDocId|orderNumber=$orderNumber|artistId=$artistId|action=confirm_shipment';
}

Map<String, dynamic> generateShippingQrCodeData({
  required String requestId,
  required String orderDocId,
  required String collectionName,
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
  return <String, dynamic>{
    'qrCode': generateShippingQrPayload(
      collectionName: collectionName,
      orderDocId: orderDocId,
      orderNumber: orderNumber,
      artistId: artistId,
    ),
    'qrPayload': <String, dynamic>{
      'requestId': requestId,
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
  };
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
  final qr = generateShippingQrCodeData(
    requestId: orderNumber,
    orderDocId: orderDocId,
    collectionName: collectionName,
    orderNumber: orderNumber,
    artistId: artistId,
    artistEmail: artistEmail,
    shippingAddressDifferentFromProfile: shippingAddressDifferentFromProfile,
    shippingStreet: shippingStreet,
    shippingCity: shippingCity,
    shippingState: shippingState,
    shippingZip: shippingZip,
    shippingCountry: shippingCountry,
  );
  return <String, dynamic>{
    'required': true,
    'status': 'label_ready',
    'qrCode': qr['qrCode'],
    'qrPayload': qr['qrPayload'],
    'shippingAddressDifferentFromProfile': shippingAddressDifferentFromProfile,
    'shippingAddress': <String, dynamic>{
      'street': shippingStreet.trim(),
      'city': shippingCity.trim(),
      'state': shippingState.trim(),
      'zip': shippingZip.trim(),
      'country': shippingCountry.trim(),
    },
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'createdBy': 'system',
    'labelUrl': '',
    'trackingNumber': '',
    'carrier': '',
    'shippedAt': null,
    'deliveredAt': null,
    'lastUpdatedAt': DateTime.now().toUtc().toIso8601String(),
  };
}
