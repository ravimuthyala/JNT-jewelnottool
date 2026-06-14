import '../models/client_request_v2.dart';

class ArtistRequestPoolStore {
  static final List<ClientRequestV2> _items = <ClientRequestV2>[];

  static List<ClientRequestV2> all() =>
      List<ClientRequestV2>.unmodifiable(_items);

  static void add(ClientRequestV2 request) {
    _items.insert(0, request);
  }
}
