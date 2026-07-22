// lib/pages/client_registration_page.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, User, UserAttributes, FileOptions;
import 'package:country_code_picker/country_code_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/address_validation_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_bootstrap.dart';
import '../theme/app_colors.dart';
import '../config/auth_flags.dart';
import '../models/client_profile_models.dart';
import '../services/notifications_service.dart';
import '../utils/registration_input_utils.dart';
import '../widgets/jnt_modal_app_bar.dart';

import 'email_verification_pending_page.dart';
import 'home_page.dart';
import 'client_shell_page.dart';

import '../widgets/nail_preferences_inline_editor.dart';
import '../widgets/payment_method_section.dart';
import '../widgets/registration_profile_upload.dart';
import '../widgets/autocomplete_dropdown_sizing.dart';
import '../widgets/coin_selector_page.dart';

const Color _clientRegHeaderBg = AppColors.alabaster;
const Color _clientRegBodyBg = AppColors.snow;
const Color _clientRegBrandAccent = Color(0xFFEDD9C9);
const Color _clientRegBrandInk = Color(0xFF292222);
const Color snow = AppColors.snow;

class ClientRegistrationPage extends StatefulWidget {
  const ClientRegistrationPage({super.key});

  @override
  State<ClientRegistrationPage> createState() => _ClientRegistrationPageState();
}

