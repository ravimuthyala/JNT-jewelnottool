import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/auth_flags.dart';
import '../services/auth_email_alias_service.dart';
import '../theme/app_colors.dart';

/// Shows the post-registration "check your email" gate as a modal bottom
/// sheet on top of whatever the caller already navigated to.
///
/// Option 2 (auto sign-in after confirmation): the caller is expected to
/// have ALREADY pushed the signed-in destination (the role's home/shell)
/// before calling this, so on success this modal only needs to dismiss
/// itself -- there's no separate navigation/role-resolution step. If the
/// user backs out instead (close button / "Not you? Log out"), the whole
/// stack under this modal -- shell included -- is replaced with
/// [loginPageBuilder] after signing out.
Future<void> showEmailVerificationPendingModal({
  required BuildContext context,
  required String email,
  required WidgetBuilder loginPageBuilder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _EmailVerificationPendingSheet(
      email: email,
      loginPageBuilder: loginPageBuilder,
    ),
  );
}

class _EmailVerificationPendingSheet extends StatefulWidget {
  const _EmailVerificationPendingSheet({
    required this.email,
    required this.loginPageBuilder,
  });

  final String email;
  final WidgetBuilder loginPageBuilder;

  @override
  State<_EmailVerificationPendingSheet> createState() =>
      _EmailVerificationPendingSheetState();
}

