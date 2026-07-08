import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/reset_password_page.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    final initialUri = await _appLinks.getInitialLink();

    if (initialUri != null) {
      _handleUri(initialUri, navigatorKey);
    }

    _subscription = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri, navigatorKey);
    });
  }

  void _handleUri(Uri uri, GlobalKey<NavigatorState> navigatorKey) {
    final isResetPassword =
        uri.path.contains('reset-password') ||
        uri.queryParameters['mode'] == 'resetPassword' ||
        uri.queryParameters['type'] == 'recovery' ||
        uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('token_hash') ||
        uri.fragment.contains('access_token=');

    if (!isResetPassword) return;

    try {
      Supabase.instance.client.auth.getSessionFromUrl(uri);
    } catch (_) {}

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordPage(
          oobCode: uri.queryParameters['code'] ??
              uri.queryParameters['token_hash'] ??
              uri.queryParameters['oobCode'] ??
              '',
          email: uri.queryParameters['email'],
        ),
      ),
    );
  }

  void dispose() {
    _subscription?.cancel();
  }
}
