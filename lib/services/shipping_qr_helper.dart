import '../utils/shipping_qr_helper.dart' as qr_utils;

String generateShippingQrPayload({
  required String collectionName,
  required String orderDocId,
  required String orderNumber,
  required String artistId,
}) {
  return qr_utils.generateShippingQrPayload(
    collectionName: collectionName,
    orderDocId: orderDocId,
    orderNumber: orderNumber,
    artistId: artistId,
  );
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
  return qr_utils.generateShippingQrCodeData(
    requestId: requestId,
    orderDocId: orderDocId,
    collectionName: collectionName,
    orderNumber: orderNumber,
    artistId: artistId,
    artistEmail: artistEmail,
    shippingAddressDifferentFromProfile:
        shippingAddressDifferentFromProfile,
    shippingStreet: shippingStreet,
    shippingCity: shippingCity,
    shippingState: shippingState,
    shippingZip: shippingZip,
    shippingCountry: shippingCountry,
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
  return qr_utils.buildShippingPayload(
    collectionName: collectionName,
    orderDocId: orderDocId,
    orderNumber: orderNumber,
    artistId: artistId,
    artistEmail: artistEmail,
    shippingAddressDifferentFromProfile:
        shippingAddressDifferentFromProfile,
    shippingStreet: shippingStreet,
    shippingCity: shippingCity,
    shippingState: shippingState,
    shippingZip: shippingZip,
    shippingCountry: shippingCountry,
  );
}
