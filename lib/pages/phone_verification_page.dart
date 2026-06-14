import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/email_service.dart';

class PhoneVerificationPage extends StatefulWidget {
  const PhoneVerificationPage({
    super.key,
    required this.phoneNumber,
    required this.userEmail,
    required this.userName,
    required this.accountType,
    required this.collectionName,
    required this.uid,
  });

  final String phoneNumber;
  final String userEmail;
  final String userName;
  final String accountType;
  final String collectionName;
  final String uid;

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  final _otpCtrl = TextEditingController();

  String? _verificationId;
  bool _sendingCode = false;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _sendingCode = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _completePhoneVerification();
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _error = e.message ?? 'Phone verification failed.';
            _sendingCode = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _sendingCode = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to send verification code.';
        _sendingCode = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCtrl.text.trim();

    if (code.length < 6) {
      setState(() => _error = 'Enter the 6-digit verification code.');
      return;
    }

    if (_verificationId == null) {
      setState(() => _error = 'Verification code is not ready yet.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await user.updatePhoneNumber(credential);
      }

      await _completePhoneVerification();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Invalid verification code.';
        _verifying = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Phone verification failed.';
        _verifying = false;
      });
    }
  }

  Future<void> _completePhoneVerification() async {
    await FirebaseFirestore.instance
        .collection(widget.collectionName)
        .doc(widget.uid)
        .set({
      'verification': {
        'emailVerified': true,
        'phoneVerified': true,
        'accountActive': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await EmailService.sendVerifiedWelcomeEmail(
      userEmail: widget.userEmail,
      userName: widget.userName,
      accountType: widget.accountType,
    );

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        title: const Text('Verify Phone'),
        backgroundColor: AppColors.alabaster,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verify Your Phone Number',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackCat,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a verification code to ${widget.phoneNumber}.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.blackCat,
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Verification Code',
                  hintText: 'Enter 6-digit code',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blackCat,
                    foregroundColor: AppColors.snow,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: _verifying
                      ? const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.snow,
                        )
                      : const Text('Verify Phone'),
                ),
              ),

              const SizedBox(height: 10),

              Center(
                child: TextButton(
                  onPressed: _sendingCode ? null : _sendOtp,
                  child: Text(
                    _sendingCode ? 'Sending code...' : 'Resend Code',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}