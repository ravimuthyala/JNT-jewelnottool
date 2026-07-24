import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class NailMeasurementService {
  static const String _apiUrl = String.fromEnvironment(
    'NAIL_MEASUREMENT_API_URL',
    defaultValue:
        'https://uolyyyq9ih.execute-api.us-east-2.amazonaws.com/measure/single-finger',
  );
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
    required String coinName,
    required double coinDiameterMm,
  }) async {
    if (!isConfigured) return null;
    if (imageBytes.isEmpty || imageBytes.lengthInBytes > _maxPayloadBytes) {
      return null;
    }

    final baseUri = Uri.tryParse(_apiUrl.trim());
    if (baseUri == null || baseUri.host.trim().isEmpty) return null;

    final uri = baseUri.replace(
      queryParameters: {
        ...baseUri.queryParameters,
        'hand': hand,
        'finger': finger,
        'coinName': coinName,
        'coinDiameterMm': coinDiameterMm.toString(),
      },
    );

    try {
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            imageBytes,
            filename: 'nail.jpg',
          ),
        );
      if (_apiKey.trim().isNotEmpty) {
        request.headers['x-api-key'] = _apiKey.trim();
      }

      final streamedRes = await request.send().timeout(_requestTimeout);
      final res = await http.Response.fromStream(streamedRes).timeout(
        _requestTimeout,
      );
      print('[CLIENT-REG] API Response Status: ${res.statusCode}, Body: ${res.body}');
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(res.body);
      return _extractMm(decoded);
    } catch (e, stack) {
      print('[CLIENT-REG] API Connection Exception: $e');
      print(stack);
      return null;
    }
  }

  /// Calls /measure/full-hand so one photo returns widths for all 5 fingers
  /// of [hand] at once, instead of one photo per finger.
  static Future<Map<String, double>?> measureFullHandMm({
    required Uint8List imageBytes,
    required String hand,
    required String coinName,
    required double coinDiameterMm,
  }) async {
    if (!isConfigured) return null;
    if (imageBytes.isEmpty || imageBytes.lengthInBytes > _maxPayloadBytes) {
      return null;
    }

    final baseUri = Uri.tryParse(_apiUrl.trim());
    if (baseUri == null || baseUri.host.trim().isEmpty) return null;

    final fullHandPath = baseUri.path.replaceFirst(
      RegExp(r'/measure/[^/]+$'),
      '/measure/full-hand',
    );
    final uri = baseUri.replace(
      path: fullHandPath,
      queryParameters: {
        'hand': hand,
        'coinName': coinName,
        'coinDiameterMm': coinDiameterMm.toString(),
      },
    );

    try {
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            imageBytes,
            filename: 'hand.jpg',
          ),
        );
      if (_apiKey.trim().isNotEmpty) {
        request.headers['x-api-key'] = _apiKey.trim();
      }

      final streamedRes = await request.send().timeout(_requestTimeout);
      final res = await http.Response.fromStream(streamedRes).timeout(
        _requestTimeout,
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final measurements = decoded['measurements'];
      if (measurements is! Map) return null;

      final result = <String, double>{};
      for (final entry in measurements.entries) {
        final finger = entry.value;
        if (finger is! Map) continue;
        final widthMm = finger['widthMm'];
        if (widthMm is num) {
          result[entry.key as String] = widthMm.toDouble();
        }
      }
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
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
