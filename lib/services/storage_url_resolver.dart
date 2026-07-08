import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class StorageUrlResolver {
  StorageUrlResolver._();

  static final Map<String, String> _resolved = <String, String>{};
  static final Set<String> _missing = <String>{};
  static final Map<String, Future<String?>> _inflight = <String, Future<String?>>{};

  static Future<String?> resolve(String raw) {
    final key = _normalize(raw);
    if (key.isEmpty) return Future<String?>.value(null);
    final cached = _resolved[key];
    if (cached != null && cached.isNotEmpty) return Future<String?>.value(cached);
    if (_missing.contains(key)) return Future<String?>.value(null);

    final existing = _inflight[key];
    if (existing != null) return existing;

    final future = _resolveInternal(key);
    _inflight[key] = future;
    return future.whenComplete(() {
      _inflight.remove(key);
    });
  }

  static Future<String?> _resolveInternal(String key) async {
    try {
      final parsed = _parseStorageReference(key);
      if (parsed == null) {
        if (key.startsWith('data:') ||
            key.startsWith('blob:') ||
            key.startsWith('content://') ||
            key.startsWith('http://') ||
            key.startsWith('https://')) {
          return key;
        }
        _missing.add(key);
        return null;
      }

      final url = Supabase.instance.client.storage
          .from(parsed.bucket)
          .getPublicUrl(parsed.objectPath);
      final trimmed = url.trim();
      if (trimmed.isEmpty) {
        _missing.add(key);
        return null;
      }
      _resolved[key] = trimmed;
      return trimmed;
    } catch (_) {
      _missing.add(key);
      return null;
    }
  }

  static ({String bucket, String objectPath})? _parseStorageReference(String key) {
    var value = key.trim();
    if (value.isEmpty) return null;

    if (value.startsWith('gs://')) {
      value = value.substring(5);
      final slash = value.indexOf('/');
      if (slash < 0 || slash + 1 >= value.length) return null;
      return (
        bucket: value.substring(0, slash),
        objectPath: value.substring(slash + 1),
      );
    }

    if (value.startsWith('storage/v1/object/public/')) {
      value = value.substring('storage/v1/object/public/'.length);
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      final uri = Uri.tryParse(value);
      if (uri == null) return null;
      if (!uri.host.contains('supabase.co')) return null;
      final segments = uri.pathSegments;
      final index = segments.indexOf('public');
      if (index >= 0 && index + 2 <= segments.length) {
        final bucket = segments[index + 1];
        final objectPath = Uri.decodeComponent(segments.sublist(index + 2).join('/'));
        if (bucket.isNotEmpty && objectPath.isNotEmpty) {
          return (bucket: bucket, objectPath: objectPath);
        }
      }
      return null;
    }

    value = value.replaceAll(RegExp(r'^/+'), '');
    final parts = value.split('/');
    if (parts.length < 2) return null;
    return (bucket: parts.first, objectPath: parts.skip(1).join('/'));
  }

  static String _normalize(String raw) {
    var key = raw.trim();
    if (key.isEmpty) return '';
    if (key.startsWith('assets/')) {
      final rest = key.substring('assets/'.length);
      final decodedRest = Uri.decodeFull(rest);
      if (rest.startsWith('data:') ||
          rest.startsWith('blob:') ||
          rest.startsWith('http://') ||
          rest.startsWith('https://') ||
          rest.startsWith('gs://') ||
          decodedRest.startsWith('data:') ||
          decodedRest.startsWith('blob:') ||
          decodedRest.startsWith('http://') ||
          decodedRest.startsWith('https://') ||
          decodedRest.startsWith('gs://')) {
        key = decodedRest;
      }
    }
    if (key.startsWith('data%3A') ||
        key.startsWith('blob%3A') ||
        key.startsWith('http%3A') ||
        key.startsWith('https%3A') ||
        key.startsWith('gs%3A')) {
      key = Uri.decodeFull(key);
    }
    return key.trim();
  }
}
