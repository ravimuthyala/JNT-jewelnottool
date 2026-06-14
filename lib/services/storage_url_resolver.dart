import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';

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
      final String url;
      if (key.startsWith('gs://')) {
        url = await FirebaseStorage.instance.refFromURL(key).getDownloadURL();
      } else if (key.startsWith('http://') || key.startsWith('https://')) {
        final reparsed = await _resolveFirebaseStorageHttpUrl(key);
        url = reparsed ?? key;
      } else if (key.startsWith('data:') ||
          key.startsWith('blob:') ||
          key.startsWith('content://')) {
        url = key;
      } else {
        url = await FirebaseStorage.instance.ref(key).getDownloadURL();
      }
      final trimmed = url.trim();
      if (trimmed.isEmpty) {
        _missing.add(key);
        return null;
      }
      _resolved[key] = trimmed;
      return trimmed;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found' || e.code == '404') {
        _missing.add(key);
        return null;
      }
      rethrow;
    } catch (_) {
      _missing.add(key);
      return null;
    }
  }

  static Future<String?> _resolveFirebaseStorageHttpUrl(String key) async {
    try {
      final uri = Uri.tryParse(key);
      if (uri == null) return null;
      if (!uri.host.contains('firebasestorage.googleapis.com')) return null;
      final segments = uri.pathSegments;
      final oIndex = segments.indexOf('o');
      if (oIndex == -1 || oIndex + 1 >= segments.length) return null;
      final encodedObjectPath = segments[oIndex + 1];
      final objectPath = Uri.decodeComponent(encodedObjectPath).trim();
      if (objectPath.isEmpty) return null;
      return await FirebaseStorage.instance.ref(objectPath).getDownloadURL();
    } catch (_) {
      return null;
    }
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
