import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Client for the jnt_nail_measurement_api "two-shot" full-hand flow:
/// 2 photos per hand (4 fingers together, then thumb alone) instead of
/// one photo per finger.
///
/// The old single-photo-per-finger endpoints (/measure/full-hand,
/// /measure/full-hand-debug) are disabled server-side (410) and must not
/// be called from this app.
class FullHandMeasurementService {
  // TODO: point this at the real jnt_nail_measurement_api host/port.
  static const String _apiBaseUrl = 'http://10.0.2.2:8000/measure';

  static const String _apiKey = String.fromEnvironment(
    'FULL_HAND_MEASUREMENT_API_KEY',
    defaultValue: '',
  );
  static const bool _enabled = bool.fromEnvironment(
    'ENABLE_FULL_HAND_MEASUREMENT_API',
    defaultValue: false,
  );
  static const bool _allowLocalhostApi = bool.fromEnvironment(
    'ALLOW_LOCALHOST_FULL_HAND_MEASUREMENT_API',
    defaultValue: false,
  );

  // TODO: replace with real tenant identifiers once this app models
  // company/app accounts for the measurement API. Placeholders keep the
  // two-shot submit call shaped correctly until those exist.
  static const String defaultCompanyId = 'TODO_COMPANY_ID';
  static const String defaultAppId = 'TODO_APP_ID';
  static const String defaultMeasurementProfile = 'default';
  static const String defaultCalibrationMode = 'auto';

  static const int _maxPayloadBytes = 6 * 1024 * 1024;
  static const Duration _requestTimeout = Duration(seconds: 15);

  static bool get isEnabled => _enabled;

