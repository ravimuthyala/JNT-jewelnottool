import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/client_order_page.dart';
import '../pages/order_details_pages.dart';

/// Order id awaiting the "Rate & Tip" deep link once the user signs in --
/// set when a review-order link is tapped while signed out, consumed by
/// LoginDialog right after a successful login.
String? pendingDeliveredReviewOrderId;

/// Opens [orderId]'s Delivered Review & Tip screen directly -- the target
/// of the `review-order` deep link used in delivered-order emails (see
/// main.dart's `_handleDeepLink` and DeliveredEmailTemplates.client).
///
/// Handles the edge cases from the design:
/// - Not signed in yet: waits briefly for session restoration (matching
///   _SessionHomeGate's own wait), and if still signed out, remembers the
///   order for LoginDialog to resume once the user actually signs in.
/// - Order isn't (or is no longer) delivered: doesn't force the review
///   panel to render against the wrong status.
/// - Wrong account signed in: confirms the session's email matches the
///   order's client or one of its group clients before opening it.
Future<void> openDeliveredReviewOrder(
  NavigatorState navigator,
  String orderId, {
  bool awaitingSignIn = false,
}) async {
  final auth = Supabase.instance.client.auth;

  if (auth.currentSession == null && !awaitingSignIn) {
    final restored = Completer<void>();
    late final StreamSubscription<AuthState> subscription;
    subscription = auth.onAuthStateChange.listen((state) {
      if (!restored.isCompleted) restored.complete();
    });
    try {
      await restored.future.timeout(const Duration(seconds: 2));
    } catch (_) {
    } finally {
      await subscription.cancel();
    }
  }

  if (auth.currentSession == null) {
    pendingDeliveredReviewOrderId = orderId;
    _showMessage(navigator, 'Sign in to view this order and leave a review.');
    return;
  }

  final order = await fetchClientOrderByIdForReview(orderId);
  if (order == null) {
    _showMessage(navigator, "We couldn't find that order.");
    return;
  }

  if (order.rawStatus.trim().toLowerCase() != 'delivered') {
    _showMessage(navigator, 'This order is no longer in a delivered state.');
    return;
  }

  final currentEmail = (auth.currentUser?.email ?? '').trim().toLowerCase();
  final isOwner =
      order.clientEmail.trim().toLowerCase() == currentEmail ||
      order.groupClients.any(
        (g) => g.clientEmail.trim().toLowerCase() == currentEmail,
      );
  if (!isOwner) {
    _showMessage(
      navigator,
      'Sign in with the account this order was placed under to review it.',
    );
    return;
  }

  navigator.push(
    MaterialPageRoute(
      builder: (_) => DeliveredOrderDetailsPage(order: order),
    ),
  );
}

void _showMessage(NavigatorState navigator, String message) {
  ScaffoldMessenger.maybeOf(
    navigator.context,
  )?.showSnackBar(SnackBar(content: Text(message)));
}