class _EmailVerificationPendingSheetState
    extends State<_EmailVerificationPendingSheet>
    with SingleTickerProviderStateMixin {
  static const int _resendCooldownSeconds = 60;
  static const Color _successColor = Color(0xFF1E8E5A);
  static const Color _successBg = Color(0xFFDBF4E6);

  SupabaseClient get _supabase => Supabase.instance.client;
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _cooldown = _resendCooldownSeconds;
  bool _busy = false;
  bool _confirmed = false;
  bool _dismissed = false;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _startCooldown();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkVerified(autoNavigate: true);
    });
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldown = _resendCooldownSeconds;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _cooldown -= 1);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  /// Deliberate "not me / abandon this account" escape hatch -- unlike the
  /// success path, this DOES sign out, and replaces the whole stack
  /// (including the already-shown shell underneath this modal) with
  /// [loginPageBuilder].
  Future<void> _abortAndReturnToStart() async {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) navigator.pop();
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('EmailVerificationPendingSheet: sign out failed: $e');
    }
    if (!navigator.mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: widget.loginPageBuilder),
      (_) => false,
    );
  }

  Future<void> _dismissWhenReady() async {
    if (_dismissed) return;
    _dismissed = true;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _onConfirmed() async {
    if (_confirmed) return;
    _pollTimer?.cancel();
    setState(() => _confirmed = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await _dismissWhenReady();
  }

  Future<void> _checkVerified({bool autoNavigate = false}) async {
    if (_busy || _confirmed) return;
    _busy = true;
    try {
      final auth = _supabase.auth;
      final user = auth.currentUser;
      if (user == null) return;
      await auth.refreshSession();
      final refreshed = auth.currentUser;
      if (refreshed?.emailConfirmedAt != null) {
        final uid = refreshed?.id;
        final authEmail = refreshed?.email;
        if (uid != null && (authEmail ?? '').isNotEmpty) {
          await AuthEmailAliasService.saveAliasMapping(
            loginEmail: widget.email,
            authEmail: authEmail!,
            uid: uid,
          );
        }
        await _onConfirmed();
      } else if (!autoNavigate && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email not verified yet. Please check your inbox.'),
          ),
        );
      }
    } catch (_) {
      if (!autoNavigate && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to refresh verification state. Try again.'),
          ),
        );
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_cooldown > 0) return;
    try {
      final email = (_supabase.auth.currentUser?.email ?? '').trim();
      if (email.isEmpty) return;
      await _supabase.auth.resend(type: OtpType.signup, email: email);
      _startCooldown();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to resend verification email.')),
      );
    }
  }

  /// TEST-ONLY: marks the signed-in user's own email as confirmed via the
  /// `simulate_confirm_current_user_email` RPC, then re-runs the normal
  /// confirmation check so the rest of the flow (alias mapping, transition,
  /// dismiss) is identical to a real confirmation. Gated behind
  /// kEnableEmailVerificationTestSimulation -- see auth_flags.dart.
  Future<void> _simulateConfirmation() async {
    if (_busy || _confirmed) return;
    _busy = true;
    try {
      await _supabase.rpc('simulate_confirm_current_user_email');
      _busy = false;
      await _checkVerified(autoNavigate: true);
    } catch (e) {
      debugPrint(
        'EmailVerificationPendingSheet: simulate confirmation failed: $e',
      );
      _busy = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not simulate confirmation. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: _confirmed ? 'Email confirmed, signing you in' : 'Verify your email',
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 480),
            margin: const EdgeInsets.symmetric(horizontal: 0),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            decoration: const BoxDecoration(
              color: AppColors.snow,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: _confirmed ? _confirmedContent() : _waitingContent(),
          ),
        ),
      ),
    );
  }

  Widget _dragHandle() => Center(
    child: Container(
      width: 44,
      height: 5,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.blackCatBorderLight,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );

  Widget _waitingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dragHandle(),
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            tooltip: 'Close and return to login',
            onPressed: _abortAndReturnToStart,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: AppColors.balletSlippers,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 40,
              color: AppColors.blackCat,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Check your email',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'We sent a confirmation link to',
          style: TextStyle(fontSize: 14, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          widget.email,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _liveWaitingIndicator(),
        const SizedBox(height: 22),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blackCat,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _checkVerified(autoNavigate: false),
            child: const Text(
              "I've Verified — Check Now",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              // The app-wide OutlinedButtonTheme (main.dart) defaults to a
              // dark fill with light text; without an explicit
              // backgroundColor override here, dark foreground text/icon
              // renders on that same dark fill underneath -- invisible.
              backgroundColor: AppColors.snow,
              foregroundColor: AppColors.blackCat,
              side: const BorderSide(color: AppColors.blackCat),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _cooldown > 0 ? null : _resendVerificationEmail,
            icon: const Icon(Icons.send_outlined),
            label: const Text(
              'Resend Verification Email',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _cooldown > 0
              ? 'Resend available in 00:${_cooldown.toString().padLeft(2, '0')}'
              : 'You can resend now.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 12.5),
        ),
        if (kEnableEmailVerificationTestSimulation) ...[
          const SizedBox(height: 18),
          Container(height: 1, color: AppColors.blackCatBorderLight),
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.snow,
                foregroundColor: AppColors.blackCatLight,
                side: const BorderSide(color: AppColors.blackCatLight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _simulateConfirmation,
              icon: const Icon(Icons.science_outlined, size: 18),
              label: const Text(
                'Simulate Email Confirmation (Test)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _abortAndReturnToStart,
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.blackCatLight,
          ),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Not you? Log out'),
        ),
      ],
    );
  }

  Widget _liveWaitingIndicator() {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Center(
      child: Semantics(
        liveRegion: true,
        label: 'Waiting for email confirmation',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.alabaster,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: reduceMotion
                    ? _dot()
                    : AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final t = _pulseController.value;
                          return SizedBox(
                            width: 16,
                            height: 16,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Opacity(
                                  opacity: (1 - t).clamp(0.0, 1.0),
                                  child: Transform.scale(
                                    scale: 1 + t * 1.6,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _successColor,
                                          width: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                _dot(),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Waiting for confirmation…',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackCatLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot() => Container(
    width: 7,
    height: 7,
    decoration: const BoxDecoration(shape: BoxShape.circle, color: _successColor),
  );

  Widget _confirmedContent() {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      liveRegion: true,
      label: 'Email confirmed. Signing you in.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dragHandle(),
          const SizedBox(height: 20),
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!reduceMotion)
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      final t = _pulseController.value;
                      return Opacity(
                        opacity: (1 - t).clamp(0.0, 1.0) * 0.6,
                        child: Transform.scale(
                          scale: 1 + t * 0.5,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _successColor,
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: _successBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 36,
                    color: _successColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Email confirmed!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                'Signing you in…',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: _dismissWhenReady,
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.blackCatLight,
            ),
            child: const Text(
              'Taking a while? Tap to continue',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
