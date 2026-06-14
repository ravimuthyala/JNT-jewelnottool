import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class NailMeasurementService {
  static const String _apiUrl = 'http://10.0.2.2:8000/v1/nail-measurements/measure';
  static const String _apiKey = String.fromEnvironment(
    'NAIL_MEASUREMENT_API_KEY',
    defaultValue: '',
  );
  static const bool _enabled = bool.fromEnvironment(
    'ENABLE_NAIL_MEASUREMENT_API',
    defaultValue: false,
  );
  static const int _maxPayloadBytes = 2 * 1024 * 1024;
  static const Duration _requestTimeout = Duration(seconds: 8);
  static const bool _allowLocalhostApi = bool.fromEnvironment(
    'ALLOW_LOCALHOST_NAIL_MEASUREMENT_API',
    defaultValue: false,
  );

  static bool get isEnabled => _enabled;
  static bool get isConfigured {
    if (!isEnabled) return false;
    final uri = Uri.tryParse(_apiUrl.trim());
    if (uri == null) return false;
    final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
    if (!isHttp) return false;
    final host = uri.host.trim().toLowerCase();
    if (host.isEmpty) return false;
    final isLocalHost =
        host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
    if (isLocalHost && !_allowLocalhostApi) return false;
    return true;
  }

  static Future<double?> measureNailWidthMm({
    required Uint8List imageBytes,
    required String hand,
    required String finger,
    required String coinReference,
    String currency = 'USD',
  }) async {
    if (!isConfigured) return null;
    if (imageBytes.isEmpty || imageBytes.lengthInBytes > _maxPayloadBytes) {
      return null;
    }

    final uri = Uri.tryParse(_apiUrl.trim());
    if (uri == null || uri.host.trim().isEmpty) return null;

    final payload = <String, dynamic>{
      'imageBase64': base64Encode(imageBytes),
      'hand': hand,
      'finger': finger,
      'coinReference': coinReference,
      'currency': currency,
    };

    final client = HttpClient();
    try {
      final req = await client.postUrl(uri).timeout(_requestTimeout);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (_apiKey.trim().isNotEmpty) {
        req.headers.set('x-api-key', _apiKey.trim());
      }
      req.write(jsonEncode(payload));
      final res = await req.close().timeout(_requestTimeout);
      final body = await utf8.decoder.bind(res).join().timeout(_requestTimeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final decoded = jsonDecode(body);
      return _extractMm(decoded);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static double? _extractMm(dynamic decoded) {
    if (decoded is num) return decoded.toDouble();
    if (decoded is String) return double.tryParse(decoded.trim());
    if (decoded is! Map) return null;

    final map = decoded.cast<Object?, Object?>();
    final candidates = <Object?>[
      map['measurementMm'],
      map['nailWidthMm'],
      map['widthMm'],
      map['width_mm'],
      map['mm'],
      (map['result'] is Map) ? (map['result'] as Map)['measurementMm'] : null,
      (map['result'] is Map) ? (map['result'] as Map)['nailWidthMm'] : null,
      (map['data'] is Map) ? (map['data'] as Map)['measurementMm'] : null,
      (map['data'] is Map) ? (map['data'] as Map)['nailWidthMm'] : null,
    ];

    for (final candidate in candidates) {
      if (candidate is num) return candidate.toDouble();
      if (candidate is String) {
        final parsed = double.tryParse(candidate.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}
