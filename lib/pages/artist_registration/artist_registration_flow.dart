import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'registration_draft.dart';
import 'step1_account.dart';
import 'step2_location.dart';
import 'step3_specialization.dart';
import 'step4_credentials.dart';
import '_widgets/step_progress_bar.dart';
import '_widgets/continue_button.dart';

class ArtistRegistrationFlow extends StatefulWidget {
  const ArtistRegistrationFlow({super.key});

  @override
  State<ArtistRegistrationFlow> createState() => _ArtistRegistrationFlowState();
}

class _ArtistRegistrationFlowState extends State<ArtistRegistrationFlow> {
  static const int _totalSteps = 4;

  static const _stepLabels = ['Account', 'Location', 'Services', 'Payments'];

  static const _stepSubtitles = [
    'Account Credentials & Artist Profile',
    'Location & Service Area',
    'Specialization, Calendar & Portfolio',
    'Credentials, Payment & Agreements',
  ];

  int _currentStep = 1;
  bool _submitting = false;
  final RegistrationDraft _draft = RegistrationDraft();

  final _step1Key = GlobalKey<Step1AccountState>();
  final _step2Key = GlobalKey<Step2LocationState>();
  final _step3Key = GlobalKey<Step3SpecializationState>();
  final _step4Key = GlobalKey<Step4CredentialsState>();

  void _onBack() {
    if (_currentStep == 1) {
      Navigator.of(context).pop();
    } else {
      setState(() => _currentStep--);
    }
  }

  void _onContinue() {
    switch (_currentStep) {
      case 1:
        if (_step1Key.currentState?.validateAndSave(_draft) != true) return;
        setState(() => _currentStep = 2);

      case 2:
        if (_step2Key.currentState?.validateAndSave(_draft) != true) return;
        setState(() => _currentStep = 3);

      case 3:
        if (_step3Key.currentState?.validateAndSave(_draft) != true) return;
        setState(() => _currentStep = 4);

      case 4:
        if (_step4Key.currentState?.validateAndSave(_draft) != true) return;
        _submit();
    }
  }

  void _autofillCurrentStep() {
    switch (_currentStep) {
      case 1: _step1Key.currentState?.autofill();
      case 2: _step2Key.currentState?.autofill();
      case 3: _step3Key.currentState?.autofill();
      case 4: _step4Key.currentState?.autofill();
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      // TODO: wire up the actual Supabase/Firebase account creation
      // using _draft fields (mirrors ArtistRegistrationPage._submit logic)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account creation coming soon!')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return Step1Account(key: _step1Key, draft: _draft);
      case 2:
        return Step2Location(key: _step2Key, draft: _draft);
      case 3:
        return Step3Specialization(key: _step3Key, draft: _draft);
      case 4:
        return Step4Credentials(key: _step4Key, draft: _draft);
      default:
        return const Center(child: Text('Coming soon'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.alabaster,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Image.asset(
          'assets/images/jnt_logo_black.png',
          height: 50,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        actions: [
          Tooltip(
            message: 'Fill dummy data',
            child: IconButton(
              icon: const Icon(Icons.auto_fix_high),
              color: AppColors.blackCatLight,
              onPressed: _autofillCurrentStep,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            color: AppColors.blackCatLight,
            onPressed: () => Navigator.of(context, rootNavigator: true)
                .pushNamedAndRemoveUntil('/register', (route) => false),
          ),
        ],
      ),
      body: ColoredBox(
        color: AppColors.snow,
        child: SafeArea(
          child: Column(
            children: [
            // ── Progress bar ───────────────────────────────────────────────
            StepProgressBar(
              current: _currentStep,
              total: _totalSteps,
              stepLabels: _stepLabels,
              sectionSubtitle: _stepSubtitles[_currentStep - 1],
            ),

            // ── Step content ───────────────────────────────────────────────
            Expanded(child: _buildCurrentStep()),

            // ── Bottom action row ──────────────────────────────────────────
            Container(
              color: AppColors.snow,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Row(
                children: [
                  // Back / Cancel
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _onBack,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blackCat,
                        side: const BorderSide(color: AppColors.blackCat),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: Text(
                        _currentStep == 1 ? 'Cancel' : 'Back',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Continue / Create
                  Expanded(
                    child: ContinueButton(
                      onTap: _onContinue,
                      loading: _submitting,
                      embedded: true,
                      label: _currentStep == _totalSteps ? 'Create My Account' : 'Continue',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