  static bool get isConfigured {
    if (!isEnabled) return false;
    final uri = Uri.tryParse(_apiBaseUrl.trim());
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

  static Future<TwoShotCheckResult?> checkShot({
    required Uint8List imageBytes,
    required String hand,
    required String shotType,
    required String coinName,
    required double coinDiameterMm,
  }) async {
    final decoded = await _postMultipart(
      pathSegment: 'full-hand-two-shot-check',
      fields: {
        'hand': hand,
        'shotType': shotType,
        'coinName': coinName,
        'coinDiameterMm': coinDiameterMm.toString(),
      },
      files: {'file': imageBytes},
    );
    if (decoded == null) return null;
    return TwoShotCheckResult.fromJson(decoded);
  }

  static Future<TwoShotResult?> submitTwoShot({
    required Uint8List fourFingerBytes,
    required Uint8List thumbBytes,
    required String hand,
    required String coinName,
    required double coinDiameterMm,
    String companyId = defaultCompanyId,
    String appId = defaultAppId,
    String measurementProfile = defaultMeasurementProfile,
    String calibrationMode = defaultCalibrationMode,
  }) async {
    final decoded = await _postMultipart(
      pathSegment: 'full-hand-two-shot',
      fields: {
        'hand': hand,
        'coinName': coinName,
        'coinDiameterMm': coinDiameterMm.toString(),
        'companyId': companyId,
        'appId': appId,
        'measurementProfile': measurementProfile,
        'calibrationMode': calibrationMode,
      },
      files: {'fourFingerFile': fourFingerBytes, 'thumbFile': thumbBytes},
    );
    if (decoded == null) return null;
    return TwoShotResult.fromJson(decoded);
  }

  static Future<Map<String, dynamic>?> _postMultipart({
    required String pathSegment,
    required Map<String, String> fields,
    required Map<String, Uint8List> files,
  }) async {
    if (!isConfigured) return null;
    for (final bytes in files.values) {
      if (bytes.isEmpty || bytes.lengthInBytes > _maxPayloadBytes) {
        return null;
      }
    }

    final uri = Uri.tryParse('$_apiBaseUrl/$pathSegment');
    if (uri == null || uri.host.trim().isEmpty) return null;

    final boundary =
        '----jnt-boundary-${DateTime.now().microsecondsSinceEpoch}';
    final body = _buildMultipartBody(boundary, fields, files);

    final client = HttpClient();
    try {
      final req = await client.postUrl(uri).timeout(_requestTimeout);
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      req.headers.set(HttpHeaders.contentLengthHeader, body.length);
      if (_apiKey.trim().isNotEmpty) {
        req.headers.set('x-api-key', _apiKey.trim());
      }
      req.add(body);
      final res = await req.close().timeout(_requestTimeout);
      final respBody = await utf8.decoder
          .bind(res)
          .join()
          .timeout(_requestTimeout);

      // 410 = endpoint disabled server-side; nothing to recover from here.
      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final decoded = jsonDecode(respBody);
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (e) {
      debugPrint('FullHandMeasurementService request failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Uint8List _buildMultipartBody(
    String boundary,
    Map<String, String> fields,
    Map<String, Uint8List> files,
  ) {
    final builder = BytesBuilder();
    void writeString(String s) => builder.add(utf8.encode(s));

    fields.forEach((name, value) {
      writeString('--$boundary\r\n');
      writeString('Content-Disposition: form-data; name="$name"\r\n\r\n');
      writeString('$value\r\n');
    });

    files.forEach((fieldName, bytes) {
      writeString('--$boundary\r\n');
      writeString(
        'Content-Disposition: form-data; name="$fieldName"; filename="$fieldName.jpg"\r\n',
      );
      writeString('Content-Type: image/jpeg\r\n\r\n');
      builder.add(bytes);
      writeString('\r\n');
    });

    writeString('--$boundary--\r\n');
    return builder.toBytes();
  }
}

class TwoShotCheckResult {
  const TwoShotCheckResult({
    required this.ok,
    this.hand,
    this.shotType,
    this.quality,
    this.coin,
    this.message,
  });

  final bool ok;
  final String? hand;
  final String? shotType;
  final Map<String, dynamic>? quality;
  final Map<String, dynamic>? coin;
  final String? message;

  factory TwoShotCheckResult.fromJson(Map<String, dynamic> json) {
    return TwoShotCheckResult(
      ok: json['ok'] == true,
      hand: json['hand'] as String?,
      shotType: json['shotType'] as String?,
      quality: (json['quality'] as Map?)?.cast<String, dynamic>(),
      coin: (json['coin'] as Map?)?.cast<String, dynamic>(),
      message: json['message'] as String?,
    );
  }

  List<String> get issues {
    final raw = quality?['issues'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).toList(growable: false);
  }
}

class FingerMeasurement {
  const FingerMeasurement({
    required this.status,
    this.widthMm,
    this.lengthMm,
    this.confidence,
    this.message,
  });

  final String status;
  final double? widthMm;
  final double? lengthMm;
  final double? confidence;
  final String? message;

  bool get isDetected => status != 'not_detected';

  factory FingerMeasurement.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) => v is num ? v.toDouble() : null;
    return FingerMeasurement(
      status: (json['status'] as String?) ?? 'not_detected',
      widthMm: asDouble(json['widthMm']),
      lengthMm: asDouble(json['lengthMm']),
      confidence: asDouble(json['confidence']),
      message: json['message'] as String?,
    );
  }
}

class TwoShotResult {
  const TwoShotResult({
    required this.ok,
    this.hand,
    this.issues,
    this.fourFingerQuality,
    this.thumbQuality,
    this.fourFingerCoin,
    this.thumbCoin,
    this.measurements,
    this.tenant,
    this.message,
  });

  final bool ok;
  final String? hand;
  final List<String>? issues;
  final Map<String, dynamic>? fourFingerQuality;
  final Map<String, dynamic>? thumbQuality;
  final Map<String, dynamic>? fourFingerCoin;
  final Map<String, dynamic>? thumbCoin;
  final Map<String, FingerMeasurement>? measurements;
  final String? tenant;
  final String? message;

  factory TwoShotResult.fromJson(Map<String, dynamic> json) {
    Map<String, FingerMeasurement>? measurements;
    final rawMeasurements = json['measurements'];
    if (rawMeasurements is Map) {
      measurements = rawMeasurements.map(
        (key, value) => MapEntry(
          key.toString(),
          FingerMeasurement.fromJson((value as Map).cast<String, dynamic>()),
        ),
      );
    }

    return TwoShotResult(
      ok: json['ok'] == true,
      hand: json['hand'] as String?,
      issues: (json['issues'] as List?)?.map((e) => e.toString()).toList(),
      fourFingerQuality: (json['fourFingerQuality'] as Map?)
          ?.cast<String, dynamic>(),
      thumbQuality: (json['thumbQuality'] as Map?)?.cast<String, dynamic>(),
      fourFingerCoin: (json['fourFingerCoin'] as Map?)
          ?.cast<String, dynamic>(),
      thumbCoin: (json['thumbCoin'] as Map?)?.cast<String, dynamic>(),
      measurements: measurements,
      tenant: json['tenant'] as String?,
      message: json['message'] as String?,
    );
  }
}
