import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/supabase_auth_service.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.oobCode, this.email});

  final String oobCode;
  final String? email;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _resolvedEmail;

  @override
  void initState() {
    super.initState();
    _verifyCode();
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    try {
      final email =
          SupabaseAuthService.currentUser?.email ?? widget.email ?? '';
      if (!mounted) return;
      if (SupabaseAuthService.currentUser == null) {
        setState(() {
          _loading = false;
          _error = 'Reset link is invalid or expired.';
        });
        return;
      }
      setState(() {
        _resolvedEmail = email.trim();
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Reset link is invalid or expired.';
      });
    }
  }

  String? _passwordValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Enter new password';
    if (value.length < 8) return 'At least 8 characters';
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasNumber = RegExp(r'\d').hasMatch(value);
    if (!hasLetter || !hasNumber) return 'Use letters and numbers';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=~`[\]\\\/]').hasMatch(value)) {
      return 'Add at least 1 special character';
    }
    return null;
  }

  String? _confirmValidator(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Confirm your password';
    if (v != _newCtrl.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _submitting = true);
    try {
      await SupabaseAuthService.updatePassword(_newCtrl.text.trim());
      await SupabaseAuthService.logout();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/reset-password-success', (route) => false);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _dec(
    String label, {
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.deepPlum, width: 1.4),
      ),
      suffixIcon: IconButton(
        iconSize: 18,
        tooltip: obscure ? 'Show password' : 'Hide password',
        onPressed: onToggle,
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: 'Reset password',
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (_error != null) {
      return Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: 'Reset password',
        child: Scaffold(
        appBar: AppBar(title: const Text('Reset Password')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 72,
                  color: AppColors.deepPlum,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reset Link Expired',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _error ?? 'Your reset link is invalid or expired.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepPlum,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/login', (route) => false);
                    },
                    child: const Text('Request New Link'),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      );
    }

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Reset password',
      child: Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.alabaster,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        title: const Text('Create New Password'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.email ?? _resolvedEmail ?? '',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _newCtrl,
                      obscureText: _obscureNew,
                      validator: _passwordValidator,
                      decoration: _dec(
                        'New Password',
                        obscure: _obscureNew,
                        onToggle: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _obscureConfirm,
                      validator: _confirmValidator,
                      decoration: _dec(
                        'Confirm New Password',
                        obscure: _obscureConfirm,
                        onToggle: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.deepPlum,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: _submitting ? null : _resetPassword,
                        child: _submitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Reset Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
