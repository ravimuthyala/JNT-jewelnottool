import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

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
        uri.queryParameters['mode'] == 'resetPassword';

    if (!isResetPassword) return;

    final oobCode = uri.queryParameters['oobCode'];

    if (oobCode == null || oobCode.isEmpty) return;

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordPage(
          oobCode: oobCode,
          email: uri.queryParameters['email'],
        ),
      ),
    );
  }

  void dispose() {
    _subscription?.cancel();
  }
}