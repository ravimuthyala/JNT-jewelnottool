import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Client for the jnt_nail_measurement_api "two-shot" full-hand flow:
/// 2 photos per hand (4 fingers together, then thumb alone).
///
/// The old single-photo /measure/full-hand and /measure/full-hand-debug
/// endpoints are retired server-side (410 Gone) — do not call them.
/// All /measure/* routes require an `x-api-key` header.
class FullHandMeasurementService {
  static const String _apiBaseUrl = String.fromEnvironment(
    'FULL_HAND_MEASUREMENT_API_URL',
    defaultValue:
        'https://uolyyyq9ih.execute-api.us-east-2.amazonaws.com/measure',
  );

  // ponytail: hardcoded test-only default so plain `flutter run` works
  // without flags. MUST be overridden via --dart-define-from-file for any
  // real release build — see docs/PLAYSTORE_API_COST_PRECAUTIONS.md.
  static const String _apiKey = String.fromEnvironment(
    'FULL_HAND_MEASUREMENT_API_KEY',
    defaultValue: 'HOGfjqLWN1I8UX5P8lB_V5tir3uqMR-B3vdHI21tXQU',
  );
  static const bool _enabled = bool.fromEnvironment(
    'ENABLE_FULL_HAND_MEASUREMENT_API',
    defaultValue: true,
  );
  static const bool _allowLocalhostApi = bool.fromEnvironment(
    'ALLOW_LOCALHOST_FULL_HAND_MEASUREMENT_API',
    defaultValue: false,
  );

  static const int _maxPayloadBytes = 6 * 1024 * 1024;
  static const Duration _requestTimeout = Duration(seconds: 40);

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

  /// Set after every call (success or failure) so the UI can show the real
  /// reason instead of a generic "unable to connect" message.
  static String? lastError;

  static Future<TwoShotCheckResult?> checkShot({
    required Uint8List imageBytes,
    required String hand,
    required String shotType,
    required String coinName,
    required double coinDiameterMm,
  }) async {
    final decoded = await _postMultipart(
      pathSegment: 'full-hand-two-shot-check',
      queryParameters: {
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
  }) async {
    final decoded = await _postMultipart(
      pathSegment: 'full-hand-two-shot',
      queryParameters: {
        'hand': hand,
        'coinName': coinName,
        'coinDiameterMm': coinDiameterMm.toString(),
      },
      files: {'fourFingerFile': fourFingerBytes, 'thumbFile': thumbBytes},
    );
    if (decoded == null) return null;
    return TwoShotResult.fromJson(decoded);
  }

  static Future<Map<String, dynamic>?> _postMultipart({
    required String pathSegment,
    required Map<String, String> queryParameters,
    required Map<String, Uint8List> files,
  }) async {
    lastError = null;
    if (!isConfigured) {
      lastError =
          'FullHandMeasurementService not configured '
          '(enabled=$_enabled, url=$_apiBaseUrl)';
      debugPrint(lastError);
      return null;
    }
    for (final bytes in files.values) {
      if (bytes.isEmpty || bytes.lengthInBytes > _maxPayloadBytes) {
        lastError =
            'Image payload invalid or too large '
            '(${bytes.lengthInBytes} bytes)';
        debugPrint(lastError);
        return null;
      }
    }

    final baseUri = Uri.tryParse('$_apiBaseUrl/$pathSegment');
    if (baseUri == null || baseUri.host.trim().isEmpty) {
      lastError = 'Invalid API URL: $_apiBaseUrl/$pathSegment';
      debugPrint(lastError);
      return null;
    }
    final uri = baseUri.replace(queryParameters: queryParameters);

    try {
      final request = http.MultipartRequest('POST', uri);
      files.forEach((fieldName, bytes) {
        request.files.add(
          http.MultipartFile.fromBytes(
            fieldName,
            bytes,
            filename: '$fieldName.jpg',
          ),
        );
      });
      if (_apiKey.trim().isNotEmpty) {
        request.headers['x-api-key'] = _apiKey.trim();
      }

      final streamedRes = await request.send().timeout(_requestTimeout);
      final res = await http.Response.fromStream(
        streamedRes,
      ).timeout(_requestTimeout);

      debugPrint(
        'FullHandMeasurementService POST $uri -> ${res.statusCode}: ${res.body}',
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        lastError = 'HTTP ${res.statusCode}: ${res.body}';
        return null;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is Map) return decoded.cast<String, dynamic>();
      lastError = 'Unexpected response shape: ${res.body}';
      return null;
    } catch (e, stack) {
      lastError = '$e';
      debugPrint('FullHandMeasurementService request failed: $e\n$stack');
      return null;
    }
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

  factory FingerMeasurement.fromJson(dynamic json) {
    if (json is! Map) return const FingerMeasurement(status: 'not_detected');
    final map = json.cast<String, dynamic>();
    double? asDouble(dynamic v) => v is num ? v.toDouble() : null;
    return FingerMeasurement(
      status: (map['status'] as String?) ?? 'not_detected',
      widthMm: asDouble(map['widthMm']),
      lengthMm: asDouble(map['lengthMm']),
      confidence: asDouble(map['confidence']),
      message: map['message'] as String?,
    );
  }
}

class TwoShotResult {
  const TwoShotResult({
    required this.ok,
    this.status,
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
  final String? status;
  final String? hand;
  final List<String>? issues;
  final Map<String, dynamic>? fourFingerQuality;
  final Map<String, dynamic>? thumbQuality;
  final Map<String, dynamic>? fourFingerCoin;
  final Map<String, dynamic>? thumbCoin;
  final Map<String, FingerMeasurement>? measurements;
  final Map<String, dynamic>? tenant;
  final String? message;

  factory TwoShotResult.fromJson(Map<String, dynamic> json) {
    Map<String, FingerMeasurement>? measurements;
    final rawMeasurements = json['measurements'];
    if (rawMeasurements is Map) {
      measurements = rawMeasurements.map(
        (key, value) =>
            MapEntry(key.toString(), FingerMeasurement.fromJson(value)),
      );
    }

    return TwoShotResult(
      ok: json['ok'] == true,
      status: json['status'] as String?,
      hand: json['hand'] as String?,
      issues: (json['issues'] as List?)?.map((e) => e.toString()).toList(),
      fourFingerQuality: (json['fourFingerQuality'] as Map?)
          ?.cast<String, dynamic>(),
      thumbQuality: (json['thumbQuality'] as Map?)?.cast<String, dynamic>(),
      fourFingerCoin: (json['fourFingerCoin'] as Map?)
          ?.cast<String, dynamic>(),
      thumbCoin: (json['thumbCoin'] as Map?)?.cast<String, dynamic>(),
      measurements: measurements,
      tenant: (json['tenant'] as Map?)?.cast<String, dynamic>(),
      message: json['message'] as String?,
    );
  }

  /// Whether the four-finger shot is implicated in this failure — either its
  /// own quality check failed, or one of [issues] is prefixed "Four-finger
  /// photo:" (segmentation/measurement issues are only ever reported this
  /// way, not via [fourFingerQuality]).
  bool get fourFingerHasIssue =>
      fourFingerQuality?['ok'] == false ||
      (issues ?? const []).any((i) => i.startsWith('Four-finger photo:'));

  /// Same as [fourFingerHasIssue], for the thumb shot.
  bool get thumbHasIssue =>
      thumbQuality?['ok'] == false ||
      (issues ?? const []).any((i) => i.startsWith('Thumb photo:'));
}
