import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../services/auth_email_alias_service.dart';
import 'artist_shell_page.dart';
import 'login_page.dart' show isCurrentSessionAccountBlocked;
import '../services/supabase_auth_service.dart';

class ArtistLoginPage extends StatefulWidget {
  const ArtistLoginPage({super.key});

  @override
  State<ArtistLoginPage> createState() => _ArtistLoginPageState();
}

class _ArtistLoginPageState extends State<ArtistLoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocusNode = FocusNode(debugLabel: 'artistLoginEmail');
  final _passwordFocusNode = FocusNode(debugLabel: 'artistLoginPassword');
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // iOS VoiceOver does not announce a TextField that gains focus purely via
  // FocusNode.requestFocus() when advancing off the keyboard's Next button --
  // it silently lands on Password without reading it aloud. Sending an
  // explicit accessibility-focus semantics event fixes that. Android/TalkBack
  // already announces the field from requestFocus() alone, so this stays
  // iOS-only and Android's behavior is unchanged.
  void _focusPasswordFieldAccessibly() {
    _passwordFocusNode.requestFocus();
    if (!kIsWeb && Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _passwordFocusNode.context?.findRenderObject()?.sendSemanticsEvent(
          const FocusSemanticEvent(),
        );
      });
    }
  }

  Future<void> _login() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _emailCtrl.text.trim().toLowerCase();
      final password = _passwordCtrl.text;
      try {
        await SupabaseAuthService.login(
          email: email,
          password: password,
        );
      } on AuthException catch (e) {
        if (!const <String>{
          'invalid_credentials',
          'invalid-credential',
          'wrong-password',
          'user-not-found',
        }.contains(e.code)) {
          rethrow;
        }
        final mappedAuthEmail =
            await AuthEmailAliasService.resolveAuthEmailForLogin(email);
        if (mappedAuthEmail == null || mappedAuthEmail == email) rethrow;
        await SupabaseAuthService.login(
          email: mappedAuthEmail,
          password: password,
        );
      }
      if (!mounted) return;

      if (await isCurrentSessionAccountBlocked()) {
        await SupabaseAuthService.logout();
        if (!mounted) return;
        setState(
          () => _error = 'Your account has been deactivated. Contact support.',
        );
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ArtistShellPage()),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Invalid artist credentials');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Artist login',
      child: Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                header: true,
                child: const Text(
                  'Artist Login',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 24),

              _field(
                _emailCtrl,
                'Email',
                focusNode: _emailFocusNode,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _focusPasswordFieldAccessibly(),
              ),
              const SizedBox(height: 8),
              _field(
                _passwordCtrl,
                'Password',
                obscure: true,
                focusNode: _passwordFocusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepPlum,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'LOGIN',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool obscure = false,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
