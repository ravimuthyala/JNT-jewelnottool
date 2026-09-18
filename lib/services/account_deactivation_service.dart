import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a [AccountDeactivationService] call. Mirrors the single JSON
/// shape returned by the `deactivate_own_account` RPC (see
/// supabase/migrations/20260916120000_add_deactivate_own_account.sql) so
/// callers never need to parse raw Supabase responses themselves.
sealed class DeactivateAccountOutcome {
  const DeactivateAccountOutcome();
}

/// The account has one or more orders that haven't reached a final state
/// yet (delivered/declined/cancelled/expired) -- deactivation was refused,
/// nothing was written.
class DeactivateAccountBlocked extends DeactivateAccountOutcome {
  const DeactivateAccountBlocked(this.activeOrderCount);

  final int activeOrderCount;
}

/// No active orders -- safe to show the confirm dialog. Nothing written
/// yet (this is only ever returned from [AccountDeactivationService.
/// checkEligibility], the dry-run call).
class DeactivateAccountEligible extends DeactivateAccountOutcome {
  const DeactivateAccountEligible();
}

/// The account was deactivated. Caller should sign out immediately.
class DeactivateAccountSucceeded extends DeactivateAccountOutcome {
  const DeactivateAccountSucceeded();
}

class DeactivateAccountFailed extends DeactivateAccountOutcome {
  const DeactivateAccountFailed(this.message);

  final String message;
}

class AccountDeactivationService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Read-only dry run -- reports whether the signed-in user currently has
  /// any active orders, without writing anything.
  static Future<DeactivateAccountOutcome> checkEligibility() =>
      _call(confirm: false);

  /// Re-checks the same active-order condition (closing the race where an
  /// order goes active between an initial check and the user confirming)
  /// and, only if still eligible, deactivates the account.
  static Future<DeactivateAccountOutcome> confirmDeactivate() =>
      _call(confirm: true);

  static Future<DeactivateAccountOutcome> _call({
    required bool confirm,
  }) async {
    try {
      final raw = await _client.rpc(
        'deactivate_own_account',
        params: {'p_confirm': confirm},
      );
      final data = Map<String, dynamic>.from(raw as Map);
      switch (data['result']) {
        case 'blocked':
          return DeactivateAccountBlocked(
            (data['active_order_count'] as num?)?.toInt() ?? 0,
          );
        case 'eligible':
          return const DeactivateAccountEligible();
        case 'deactivated':
          return const DeactivateAccountSucceeded();
        default:
          return DeactivateAccountFailed(
            (data['message'] ?? 'Unable to deactivate account.').toString(),
          );
      }
    } catch (e) {
      debugPrint('AccountDeactivationService._call failed: $e');
      return const DeactivateAccountFailed(
        'Unable to deactivate account. Please try again.',
      );
    }
  }
}
