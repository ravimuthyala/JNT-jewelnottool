// lib/utils/logout_helper.dart
import 'package:flutter/material.dart';

/// Logs out (your auth later) and takes user to the app landing route.
/// Works even if you don't use Firebase yet.
///
/// IMPORTANT: Make sure your MaterialApp has a route named '/'.
Future<void> logoutAndGoHome(BuildContext context) async {

  if (!context.mounted) return;

  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
}
