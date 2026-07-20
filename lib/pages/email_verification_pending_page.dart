import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/auth_flags.dart';
import '../services/auth_email_alias_service.dart';
import '../theme/app_colors.dart';

class EmailVerificationPendingPage extends StatefulWidget {
  const EmailVerificationPendingPage({
    super.key,
    required this.email,
    required this.loginPageBuilder,
  });

  final String email;
  final WidgetBuilder loginPageBuilder;

  @override
  State<EmailVerificationPendingPage> createState() =>
      _EmailVerificationPendingPageState();
}

class _EmailVerificationPendingPageState
    extends State<EmailVerificationPendingPage> {
  static const int _resendCooldownSeconds = 60;
  SupabaseClient get _supabase => Supabase.instance.client;
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _cooldown = _resendCooldownSeconds;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (!kRequireEmailVerification) {
      scheduleMicrotask(_navigateToLogin);
      return;
    }
    _startCooldown();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
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
      setState(() {
        _cooldown -= 1;
      });
      if (_cooldown <= 0) {
        timer.cancel();
      }
    });
  }

  Future<void> _navigateToLogin() async {
    if (!mounted) return;
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('EmailVerificationPendingPage: sign out failed: $e');
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: widget.loginPageBuilder),
      (_) => false,
    );
  }

  Future<void> _checkVerified({bool autoNavigate = false}) async {
    if (_busy) return;
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
        _pollTimer?.cancel();
        await _navigateToLogin();
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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: 'Verify your email',
      child: Scaffold(
      backgroundColor: AppColors.snow,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: 430,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.blackCatBorderLight),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      tooltip: 'Close and return to login',
                      onPressed: _navigateToLogin,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      color: AppColors.balletSlippers,
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      size: 52,
                      color: AppColors.blackCat,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Verify Your Email',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'We\'ve sent a verification link to',
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.email,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Please verify your email to continue.',
                    style: TextStyle(fontSize: 20, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
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
                        'I\'ve Verified My Email',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
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
                  const SizedBox(height: 10),
                  Text(
                    _cooldown > 0
                        ? 'Resend available in 00:${_cooldown.toString().padLeft(2, '0')}'
                        : 'You can resend now.',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: _navigateToLogin,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Logout'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