class _ClientRegistrationPageState extends State<ClientRegistrationPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();

  // TEMP: allow registration even if checkout flow isn't complete.
  // Flip to false when checkout is enforced.
  static const bool kAllowRegistrationWithoutCheckout = true;

  bool _submitting = false;
  bool _showValidationErrors = false;
  int _registrationStep = 0;
  int? _validationTriggeredStep;
  final ScrollController _registrationScrollController = ScrollController();
  bool _pickingImage = false;
  final ImagePicker _picker = ImagePicker();
  final FocusNode _profilePhotoFocusNode = FocusNode(debugLabel: 'clientProfilePhotoUpload');
  Uint8List? _profilePhotoBytes;
  final Map<String, Uint8List> _guidedMeasurementPhotos = {};

  // Basic info
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  Timer? _emailAvailabilityDebounce;
  bool _checkingEmailAvailability = false;
  String? _lastCheckedEmail;
  String? _emailTakenRole;
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  // Address info
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _manualStateCtrl = TextEditingController();
  Timer? _streetAutocompleteDebounce;
  List<AddressSuggestion> _streetSuggestions = const [];
  bool _streetSuggestionsLoading = false;
  String _phoneAreaCode = '+1';
  static final List<Map<String, String>> _phonePickerCountries = codes
      .where(
        (c) =>
            (c['code'] ?? '').isNotEmpty && (c['dial_code'] ?? '').isNotEmpty,
      )
      .map(
        (c) => <String, String>{
          'name': (c['code'] ?? '').toUpperCase(),
          'code': (c['code'] ?? '').toUpperCase(),
          'dial_code': c['dial_code'] ?? '',
        },
      )
      .toList(growable: false);

  String get _normalizedAreaCode =>
      RegistrationInputUtils.normalizeAreaCode(_phoneAreaCode);
  String get _normalizedPhone =>
      RegistrationInputUtils.normalizePhone(_phoneCtrl.text);
  String get _fullPhone => '$_normalizedAreaCode$_normalizedPhone';

  bool _obscure = true;
  String? _passwordError;
  String? _confirmPasswordError;

  // User can proceed by either completing measurements or purchasing the kit.
  bool _kitPurchased = false;

  NailPreferences _nailPrefs = NailPreferences.empty();
  String _measurementCoinReference = 'US Penny (1¢)';

  // ✅ Payment state for scenario 1 (after Nail Length)
  PaymentInfo _payment = const PaymentInfo(
    method: PaymentMethod.applePay,
    saveForFuture: true,
  );

  static const List<String> _registrationStepTitles = <String>[
    'Basic Info,\nAddress & Payment',
    'Nail\nDimensions',
  ];

  // State/Country dropdown values
  String? _selectedState;
  String _selectedCountry = 'United States';
  bool get _isUnitedStates => _selectedCountry == 'United States';
  String get _resolvedState => _isUnitedStates
      ? (_selectedState ?? '').trim()
      : _manualStateCtrl.text.trim();

  void _autofillRandomData() {
    final rand = Random();
    final randomNum = rand.nextInt(1000000);
    final randomState = usStates[rand.nextInt(usStates.length)];
    setState(() {
      _nameCtrl.text = 'Client $randomNum';
      _emailCtrl.text = 'client_$randomNum@example.com';
      _passCtrl.text = 'Password123!';
      _confirmPassCtrl.text = 'Password123!';
      
      final p1 = 500 + rand.nextInt(400);
      final p2 = 100 + rand.nextInt(899);
      final p3 = 1000 + rand.nextInt(8999);
      _phoneCtrl.text = '($p1) $p2-$p3';
      
      _instagramCtrl.text = 'client_$randomNum';
      _tiktokCtrl.text = 'client_$randomNum';
      _bioCtrl.text = 'This is a test bio for client $randomNum.';
      _streetCtrl.text = '${100 + rand.nextInt(900)} Test St';
      _cityCtrl.text = 'Test City';
      _zipCtrl.text = '${10000 + rand.nextInt(89999)}';
      _selectedState = randomState;
      _selectedCountry = 'United States';
      _manualStateCtrl.clear();
    });
  }

  void _authLog(String message) {
    debugPrint('[CLIENT-REG] $message');
  }

  bool _hasRequiredPaymentMethod() {
    switch (_payment.method) {
      case PaymentMethod.venmo:
        return _payment.venmoHandle.trim().isNotEmpty;
      case PaymentMethod.paypal:
        final email = _payment.paypalEmail.trim();
        return email.isNotEmpty && email.contains('@');
      case PaymentMethod.card:
        final number = _payment.cardNumber.trim().replaceAll(' ', '');
        final cvv = _payment.cvv.trim();
        return _payment.nameOnCard.trim().isNotEmpty &&
            number.length >= 13 &&
            number.length <= 19 &&
            RegExp(r'^\d{2}\/\d{2}$').hasMatch(_payment.expiryMMYY.trim()) &&
            (cvv.length == 3 || cvv.length == 4) &&
            _payment.zip.trim().isNotEmpty;
      case PaymentMethod.applePay:
        // Apple Pay has no extra fields to fill in -- selecting it is
        // itself a complete, valid payment method.
        return true;
    }
  }

  bool _showPaymentValidationMessage(String message) {
    if (!mounted) return false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_pickingImage) return;
    // No lifecycle side effects while the picker is active.
  }

  static const List<_NailCaptureStep> _nailCaptureSteps = <_NailCaptureStep>[
    _NailCaptureStep(
      key: 'lThumb',
      hand: 'left',
      finger: 'thumb',
      title: 'Left Thumb',
    ),
    _NailCaptureStep(
      key: 'lIndex',
      hand: 'left',
      finger: 'index',
      title: 'Left Index',
    ),
    _NailCaptureStep(
      key: 'lMiddle',
      hand: 'left',
      finger: 'middle',
      title: 'Left Middle',
    ),
    _NailCaptureStep(
      key: 'lRing',
      hand: 'left',
      finger: 'ring',
      title: 'Left Ring',
    ),
    _NailCaptureStep(
      key: 'lPinky',
      hand: 'left',
      finger: 'pinky',
      title: 'Left Pinky',
    ),
    _NailCaptureStep(
      key: 'rThumb',
      hand: 'right',
      finger: 'thumb',
      title: 'Right Thumb',
    ),
    _NailCaptureStep(
      key: 'rIndex',
      hand: 'right',
      finger: 'index',
      title: 'Right Index',
    ),
    _NailCaptureStep(
      key: 'rMiddle',
      hand: 'right',
      finger: 'middle',
      title: 'Right Middle',
    ),
    _NailCaptureStep(
      key: 'rRing',
      hand: 'right',
      finger: 'ring',
      title: 'Right Ring',
    ),
    _NailCaptureStep(
      key: 'rPinky',
      hand: 'right',
      finger: 'pinky',
      title: 'Right Pinky',
    ),
  ];

  NailDimensions _dimensionsWithOverrides(Map<String, double> measured) {
    final d = _nailPrefs.dimensions;
    return NailDimensions(
      lThumb: measured['lThumb'] ?? d.lThumb,
      lIndex: measured['lIndex'] ?? d.lIndex,
      lMiddle: measured['lMiddle'] ?? d.lMiddle,
      lRing: measured['lRing'] ?? d.lRing,
      lPinky: measured['lPinky'] ?? d.lPinky,
      rThumb: measured['rThumb'] ?? d.rThumb,
      rIndex: measured['rIndex'] ?? d.rIndex,
      rMiddle: measured['rMiddle'] ?? d.rMiddle,
      rRing: measured['rRing'] ?? d.rRing,
      rPinky: measured['rPinky'] ?? d.rPinky,
    );
  }

  Future<double?> _askManualMeasurement(String fingerTitle) async {
    final ctrl = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.snow,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text('Enter $fingerTitle (mm)'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'e.g. 14.5',
            border: OutlineInputBorder(borderRadius: BorderRadius.zero),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blackCatLight,
              foregroundColor: AppColors.snow,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              textStyle: Theme.of(
                ctx,
              ).textTheme.labelLarge?.copyWith(fontFamily: 'Arial'),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, parsed);
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              backgroundColor: AppColors.blackCat,
              foregroundColor: AppColors.snow,
              textStyle: Theme.of(
                ctx,
              ).textTheme.labelLarge?.copyWith(fontFamily: 'Arial'),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return value;
  }

  Map<String, double> _currentMeasuredMap() {
    final d = _nailPrefs.dimensions;
    final out = <String, double>{};
    void put(String key, double? v) {
      if (v != null) out[key] = v;
    }

    put('lThumb', d.lThumb);
    put('lIndex', d.lIndex);
    put('lMiddle', d.lMiddle);
    put('lRing', d.lRing);
    put('lPinky', d.lPinky);
    put('rThumb', d.rThumb);
    put('rIndex', d.rIndex);
    put('rMiddle', d.rMiddle);
    put('rRing', d.rRing);
    put('rPinky', d.rPinky);
    return out;
  }

  void _persistMeasuredMap(Map<String, double> measured) {
    setState(() {
      _nailPrefs = NailPreferences(
        dimensions: _dimensionsWithOverrides(measured),
        shape: _nailPrefs.shape,
        length: _nailPrefs.length,
      );
    });
  }

  Future<bool> _showMeasurementGuide() async {
    final allowed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: AppColors.snow,
          appBar: AppBar(
            backgroundColor: AppColors.snow,
            elevation: 0,
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context, false),
            ),
            centerTitle: true,
            title: const Text(
              'Nail Measurement',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.snow,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: AppColors.blackCat.withValues(alpha: 0.10),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.straighten_rounded, size: 26),
                        SizedBox(height: 12),
                        Text(
                          'How to Measure Your Nails',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "We'll use a coin or currency as a reference guide to accurately measure your nail width.",
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _MeasureStepTile(
                    step: 1,
                    title: 'Keep It Flat',
                    subtitle:
                        'Position your finger flat on a table for maximum accuracy.',
                  ),
                  const _MeasureStepTile(
                    step: 2,
                    title: 'Use a Reference Coin',
                    subtitle:
                        'Place the coin next to your fingernail to use as a measurement guide.',
                  ),
                  const _MeasureStepTile(
                    step: 3,
                    title: 'Scan with Camera',
                    subtitle:
                        "Point your phone's camera to capture both your nail and the reference coin.",
                  ),
                  const _MeasureStepTile(
                    step: 4,
                    title: 'Confirm Measurement',
                    subtitle:
                        "We'll calculate your nail width based on the coin reference.",
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blackCat,
                        foregroundColor: AppColors.snow,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.snow,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return allowed == true;
  }

  Future<String?> _showCoinSelector() async {
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CoinSelectorPage(
          items: coinReferences,
          progressText: '${_currentMeasuredMap().length}/10',
          title: 'Select Coin',
          initialSelection: _measurementCoinReference,
        ),
      ),
    );
    return selected;
  }

  Future<void> _startGuidedNailMeasurement() async {
    if (!mounted) return;
    final proceed = await _showMeasurementGuide();
    if (!proceed || !mounted) return;

    final selectedCoin = await _showCoinSelector();
    if (selectedCoin == null || selectedCoin.trim().isEmpty || !mounted) {
      return;
    }
    _measurementCoinReference = selectedCoin;

    final measured = _currentMeasuredMap();
    var stepIndex = 0;
    var measuring = false;
    var sheetClosed = false;
    final pageContext = context;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.blackCat,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final step = _nailCaptureSteps[stepIndex];
            final progressLabel =
                '${measured.length}/${_nailCaptureSteps.length}';

            Future<void> saveCurrentAndMoveNext(double mm) async {
              if (!mm.isFinite || mm <= 0) {
                _authLog('invalid measurement for ${step.key}: $mm');
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Invalid measurement value. Please try again.',
                    ),
                  ),
                );
                return;
              }
              _authLog('saving measurement ${step.key} => $mm');
              measured[step.key] = (mm * 10).roundToDouble() / 10.0;
              _persistMeasuredMap(measured);
              if (stepIndex < _nailCaptureSteps.length - 1) {
                _authLog('moving to next step index=${stepIndex + 1}');
                setModalState(() => stepIndex += 1);
              } else {
                _authLog('final step complete; closing measurement sheet');
                sheetClosed = true;
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  const SnackBar(
                    content: Text('Nail measurements saved for both hands.'),
                  ),
                );
              }
            }

            Future<void> captureCurrentStep() async {
              if (measuring) return;
              setModalState(() => measuring = true);
              try {
                _authLog('opening camera for ${step.key}');
                final image = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                  maxWidth: 1080,
                  maxHeight: 1080,
                );
                if (image == null) {
                  _authLog('camera canceled for ${step.key}');
                  return;
                }

                final bytes = await image.readAsBytes();
                _guidedMeasurementPhotos[step.key] = bytes;
                _authLog(
                  'captured photo for ${step.key}: ${bytes.lengthInBytes} bytes',
                );

                final mm = await _askManualMeasurement(step.title);
                if (mm == null) return;
                await saveCurrentAndMoveNext(mm);
              } catch (_) {
                _authLog('capture failed for ${step.key}');
                if (mounted) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unable to measure from photo. Please try again.',
                      ),
                    ),
                  );
                }
              } finally {
                if (mounted && !sheetClosed) {
                  setModalState(() => measuring = false);
                }
              }
            }

            return SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.snow,
                  borderRadius: BorderRadius.zero,
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  16 + MediaQuery.of(modalContext).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Measure Your Nail',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.blackCat,
                            ),
                          ),
                        ),
                        Text(
                          progressLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.blackCat,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, i) {
                          final s = _nailCaptureSteps[i];
                          final done = measured[s.key] != null;
                          final current = i == stepIndex;
                          return Semantics(
                            button: true,
                            selected: current,
                            label:
                                '${s.title}${done ? ', measured' : ', not measured'}',
                            onTap: () =>
                                setModalState(() => stepIndex = i),
                            child: ExcludeSemantics(
                              child: InkWell(
                                onTap: () =>
                                    setModalState(() => stepIndex = i),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: current
                                        ? AppColors.blackCat
                                        : (done
                                              ? AppColors.balletSlippers
                                              : AppColors.snow),
                                    border: Border.all(
                                      color: current
                                          ? AppColors.blackCat
                                          : AppColors.blackCat.withValues(
                                              alpha: 0.12,
                                            ),
                                    ),
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  child: Text(
                                    s.finger,
                                    style: TextStyle(
                                      color: current
                                          ? AppColors.snow
                                          : AppColors.blackCat,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemCount: _nailCaptureSteps.length,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 320,
                      decoration: const BoxDecoration(
                        color: AppColors.blackCat,
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.camera_alt_rounded,
                              size: 70,
                              color: AppColors.snow,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Scan your ${step.title}',
                              style: const TextStyle(
                                color: AppColors.snow,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reference: $_measurementCoinReference',
                      style: TextStyle(
                        color: AppColors.blackCat,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        fontFamily: 'ArialBold',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter width in mm for ${step.title} (you can re-image any finger and latest value is saved).',
                      style: TextStyle(
                        color: AppColors.blackCat,
                        fontSize: 13,
                        fontFamily: 'Arial',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.snow,
                        borderRadius: BorderRadius.zero,
                      ),
                      child: const Text(
                        'Captured photos will upload with your client account when you sign up.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: measuring
                                ? null
                                : () async {
                                    try {
                                      _authLog(
                                        'manual entry opened for ${step.key}',
                                      );
                                      final manual =
                                          await _askManualMeasurement(
                                            step.title,
                                          );
                                      if (manual == null) return;
                                      await saveCurrentAndMoveNext(manual);
                                    } catch (e) {
                                      _authLog(
                                        'manual save failed for ${step.key}: $e',
                                      );
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            child: const Text('Enter Manually'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: measuring ? null : captureCurrentStep,
                            icon: measuring
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_outlined),
                            label: Text(
                              measuring
                                  ? 'Measuring...'
                                  : (measured[step.key] == null
                                        ? 'Capture'
                                        : 'Re-image'),
                            ),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              backgroundColor: AppColors.blackCat,
                              foregroundColor: AppColors.snow,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        final nextCoin = await _showCoinSelector();
                        if (nextCoin == null || nextCoin.trim().isEmpty) return;
                        setModalState(
                          () => _measurementCoinReference = nextCoin,
                        );
                      },
                      child: const Text('Change Coin/Currency'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickProfilePhoto() async {
    _pickingImage = true;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 62,
        maxWidth: 700,
        maxHeight: 700,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _profilePhotoBytes = bytes);
    } catch (e) {
      debugPrint('Profile photo pick failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not access photo library. Please check app permissions.',
            ),
          ),
        );
      }
    } finally {
      _pickingImage = false;
      // The OS image picker steals accessibility focus; put it back on the
      // avatar (not wherever the platform happens to land it) so screen
      // reader users stay in place.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_profilePhotoFocusNode);
      });
    }
  }

  double? _firestoreSafeDimension(double? value) {
    if (value == null || !value.isFinite || value <= 0) return null;
    return (value * 10).roundToDouble() / 10.0;
  }

  bool _hasAnyNfcEligibleDimension(NailDimensions dimensions) {
    final values = <double?>[
      dimensions.lThumb,
      dimensions.lIndex,
      dimensions.lMiddle,
      dimensions.lRing,
      dimensions.lPinky,
      dimensions.rThumb,
      dimensions.rIndex,
      dimensions.rMiddle,
      dimensions.rRing,
      dimensions.rPinky,
    ];
    return values.any((v) => v != null && v.isFinite && v >= 8);
  }


  /// Builds the sub-maps consumed by the `client` table upsert in
  /// `_completeRegistration` (`payload['profile']`/`['basic']`/`['address']`/
  /// `['payment']`/`['nailPreferences']`/`['registration']`). Only build keys
  /// that call site actually reads — anything else here is silently dropped
  /// before it reaches Supabase, so it's dead weight, not real duplication.
  Map<String, dynamic> _buildClientFirestorePayload({
    required ClientProfileDraft draft,
  }) {
    final payment = draft.payment;
    final nail = draft.nail;
    final dimensions = nail.dimensions;
    final nfcEligible = _hasAnyNfcEligibleDimension(dimensions);

    return {
      'profile': {
        'name': draft.basic.name,
        'phone': draft.basic.phone,
        'profileImageUrl': draft.basic.profileImageUrl,
        'photoUrl': draft.basic.profileImageUrl,
        'avatarUrl': draft.basic.profileImageUrl,
        'instagram': _instagramCtrl.text.trim(),
        'tiktok': _tiktokCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
      },
      'basic': {
        'name': draft.basic.name,
        'email': draft.basic.email,
        'phone': draft.basic.phone,
        'profileImageUrl': draft.basic.profileImageUrl,
        'photoUrl': draft.basic.profileImageUrl,
        'avatarUrl': draft.basic.profileImageUrl,
      },
      'address': {
        'street': draft.address.street,
        'city': draft.address.city,
        'state': draft.address.state,
        'zip': draft.address.zip,
        'country': draft.address.country,
      },
      'payment': {
        'method': payment.method.name,
        'saveForFuture': payment.saveForFuture,
        // NOTE: storing raw payment data is not recommended for production.
        'cardNumber': payment.cardNumber.trim(),
        'nameOnCard': payment.nameOnCard.trim(),
        'expiryMMYY': payment.expiryMMYY.trim(),
        'cvv': payment.cvv.trim(),
        'zip': payment.zip.trim(),
        'venmoHandle': payment.venmoHandle.trim(),
        'paypalEmail': payment.paypalEmail.trim(),
      },
      'nailPreferences': {
        'shape': nail.shape,
        'length': nail.length.name,
        'nfcEligible': nfcEligible,
        'eligibleForNfc': nfcEligible,
        'dimensions': {
          'lThumb': _firestoreSafeDimension(dimensions.lThumb),
          'lIndex': _firestoreSafeDimension(dimensions.lIndex),
          'lMiddle': _firestoreSafeDimension(dimensions.lMiddle),
          'lRing': _firestoreSafeDimension(dimensions.lRing),
          'lPinky': _firestoreSafeDimension(dimensions.lPinky),
          'rThumb': _firestoreSafeDimension(dimensions.rThumb),
          'rIndex': _firestoreSafeDimension(dimensions.rIndex),
          'rMiddle': _firestoreSafeDimension(dimensions.rMiddle),
          'rRing': _firestoreSafeDimension(dimensions.rRing),
          'rPinky': _firestoreSafeDimension(dimensions.rPinky),
        },
      },
      'registration': {
        'hasSizingKitAlready': _nailPrefs.isComplete,
        'kitPurchased': _kitPurchased,
        'bypassCheckoutUsed': kAllowRegistrationWithoutCheckout,
      },
    };
  }

  Future<String> _uploadProfileImage(String uid) async {
    final bytes = _profilePhotoBytes;

    debugPrint('CLIENT PHOTO BYTES NULL = ${bytes == null}');
    debugPrint('CLIENT PHOTO BYTES LENGTH = ${bytes?.length ?? 0}');

    if (bytes == null || bytes.isEmpty) return '';

    final path = 'clients/$uid/profile/avatar.jpg';

    try {
      final storage = SupabaseBootstrap.client.storage.from('profile-pictures');

      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );

      final publicUrl = storage.getPublicUrl(path).trim();

      debugPrint('CLIENT SUPABASE PROFILE URL = $publicUrl');

      return publicUrl;
    } catch (e) {
      debugPrint('CLIENT SUPABASE PROFILE UPLOAD FAILED: $e');
      return '';
    }
  }

  Future<Map<String, String>> _uploadGuidedMeasurementPhotos(String uid) async {
    if (_guidedMeasurementPhotos.isEmpty) {
      return const <String, String>{};
    }

    final storage = SupabaseBootstrap.client.storage.from('profile-pictures');
    final uploaded = <String, String>{};

    for (final entry in _guidedMeasurementPhotos.entries) {
      final path = 'clients/$uid/guided_measurements/${entry.key}.jpg';
      try {
        await storage.uploadBinary(
          path,
          entry.value,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
        uploaded[entry.key] = storage.getPublicUrl(path).trim();
      } catch (e) {
        debugPrint(
          'CLIENT GUIDED MEASUREMENT UPLOAD FAILED (${entry.key}): $e',
        );
      }
    }

    return uploaded;
  }

  static const List<String> usStates = [
    'Alabama',
    'Alaska',
    'Arizona',
    'Arkansas',
    'California',
    'Colorado',
    'Connecticut',
    'Delaware',
    'Florida',
    'Georgia',
    'Hawaii',
    'Idaho',
    'Illinois',
    'Indiana',
    'Iowa',
    'Kansas',
    'Kentucky',
    'Louisiana',
    'Maine',
    'Maryland',
    'Massachusetts',
    'Michigan',
    'Minnesota',
    'Mississippi',
    'Missouri',
    'Montana',
    'Nebraska',
    'Nevada',
    'New Hampshire',
    'New Jersey',
    'New Mexico',
    'New York',
    'North Carolina',
    'North Dakota',
    'Ohio',
    'Oklahoma',
    'Oregon',
    'Pennsylvania',
    'Rhode Island',
    'South Carolina',
    'South Dakota',
    'Tennessee',
    'Texas',
    'Utah',
    'Vermont',
    'Virginia',
    'Washington',
    'West Virginia',
    'Wisconsin',
    'Wyoming',
  ];

  static const List<String> countries = [
    'Afghanistan',
    'Albania',
    'Algeria',
    'Andorra',
    'Angola',
    'Antigua and Barbuda',
    'Argentina',
    'Armenia',
    'Australia',
    'Austria',
    'Azerbaijan',
    'Bahamas',
    'Bahrain',
    'Bangladesh',
    'Barbados',
    'Belarus',
    'Belgium',
    'Belize',
    'Benin',
    'Bhutan',
    'Bolivia',
    'Bosnia and Herzegovina',
    'Botswana',
    'Brazil',
    'Brunei',
    'Bulgaria',
    'Burkina Faso',
    'Burundi',
    'Cambodia',
    'Cameroon',
    'Canada',
    'Chile',
    'China',
    'Colombia',
    'Costa Rica',
    'Croatia',
    'Cuba',
    'Cyprus',
    'Czechia',
    'Denmark',
    'Dominican Republic',
    'Ecuador',
    'Egypt',
    'El Salvador',
    'Estonia',
    'Ethiopia',
    'Finland',
    'France',
    'Georgia',
    'Germany',
    'Ghana',
    'Greece',
    'Guatemala',
    'Haiti',
    'Honduras',
    'Hungary',
    'Iceland',
    'India',
    'Indonesia',
    'Iran',
    'Iraq',
    'Ireland',
    'Israel',
    'Italy',
    'Jamaica',
    'Japan',
    'Jordan',
    'Kazakhstan',
    'Kenya',
    'Kuwait',
    'Kyrgyzstan',
    'Laos',
    'Latvia',
    'Lebanon',
    'Lithuania',
    'Luxembourg',
    'Malaysia',
    'Maldives',
    'Malta',
    'Mexico',
    'Moldova',
    'Monaco',
    'Mongolia',
    'Morocco',
    'Nepal',
    'Netherlands',
    'New Zealand',
    'Nicaragua',
    'Nigeria',
    'Norway',
    'Oman',
    'Pakistan',
    'Panama',
    'Peru',
    'Philippines',
    'Poland',
    'Portugal',
    'Qatar',
    'Romania',
    'Russia',
    'Saudi Arabia',
    'Senegal',
    'Serbia',
    'Singapore',
    'Slovakia',
    'Slovenia',
    'South Africa',
    'South Korea',
    'Spain',
    'Sri Lanka',
    'Sweden',
    'Switzerland',
    'Thailand',
    'Tunisia',
    'Turkey',
    'Ukraine',
    'United Arab Emirates',
    'United Kingdom',
    'United States',
    'Uruguay',
    'Uzbekistan',
    'Venezuela',
    'Vietnam',
    'Zambia',
    'Zimbabwe',
  ];

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streetAutocompleteDebounce?.cancel();
    _emailAvailabilityDebounce?.cancel();
    _registrationScrollController.dispose();
    _profilePhotoFocusNode.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _phoneCtrl.dispose();
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    _bioCtrl.dispose();

    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _zipCtrl.dispose();
    _manualStateCtrl.dispose();
    super.dispose();
  }

  Future<void> _autofillAddressFromStreet() async {
    _streetAutocompleteDebounce?.cancel();
    final query = _streetCtrl.text.trim();
    if (query.length < 3) {
      if (!mounted) return;
      setState(() {
        _streetSuggestionsLoading = false;
        _streetSuggestions = const [];
      });
      return;
    }

    setState(() => _streetSuggestionsLoading = true);
    _streetAutocompleteDebounce = Timer(
      const Duration(milliseconds: 350),
      () async {
        final results =
            await AddressValidationService.searchUsStreetSuggestions(query);
        if (!mounted) return;
        setState(() {
          _streetSuggestionsLoading = false;
          _streetSuggestions = results;
        });
      },
    );
  }

  void _applyStreetSuggestion(AddressSuggestion selected) {
    setState(() {
      _streetCtrl.text = selected.street;
      _cityCtrl.text = selected.city;
      _zipCtrl.text = selected.zip;
      _selectedCountry = 'United States';
      final resolved =
          AddressValidationService.matchUsStateName(selected.state) ??
          selected.state;
      final matched = usStates.where((s) => s == resolved).toList();
      _selectedState = matched.isNotEmpty ? matched.first : null;
      _manualStateCtrl.clear();
      _streetSuggestions = const [];
    });
  }

  /// Google Places predictions (see [AddressSuggestion.placeId]) carry only
  /// display text, not structured fields — resolve the full address before
  /// applying it. Nominatim-backed suggestions (placeId null) apply
  /// unchanged, synchronously.
  Future<void> _selectStreetSuggestion(AddressSuggestion selected) async {
    if (selected.placeId != null) {
      final resolved = await AddressValidationService.resolvePlaceDetails(
        selected.placeId!,
      );
      if (resolved != null) {
        _applyStreetSuggestion(resolved);
        return;
      }
    }
    _applyStreetSuggestion(selected);
  }

  // -----------------------
  // Font sizes (smaller)
  // -----------------------
  static const double _labelFs = 16;
  static const double _inputFs = 14;
  static const double _hintFs = 13;
  static const double _fieldHeight = 46;
  static const double _fieldVerticalPadding = 16;

  InputDecoration _dec(String label, String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: _hintFs,
        color: _clientRegBrandInk.withValues(alpha: 0.42),
        fontFamily: 'Arial',
      ),
      labelStyle: TextStyle(
        fontSize: _labelFs,
        color: _clientRegBrandInk.withValues(alpha: 0.78),
        fontFamily: 'Arial',
      ),
      errorStyle: const TextStyle(
        fontSize: 10.5,
        height: 1.1,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: snow,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.blackCatBorderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.blackCatBorderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.blackCat, width: 1.4),
      ),
      isDense: false,
      constraints: const BoxConstraints(minHeight: _fieldHeight),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: _fieldVerticalPadding,
      ),
    );
  }

  /// Marks a form field as required (or not) for screen readers, matching
  /// the visible required/optional state already tracked by `_FieldLabel`.
  Widget _req(bool required, Widget child) {
    return Semantics(isRequired: required, child: child);
  }

  Widget _countryCodeDropdown({
    required String value,
    required ValueChanged<CountryCode> onChanged,
    bool embedded = false,
  }) {
    return Localizations.override(
      context: context,
      locale: const Locale('en'),
      child: Container(
        height: _fieldHeight,
        decoration: BoxDecoration(
          color: snow,
          borderRadius: BorderRadius.zero,
          border: embedded
              ? null
              : Border.all(color: AppColors.blackCatBorderLight),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CountryCodePicker(
          onChanged: onChanged,
          initialSelection: value == '+1' ? 'US' : value,
          favorite: const ['US', '+1', '+44', '+91'],
          countryList: _phonePickerCountries,
          showFlag: false,
          showFlagMain: false,
          showFlagDialog: true,
          showCountryOnly: true,
          hideMainText: true,
          alignLeft: true,
          flagWidth: 20,
          padding: EdgeInsets.zero,
          builder: (code) {
            final flagUri = code?.flagUri;
            final countryAbbr = (code?.code ?? 'US').toUpperCase();
            return Row(
              children: [
                if (flagUri != null)
                  Image.asset(
                    flagUri,
                    package: 'country_code_picker',
                    width: 20,
                    height: 14,
                    fit: BoxFit.cover,
                  ),
                const SizedBox(width: 8),
                Text(
                  countryAbbr,
                  style: const TextStyle(
                    fontSize: _inputFs,
                    color: AppColors.blackCat,
                    fontFamily: 'Arial',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String? _firstExactMatch(List<String> options, String input) {
    final needle = input.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final option in options) {
      if (option.trim().toLowerCase() == needle) return option;
    }
    return null;
  }

  Widget _typeAheadPicker({
    required String label,
    required String hint,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
    bool required = false,
  }) {
    return _req(required, _typeAheadPickerField(
      label: label,
      hint: hint,
      options: options,
      selectedValue: selectedValue,
      onChanged: onChanged,
      validator: validator,
    ));
  }

  Widget _typeAheadPickerField({
    required String label,
    required String hint,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return FormField<String>(
      initialValue: selectedValue,
      validator: validator,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Autocomplete<String>(
              initialValue: TextEditingValue(text: field.value ?? ''),
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.trim().toLowerCase();
                if (query.isEmpty) return const Iterable<String>.empty();
                return options.where(
                  (option) => option.toLowerCase().contains(query),
                );
              },
              onSelected: (value) {
                field.didChange(value);
                onChanged(value);
              },
              fieldViewBuilder:
                  (context, textController, focusNode, onSubmitted) {
                    return TextFormField(
                      controller: textController,
                      focusNode: focusNode,
                      style: const TextStyle(
                        fontSize: _inputFs,
                        color: AppColors.blackCat,
                        fontFamily: 'Arial',
                      ),
                      decoration: _dec(label, hint),
                      onTapOutside: (_) => focusNode.unfocus(),
                      onEditingComplete: () {
                        final match = _firstExactMatch(
                          options,
                          textController.text,
                        );
                        if (match != null) {
                          field.didChange(match);
                          onChanged(match);
                        }
                      },
                    );
                  },
              optionsViewBuilder: (context, onSelected, optionsList) {
                final maxW = MediaQuery.of(context).size.width - 48;
                final optionCount = optionsList.length;
                final menuHeight = AutocompleteDropdownSizing.menuHeight(
                  itemCount: optionCount,
                  itemExtent: 40,
                );
                return TextFieldTapRegion(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: snow,
                      elevation: 4,
                      borderRadius: BorderRadius.zero,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: menuHeight,
                          maxWidth: maxW < 260 ? 260 : maxW,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: AutocompleteDropdownSizing.shrinkWrap(
                            optionCount,
                          ),
                          physics: AutocompleteDropdownSizing.scrollPhysics(
                            optionCount,
                          ),
                          itemCount: optionCount,
                          itemBuilder: (context, index) {
                            final option = optionsList.elementAt(index);
                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                dense: true,
                                title: Text(
                                  option,
                                  style: const TextStyle(fontSize: _inputFs),
                                ),
                                onTap: () => onSelected(option),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.1,
                    fontWeight: FontWeight.w400,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // -----------------------
  // Validators
  // -----------------------
  String? _requiredValidator(String? v, String fieldName) {
    if (v == null || v.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!v.contains('@')) return 'Enter a valid email';
    final normalized = v.trim().toLowerCase();
    if (_emailTakenRole != null && normalized == _lastCheckedEmail) {
      return SupabaseAuthService.emailAlreadyRegisteredMessage;
    }
    return null;
  }

  void _onEmailChanged(String value) {
    _emailAvailabilityDebounce?.cancel();
    final normalized = value.trim().toLowerCase();

    if (normalized.isEmpty || !normalized.contains('@')) {
      if (_emailTakenRole != null || _checkingEmailAvailability) {
        setState(() {
          _emailTakenRole = null;
          _checkingEmailAvailability = false;
        });
      }
      return;
    }

    setState(() => _checkingEmailAvailability = true);
    _emailAvailabilityDebounce = Timer(const Duration(milliseconds: 500), () async {
      final role = await SupabaseAuthService.findExistingRoleForEmail(
        normalized,
      );
      if (!mounted) return;
      if (_emailCtrl.text.trim().toLowerCase() != normalized) {
        // Text changed again while the check was in flight; ignore this
        // stale result, the newer debounce cycle will handle it.
        return;
      }
      setState(() {
        _checkingEmailAvailability = false;
        _lastCheckedEmail = normalized;
        _emailTakenRole = role;
      });
    });
  }

  /// Real-time email availability feedback, shown as the user types/pauses
  /// instead of only surfacing on Create Account submission. Hidden once the
  /// user has attempted to submit, since the standard field validator takes
  /// over displaying the same message at that point.
  Widget _buildEmailAvailabilityStatus() {
    if (_showValidationErrors) return const SizedBox.shrink();

    final normalized = _emailCtrl.text.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      return const SizedBox.shrink();
    }

    if (_checkingEmailAvailability) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, left: 2),
        child: Text(
          'Checking email availability…',
          style: TextStyle(
            fontSize: 11,
            color: Colors.black.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    if (_emailTakenRole != null && normalized == _lastCheckedEmail) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, left: 2),
        child: Text(
          SupabaseAuthService.emailAlreadyRegisteredMessage,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String? _passwordValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Password is required';
    if (!RegistrationInputUtils.isStrongPassword(value)) {
      return 'Use 8+ chars with upper, lower, number, and symbol';
    }
    return null;
  }

  void _onPasswordChanged(String value) {
    setState(() {
      _passwordError = _passwordValidator(value);
      // Confirm-password's match state depends on the password value, so
      // re-check it live too instead of waiting for that field to be edited.
      if (_confirmPassCtrl.text.isNotEmpty) {
        _confirmPasswordError = _confirmPasswordValidator(
          _confirmPassCtrl.text,
        );
      }
    });
  }

  void _onConfirmPasswordChanged(String value) {
    setState(() {
      _confirmPasswordError = _confirmPasswordValidator(value);
    });
  }

  Widget _buildPasswordStatus() {
    if (_passCtrl.text.isEmpty || _passwordError == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Text(
        _passwordError!,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.red,
        ),
      ),
    );
  }

  Widget _buildConfirmPasswordStatus() {
    if (_confirmPassCtrl.text.isEmpty || _confirmPasswordError == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Text(
        _confirmPasswordError!,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.red,
        ),
      ),
    );
  }

  String? _phoneValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone is required';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'Enter exactly 10 digits';
    return null;
  }

  String? _zipValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) {
      return _isUnitedStates ? 'Zip Code is required' : null;
    }
    if (!_isUnitedStates) return null;
    final ok = RegExp(r'^\d{5}$').hasMatch(value);
    if (!ok) return 'Enter a valid ZIP code';
    return null;
  }

  String? _confirmPasswordValidator(String? v) {
    if (v == null || v.isEmpty) return 'Confirm Password is required';
    if (v != _passCtrl.text) return 'Passwords do not match';
    return null;
  }

  String? _socialRequiredValidator(String? _) {
    final instagram = _instagramCtrl.text.trim();
    final tiktok = _tiktokCtrl.text.trim();
    if (instagram.isEmpty && tiktok.isEmpty) {
      return 'Provide Instagram or TikTok';
    }
    return null;
  }

  // -----------------------
  // Popup (only for kit purchased scenario 2)
  // -----------------------
  Future<bool> _showSetupReminderDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          title: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: _clientRegBrandAccent.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.zero,
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: _clientRegBrandInk,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Finish setup after kit arrives',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Text(
            'Your account will be created now. '
            'To request a custom nail design, you must complete profile setup '
            'after receiving the Nail Sizing Kit.',
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.70),
              height: 1.25,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _clientRegBrandInk,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Widget promosAndNailTipsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Promos & Nail Tips',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              color: snow,
              borderRadius: BorderRadius.zero,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  color: AppColors.blackCat.withValues(alpha: 0.55),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Get 10% off your first custom set — use WELCOME10',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.blackCat.withValues(alpha: 0.75),
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finishClientRegistrationForUser({
    required User user,
    required ClientProfileDraft draft,
  }) async {
    final uid = user.id;

    final displayName = _nameCtrl.text.trim();
    if (displayName.isNotEmpty) {
      _authLog('updating display name');
      try {
        await SupabaseBootstrap.client.auth.updateUser(
          UserAttributes(
            data: <String, dynamic>{
              'display_name': displayName,
              'full_name': displayName,
            },
          ),
        );
      } catch (_) {}
    }

    _authLog('uploading profile photo');
    final uploadedProfilePhotoUrl = await _uploadProfileImage(uid);
    _authLog(
      'profile photo upload complete hasUrl=${uploadedProfilePhotoUrl.isNotEmpty}',
    );

    final profilePhotoUrl = uploadedProfilePhotoUrl.trim();

    _authLog('uploading guided measurement photos');
    final guidedMeasurementPhotoUrls = await _uploadGuidedMeasurementPhotos(
      uid,
    );
    _authLog(
      'guided measurement photo upload count=${guidedMeasurementPhotoUrls.length}',
    );

    draft = draft.copyWith(
      basic: draft.basic.copyWith(profileImageUrl: profilePhotoUrl),
    );
    final payload = _buildClientFirestorePayload(draft: draft);
    final registration = Map<String, dynamic>.from(
      (payload['registration'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    )..['guidedMeasurementPhotos'] = guidedMeasurementPhotoUrls;
    final supabase = SupabaseBootstrap.client;

    _authLog('upserting client row');
    await supabase.from('client').upsert({
      'id': uid,
      'email': draft.basic.email,
      'account_type': 'client',

      'profile': payload['profile'],
      'basic': payload['basic'],
      'address': payload['address'],
      'payment': payload['payment'],
      'nail_preferences': payload['nailPreferences'],
      'registration': registration,

      'panel_display_name': draft.basic.name,
      'panel_phone': draft.basic.phone,

      'updated_at': DateTime.now().toIso8601String(),
    });

    final registeredName = draft.basic.name.trim().isNotEmpty
        ? draft.basic.name.trim()
        : draft.basic.email.trim();
    _authLog('notifying admins');
    await NotificationsService.notifyAdmins(
      title: 'New User Registered',
      body: 'New Client: $registeredName registered',
      type: 'admin_new_user_registered',
      sourceCollection: 'client',
      extra: <String, dynamic>{
        'registeredRole': 'Client',
        'registeredName': registeredName,
        'registeredEmail': draft.basic.email.trim().toLowerCase(),
        'registeredUid': uid,
      },
    );

    _authLog('navigation after signup');
    if (!mounted) return;
    if (kRequireEmailVerification) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => EmailVerificationPendingPage(
            email: _emailCtrl.text.trim().toLowerCase(),
            loginPageBuilder: (_) => const HomePage(),
          ),
        ),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => ClientShellPage(profile: draft)),
        (route) => false,
      );
    }
  }

  // -----------------------
  // Create Account
  // -----------------------
  Future<void> _onCreateAccount() async {
    final sw = Stopwatch()..start();
    _authLog('submit tapped');

    if (!_showValidationErrors) {
      setState(() => _showValidationErrors = true);
    }
    if (_formKey.currentState?.validate() != true) return;
    if (!_hasRequiredPaymentMethod()) {
      _showPaymentValidationMessage(
        'Please enter at least one payment method before continuing.',
      );
      return;
    }
    _authLog('form validation passed');

    if (!kAllowRegistrationWithoutCheckout) {
      // Scenario 2: must purchase kit if they don't already have one
      if (!_nailPrefs.isComplete && !_kitPurchased) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please purchase the Nail Sizing Kit to continue.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        );
        return;
      }

      // Scenario 1: must complete nail prefs
      if (_nailPrefs.isComplete && _payment.method == PaymentMethod.card) {
        if (_payment.cardNumber.trim().isEmpty ||
            _payment.expiryMMYY.trim().isEmpty ||
            _payment.cvv.trim().isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Enter card details')));
          return;
        }
      }

      // ✅ Popup ONLY for purchased kit flow (scenario 2)
      if (!_nailPrefs.isComplete) {
        final proceed = await _showSetupReminderDialog();
        if (!proceed) return;
      }
    }

    var draft = ClientProfileDraft(
      basic: BasicInfo(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _fullPhone,
      ),
      address: AddressInfo(
        street: _streetCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _resolvedState,
        zip: _zipCtrl.text.trim(),
        country: _selectedCountry.trim(),
      ),
      payment: _payment,
      nail: _nailPrefs.isComplete ? _nailPrefs : NailPreferences.empty(),
    );

    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      // Clear any stale session from a previously logged-in user before
      // signing up. Without this, if signup doesn't return a fresh session
      // (e.g. email confirmation required), the app proceeds as if the new
      // client is "in", while every per-user query (like Notifications)
      // still reads whichever OTHER account's session was left active.
      await SupabaseAuthService.logout();

      _authLog('calling SupabaseAuthService.signup');
      final user = await SupabaseAuthService.signup(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      _authLog('signup returned userId=${user?.id ?? 'null'}');

      if (user == null) {
        _authLog('signup returned null user');
        throw Exception('Unable to create user.');
      }

      await _finishClientRegistrationForUser(user: user, draft: draft);
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      final isAlreadyRegistered =
          message.contains('already registered') ||
          message.contains('already exists') ||
          message.contains('user already registered');

      if (isAlreadyRegistered) {
        final existingRole = await SupabaseAuthService.findExistingRoleForEmail(
          _emailCtrl.text,
        );

        // An email maps to exactly one account. If it's already registered
        // under a DIFFERENT role table, block rather than silently
        // attaching a second role to it. Same-role (or no role data yet,
        // e.g. a prior signup that never finished writing its row) is a
        // safe repair/resubmit case.
        if (existingRole != null && existingRole != 'client') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(SupabaseAuthService.emailAlreadyRegisteredMessage),
            ),
          );
          return;
        }

        try {
          _authLog('already registered, retrying as login');
          final existingUser = await SupabaseAuthService.login(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text.trim(),
          );
          if (existingUser != null) {
            await _finishClientRegistrationForUser(
              user: existingUser,
              draft: draft,
            );
            return;
          }
        } on AuthException {
          // Fall through to the user-facing sign-in message below.
        }
      }

      if (!mounted) return;
      final msg = isAlreadyRegistered
          ? 'Email already registered. Please sign in.'
          : message.contains('invalid')
          ? 'Invalid email or password.'
          : message.contains('weak')
          ? 'Password is too weak.'
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      _authLog('unexpected error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      _authLog('finished in ${sw.elapsedMilliseconds}ms');
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _announceStep(int index) {
    if (!mounted) return;
    final title = _registrationStepTitles[index].replaceAll('\n', ' ');
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Step ${index + 1} of ${_registrationStepTitles.length}: $title',
      Directionality.of(context),
    );
  }

  Future<bool> _validateCurrentRegistrationStep() async {
    if (_validationTriggeredStep != _registrationStep) {
      setState(() => _validationTriggeredStep = _registrationStep);
    }
    final ok = _formKey.currentState?.validate() ?? true;
    if (!ok) {
      if (mounted) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          'Please correct the highlighted fields before continuing.',
          Directionality.of(context),
        );
      }
      return false;
    }

    if (_registrationStep == 0 && _isUnitedStates) {
      try {
        final addressValidation =
            await AddressValidationService.validateUsAddress(
              street: _streetCtrl.text.trim(),
              city: _cityCtrl.text.trim(),
              state: _resolvedState,
              zip: _zipCtrl.text.trim(),
            ).timeout(const Duration(seconds: 8));
        if (!addressValidation.isValid) {
          if (!mounted) return false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                addressValidation.message ?? 'Invalid U.S. mailing address.',
              ),
            ),
          );
          return false;
        }
      } on TimeoutException {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address validation timed out. Please try again.'),
          ),
        );
        return false;
      }
    }

    if (_registrationStep == 0 && !_hasRequiredPaymentMethod()) {
      return _showPaymentValidationMessage(
        'Please enter at least one payment method before continuing.',
      );
    }

    return true;
  }

  Future<void> _goToNextRegistrationStep() async {
    if (!await _validateCurrentRegistrationStep()) return;
    if (!mounted) return;
    setState(() {
      _registrationStep += 1;
      _validationTriggeredStep = null;
    });
    _announceStep(_registrationStep);
    _scrollRegistrationToTop();
  }

  /// Advancing/going back a step swaps which fields render within the same
  /// single scrollable, so without this the new step opens at whatever
  /// scroll offset the Next/Back button happened to be at (often the
  /// bottom), instead of showing the step from its top.
  void _scrollRegistrationToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_registrationScrollController.hasClients) return;
      _registrationScrollController.jumpTo(0);
    });
  }

  Widget _registrationProgressTabs() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Row(
        children: List.generate(_registrationStepTitles.length, (index) {
          final selected = index == _registrationStep;
          final completed = index < _registrationStep;
          final showConnector = index < _registrationStepTitles.length - 1;
          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label:
                  'Step ${index + 1}: ${_registrationStepTitles[index]}${completed ? ', completed' : ''}',
              onTap: () {
                setState(() {
                  _registrationStep = index;
                  _validationTriggeredStep = null;
                });
                _announceStep(index);
              },
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _registrationStep = index;
                      _validationTriggeredStep = null;
                    });
                    _announceStep(index);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 28,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (index > 0)
                              Expanded(
                                child: Container(
                                  height: 1.5,
                                  color: completed
                                      ? _clientRegBrandInk.withValues(
                                          alpha: 0.55,
                                        )
                                      : _clientRegBrandInk.withValues(
                                          alpha: 0.18,
                                        ),
                                ),
                              )
                            else
                              const Spacer(),
                            const SizedBox(width: 6),
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (selected || completed)
                                    ? _clientRegBrandInk
                                    : _clientRegBrandInk.withValues(
                                        alpha: 0.10,
                                      ),
                              ),
                              child: completed
                                  ? const Icon(
                                      Icons.check,
                                      size: 15,
                                      color: AppColors.snow,
                                    )
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontFamily: 'Arial',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? AppColors.snow
                                            : _clientRegBrandInk,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 6),
                            if (showConnector)
                              Expanded(
                                child: Container(
                                  height: 1.5,
                                  color: (completed || selected)
                                      ? _clientRegBrandInk.withValues(
                                          alpha: 0.55,
                                        )
                                      : _clientRegBrandInk.withValues(
                                          alpha: 0.18,
                                        ),
                                ),
                              )
                            else
                              const Spacer(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 30,
                        child: Text(
                          _registrationStepTitles[index],
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: 'Arial',
                            fontSize: 9,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _clientRegBrandInk.withValues(
                              alpha: selected ? 1 : 0.65,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 3,
                        color: selected
                            ? _clientRegBrandInk
                            : Colors.transparent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _wizardNavButtons({required bool canCreate}) {
    final isLast = _registrationStep == _registrationStepTitles.length - 1;
    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      color: _clientRegBodyBg,
      child: Row(
        children: [
          if (_registrationStep > 0)
            SizedBox(
              height: 44,
              width: 96,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: _clientRegBrandInk,
                  foregroundColor: AppColors.snow,
                  side: const BorderSide(color: AppColors.blackCatBorderLight),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _registrationStep -= 1;
                    _validationTriggeredStep = null;
                  });
                  _announceStep(_registrationStep);
                  _scrollRegistrationToTop();
                },
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 96),
          const Spacer(),
          SizedBox(
            height: 44,
            width: isLast ? 170 : 96,
            child: ElevatedButton(
              onPressed: _submitting
                  ? null
                  : isLast
                  ? (canCreate ? _onCreateAccount : null)
                  : _goToNextRegistrationStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: _clientRegBrandInk,
                disabledBackgroundColor: _clientRegBrandInk.withValues(
                  alpha: 0.16,
                ),
                foregroundColor: AppColors.snow,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.snow,
                        ),
                      ),
                    )
                  : Text(
                      isLast ? 'Create account' : 'Next',
                      style: const TextStyle(
                        fontFamily: 'Arial',
                        color: AppColors.snow,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = kAllowRegistrationWithoutCheckout
        ? true
        : (_nailPrefs.isComplete || _kitPurchased);
    final themed = Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(
        fontFamily: 'Arial',
        bodyColor: _clientRegBrandInk,
        displayColor: _clientRegBrandInk,
      ),
      colorScheme: Theme.of(
        context,
      ).colorScheme.copyWith(primary: _clientRegBrandInk),
      scaffoldBackgroundColor: _clientRegBodyBg,
      appBarTheme: Theme.of(context).appBarTheme.copyWith(
        backgroundColor: _clientRegHeaderBg,
        foregroundColor: _clientRegBrandInk,
      ),
    );

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Client registration',
      child: Theme(
      data: themed,
      child: Scaffold(
        backgroundColor: _clientRegBodyBg,
        appBar: JntModalAppBar(
          onClose: () => Navigator.of(
            context,
            rootNavigator: true,
          ).pushNamedAndRemoveUntil('/register', (route) => false),
          closeTooltip: 'Close client registration',
          closeIcon: const Icon(Icons.close),
          leadingWidth: 60,
          leading: Tooltip(
            message: 'Fill dummy data',
            child: IconButton(
              icon: const Icon(Icons.auto_fix_high),
              iconSize: 20,
              color: AppColors.blackCat,
              onPressed: _autofillRandomData,
              style: IconButton.styleFrom(
                foregroundColor: AppColors.blackCat,
                minimumSize: const Size(40, 40),
                padding: const EdgeInsets.all(8),
                shape: const RoundedRectangleBorder(),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            controller: _registrationScrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            children: [
              Form(
                key: _formKey,
                autovalidateMode: _validationTriggeredStep == _registrationStep
                    ? AutovalidateMode.always
                    : AutovalidateMode.disabled,
                child: Column(
                  children: [
                    _registrationProgressTabs(),
                    if (_registrationStep == 0) ...[
                    _SectionCard(
                      title: 'Basic Information',
                      subtitle:
                          'Fill in your details to create your client account',
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          _ProfileUpload(
                            imageBytes: _profilePhotoBytes,
                            onTap: _pickProfilePhoto,
                            focusNode: _profilePhotoFocusNode,
                          ),
                          const SizedBox(height: 6),

                          _FieldLabel.required('Name'),
                          const SizedBox(height: 6),
                          _req(
                            true,
                            TextFormField(
                              controller: _nameCtrl,
                              style: const TextStyle(
                                fontSize: _inputFs,
                                fontFamily: 'Arial',
                              ),
                              decoration: _dec('Name', 'Enter Name'),
                              validator: (v) => _requiredValidator(v, 'Name'),
                            ),
                          ),
                          const SizedBox(height: 6),

                          _FieldLabel.required('Email'),
                          const SizedBox(height: 6),
                          _req(
                            true,
                            TextFormField(
                              controller: _emailCtrl,
                              style: const TextStyle(
                                fontSize: _inputFs,
                                fontFamily: 'Arial',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _dec('Email', 'Enter Email'),
                              validator: _emailValidator,
                              onChanged: _onEmailChanged,
                            ),
                          ),
                          _buildEmailAvailabilityStatus(),
                          const SizedBox(height: 6),

                          _FieldLabel.required('Password'),
                          const SizedBox(height: 6),
                          _req(
                            true,
                            TextFormField(
                              controller: _passCtrl,
                              style: const TextStyle(
                                fontSize: _inputFs,
                                fontFamily: 'Arial',
                              ),
                              obscureText: _obscure,
                              decoration: _dec(
                                'Password',
                                'Enter Password',
                                suffixIcon: IconButton(
                                  iconSize: 18,
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                ),
                              ),
                              validator: _passwordValidator,
                              onChanged: _onPasswordChanged,
                            ),
                          ),
                          _buildPasswordStatus(),
                          const SizedBox(height: 6),
                          // ✅ Confirm Password (NEW)
                          _FieldLabel.required('Confirm Password'),
                          const SizedBox(height: 6),
                          _req(
                            true,
                            TextFormField(
                            controller: _confirmPassCtrl,
                            style: const TextStyle(
                              fontSize: _inputFs,
                              fontFamily: 'Arial',
                            ),
                            obscureText: _obscure,
                            decoration: _dec(
                              'Confirm Password',
                              'Re-enter Password',
                              suffixIcon: IconButton(
                                iconSize: 18,
                                tooltip: _obscure
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                            validator: _confirmPasswordValidator,
                            onChanged: _onConfirmPasswordChanged,
                            ),
                          ),
                          _buildConfirmPasswordStatus(),
                          const SizedBox(height: 6),
                          _FieldLabel.required('Phone'),
                          const SizedBox(height: 6),
                          FormField<String>(
                            validator: (value) =>
                                _phoneValidator(_phoneCtrl.text),
                            builder: (field) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: _fieldHeight,
                                    decoration: BoxDecoration(
                                      color: AppColors.snow,
                                      borderRadius: BorderRadius.zero,
                                      border: Border.all(
                                        color: AppColors.blackCatBorderLight,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 132,
                                          child: _countryCodeDropdown(
                                            value: _phoneAreaCode,
                                            embedded: true,
                                            onChanged: (code) => setState(
                                              () => _phoneAreaCode =
                                                  code.dialCode ?? '+1',
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          color: AppColors.blackCatBorderLight,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Semantics(
                                            label: 'Phone number',
                                            isRequired: true,
                                            textField: true,
                                            child: TextFormField(
                                            controller: _phoneCtrl,
                                            style: const TextStyle(
                                              fontSize: _inputFs,
                                              fontFamily: 'Arial',
                                            ),
                                            keyboardType: TextInputType.phone,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                10,
                                              ),
                                              UsPhoneTextInputFormatter(),
                                            ],
                                            onChanged: field.didChange,
                                            decoration: InputDecoration(
                                              hintText: 'Enter 10-digit phone',
                                              hintStyle: TextStyle(
                                                fontSize: _hintFs,
                                                color: _clientRegBrandInk
                                                    .withValues(alpha: 0.42),
                                                fontFamily: 'Arial',
                                              ),
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical:
                                                        _fieldVerticalPadding,
                                                  ),
                                              isDense: false,
                                            ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                    ),
                                  ),
                                  if (field.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 6,
                                        left: 4,
                                      ),
                                      child: Text(
                                        field.errorText!,
                                        style: const TextStyle(
                                          color: Color(0xFFB3261E),
                                          fontSize: 10.5,
                                          height: 1.1,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 6),

                          _FieldLabel.normal('Instagram'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _instagramCtrl,
                            style: const TextStyle(
                              fontSize: _inputFs,
                              fontFamily: 'Arial',
                            ),
                            decoration: _dec('Instagram', 'Enter Instagram'),
                            validator: _socialRequiredValidator,
                          ),
                          const SizedBox(height: 6),

                          _FieldLabel.normal('TikTok'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _tiktokCtrl,
                            style: const TextStyle(
                              fontSize: _inputFs,
                              fontFamily: 'Arial',
                            ),
                            decoration: _dec('TikTok', 'Enter TikTok'),
                            validator: _socialRequiredValidator,
                          ),
                          const SizedBox(height: 6),

                          _FieldLabel.normal('Bio'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _bioCtrl,
                            style: const TextStyle(
                              fontSize: _inputFs,
                              fontFamily: 'Arial',
                            ),
                            maxLines: 4,
                            decoration: _dec('Bio', 'Enter Bio'),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),

                    _SectionCard(
                      title: 'Address Information',
                      subtitle:
                          'Provide your shipping address (required to receive nail sizing kit and custom sets)',
                      child: Column(
                        children: [
                          _FieldLabel.required('Street Address'),
                          const SizedBox(height: 6),
                          _req(
                            true,
                            TextFormField(
                              controller: _streetCtrl,
                              style: const TextStyle(
                                fontSize: _inputFs,
                                fontFamily: 'Arial',
                              ),
                              decoration: _dec(
                                'Street Address',
                                'Enter Street Address',
                              ),
                              onChanged: (_) => _autofillAddressFromStreet(),
                              validator: (v) =>
                                  _requiredValidator(v, 'Street Address'),
                            ),
                          ),
                          if (_streetSuggestionsLoading)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          if (_streetSuggestions.isNotEmpty)
                            Builder(
                              builder: (context) {
                                final suggestionCount =
                                    _streetSuggestions.length;
                                final menuHeight =
                                    AutocompleteDropdownSizing.menuHeight(
                                      itemCount: suggestionCount,
                                      itemExtent: 40,
                                    );
                                return Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  decoration: BoxDecoration(
                                    color: _clientRegBodyBg,
                                    borderRadius: BorderRadius.zero,
                                    border: Border.all(
                                      color: _clientRegBrandInk.withValues(
                                        alpha: 0.20,
                                      ),
                                    ),
                                  ),
                                  constraints: BoxConstraints(
                                    maxHeight: menuHeight,
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap:
                                        AutocompleteDropdownSizing.shrinkWrap(
                                          suggestionCount,
                                        ),
                                    physics:
                                        AutocompleteDropdownSizing.scrollPhysics(
                                          suggestionCount,
                                        ),
                                    itemCount: suggestionCount,
                                    separatorBuilder: (_, _) =>
                                        const Divider(height: 1),
                                    itemBuilder: (_, i) => ListTile(
                                      dense: true,
                                      title: Text(
                                        _streetSuggestions[i].displayLabel,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onTap: () => _selectStreetSuggestion(
                                        _streetSuggestions[i],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 6),

                          _FieldLabel.required('City'),
                          const SizedBox(height: 6),
                          _req(
                            true,
                            TextFormField(
                              controller: _cityCtrl,
                              style: const TextStyle(
                                fontSize: _inputFs,
                                fontFamily: 'Arial',
                              ),
                              decoration: _dec('City', 'Enter City'),
                              validator: (v) => _requiredValidator(v, 'City'),
                            ),
                          ),
                          const SizedBox(height: 6),

                          _isUnitedStates
                              ? _FieldLabel.required('State')
                              : _FieldLabel.normal('State / Region'),
                          const SizedBox(height: 6),
                          if (_isUnitedStates)
                            _typeAheadPicker(
                              label: 'State',
                              hint: 'Type state',
                              options: usStates,
                              selectedValue: _selectedState,
                              required: true,
                              onChanged: (v) =>
                                  setState(() => _selectedState = v),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'State is required'
                                  : null,
                            )
                          else
                            TextFormField(
                              controller: _manualStateCtrl,
                              style: const TextStyle(
                                fontSize: _inputFs,
                                fontFamily: 'Arial',
                              ),
                              decoration: _dec(
                                'State / Region',
                                'Enter State / Region',
                              ),
                            ),
                          const SizedBox(height: 6),

                          _isUnitedStates
                              ? _FieldLabel.required('Zip Code')
                              : _FieldLabel.normal('Zip Code'),
                          const SizedBox(height: 6),
                          _req(
                            _isUnitedStates,
                            TextFormField(
                              controller: _zipCtrl,
                              style: const TextStyle(
                                fontSize: _inputFs,
                                fontFamily: 'Arial',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: _isUnitedStates
                                  ? <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(5),
                                    ]
                                  : <TextInputFormatter>[],
                              decoration: _dec('Zip Code', 'Enter Zip Code'),
                              validator: _zipValidator,
                            ),
                          ),
                          const SizedBox(height: 6),

                          _FieldLabel.required('Country'),
                          const SizedBox(height: 6),
                          _typeAheadPicker(
                            label: 'Country',
                            hint: 'Type country',
                            options: countries,
                            selectedValue: _selectedCountry,
                            required: true,
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _selectedCountry = v;
                                if (_isUnitedStates) {
                                  _manualStateCtrl.clear();
                                } else {
                                  _selectedState = null;
                                }
                              });
                            },
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Country is required'
                                : null,
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    promosAndNailTipsCard(),
                    const SizedBox(height: 6),
                    PaymentMethodSection(
                      initial: _payment,
                      onChanged: (updated) =>
                          setState(() => _payment = updated),
                    ),
                  ] else ...[

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: snow,
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: AppColors.blackCat.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nail Photos',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Capture each finger photo here. The photos will upload with your client account when you sign up.',
                            style: TextStyle(
                              color: AppColors.blackCat.withValues(alpha: 0.72),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _startGuidedNailMeasurement,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _clientRegBrandInk,
                                foregroundColor: AppColors.snow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Capture Photo'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    NailPreferencesInlineEditor(
                      initial: _nailPrefs,
                      showDimensionImages: false,
                      onChanged: (updated) =>
                          setState(() => _nailPrefs = updated),
                    ),
                  ],
                    const SizedBox(height: 6),

                    /*if (!_nailPrefs.isComplete) ...[
                      if (!_kitPurchased)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Purchase the Nail Sizing Kit to continue.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      NailSizingKitSection(
                        purchased: _kitPurchased,
                        onAddToCart: _startCheckout,
                      ),
                    ],*/
                    const SizedBox(height: 18),

                    _wizardNavButtons(canCreate: canCreate),
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

class _NailCaptureStep {
  const _NailCaptureStep({
    required this.key,
    required this.hand,
    required this.finger,
    required this.title,
  });

  final String key;
  final String hand;
  final String finger;
  final String title;
}

class _MeasureStepTile extends StatelessWidget {
  const _MeasureStepTile({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final int step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.blackCat,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$step',
              style: const TextStyle(
                color: AppColors.snow,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinReference {
  const _CoinReference({
    required this.group,
    required this.name,
    required this.diameterMm,
    required this.icon,
  });
  final String group;
  final String name;
  final double diameterMm;
  final String icon;
}

const List<_CoinReference> _coinReferences = <_CoinReference>[
  _CoinReference(
    group: 'UNITED STATES',
    name: 'US Penny (1¢)',
    diameterMm: 19.05,
    icon: '🇺🇸',
  ),
  _CoinReference(
    group: 'UNITED STATES',
    name: 'US Nickel (5¢)',
    diameterMm: 21.21,
    icon: '🇺🇸',
  ),
  _CoinReference(
    group: 'UNITED STATES',
    name: 'US Dime (10¢)',
    diameterMm: 17.91,
    icon: '🇺🇸',
  ),
  _CoinReference(
    group: 'UNITED STATES',
    name: 'US Quarter (25¢)',
    diameterMm: 24.26,
    icon: '🇺🇸',
  ),
  _CoinReference(
    group: 'CANADA',
    name: 'Canadian Quarter',
    diameterMm: 23.88,
    icon: '🇨🇦',
  ),
  _CoinReference(
    group: 'CANADA',
    name: 'Canadian Dollar (Loonie)',
    diameterMm: 26.50,
    icon: '🇨🇦',
  ),
  _CoinReference(
    group: 'CANADA',
    name: 'Canadian 2 Dollar (Toonie)',
    diameterMm: 28.00,
    icon: '🇨🇦',
  ),
  _CoinReference(
    group: 'MEXICO',
    name: 'Mexico 10 Peso',
    diameterMm: 28.00,
    icon: '🇲🇽',
  ),
];

class _CoinSelectorPage extends StatefulWidget {
  const _CoinSelectorPage({required this.items, required this.progressText});

  final List<_CoinReference> items;
  final String progressText;

  @override
  State<_CoinSelectorPage> createState() => _CoinSelectorPageState();
}

class _CoinSelectorPageState extends State<_CoinSelectorPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = widget.items
        .where((e) {
          if (query.isEmpty) return true;
          return e.name.toLowerCase().contains(query) ||
              e.group.toLowerCase().contains(query);
        })
        .toList(growable: false);

    String? previousGroup;
    final groupedWidgets = <Widget>[];
    for (final item in filtered) {
      if (previousGroup != item.group) {
        previousGroup = item.group;
        groupedWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              item.group,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat.withValues(alpha: 0.55),
              ),
            ),
          ),
        );
      }
      groupedWidgets.add(
        MergeSemantics(
          child: Semantics(
            button: true,
            onTap: () => Navigator.pop(context, item.name),
            child: InkWell(
          onTap: () => Navigator.pop(context, item.name),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.snow,
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: AppColors.blackCat.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                Text(item.icon, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.diameterMm.toStringAsFixed(2)}mm diameter',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.blackCat.withValues(alpha: 0.65),
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
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.snow,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Select Coin',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                widget.progressText,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search coins...',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: AppColors.blackCat.withValues(alpha: 0.35),
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: AppColors.balletSlippers,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: groupedWidgets.isEmpty
                      ? [
                          const SizedBox(height: 30),
                          const Center(child: Text('No matching coin found.')),
                        ]
                      : groupedWidgets,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------------
/// UI Components
/// ------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.35)),
        /*boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],*/
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat,
              fontFamily: 'ArialBold',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.blackCat.withValues(alpha: 0.60),
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _ProfileUpload extends StatelessWidget {
  const _ProfileUpload({required this.onTap, this.imageBytes, this.focusNode});
  final VoidCallback onTap;
  final Uint8List? imageBytes;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return RegistrationProfileUpload(
      onTap: onTap,
      imageBytes: imageBytes,
      focusNode: focusNode,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel._(this.text, this.requiredField);

  final String text;
  final bool requiredField;

  factory _FieldLabel.required(String text) => _FieldLabel._(text, true);
  factory _FieldLabel.normal(String text) => _FieldLabel._(text, false);

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
