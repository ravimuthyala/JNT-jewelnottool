import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/full_hand_measurement_service.dart';
import '../theme/app_colors.dart';
import 'coin_selector_page.dart';

/// Shared "Measure Your Nail" flow: 2 photos per hand (4 fingers together,
/// then thumb alone) instead of one photo per finger.
///
/// Used by both the client self-registration and client-via-artist
/// registration screens, which previously duplicated the old 10-photo
/// per-finger flow.
///
/// [photosOut] is mutated in place with the captured shots, keyed
/// `lFourFinger` / `lThumb` / `rFourFinger` / `rThumb`, so callers can
/// upload them the same way they uploaded the old per-finger photos.
///
/// Returns the updated finger-width map (keyed `lThumb`, `lIndex`, ...,
/// matching [NailDimensions]' field names) on completion, or null if the
/// user backed out before finishing.
Future<Map<String, double>?> showFullHandMeasurementFlow({
  required BuildContext context,
  required Map<String, double> initialMeasured,
  required Map<String, Uint8List> photosOut,
  String initialCoinReference = 'US Penny (1¢)',
}) async {
  debugPrint('[FullHandMeasurement] flow started, pushing guide page');
  final proceed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _MeasurementGuidePage(),
    ),
  );
  debugPrint('[FullHandMeasurement] guide page returned proceed=$proceed');
  if (proceed != true || !context.mounted) return null;

  debugPrint('[FullHandMeasurement] pushing coin selector page');
  final selectedCoinName = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CoinSelectorPage(
        items: coinReferences,
        progressText: '0/4',
        title: 'Select Coin',
        initialSelection: initialCoinReference,
      ),
    ),
  );
  debugPrint('[FullHandMeasurement] coin selector returned $selectedCoinName');
  if (selectedCoinName == null ||
      selectedCoinName.trim().isEmpty ||
      !context.mounted) {
    return null;
  }

  final coinDiameterMm = coinReferences
      .firstWhere(
        (c) => c.name == selectedCoinName,
        orElse: () => coinReferences.first,
      )
      .diameterMm;

  debugPrint('[FullHandMeasurement] opening capture sheet');
  return showModalBottomSheet<Map<String, double>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.blackCat,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _FullHandMeasurementSheet(
      initialMeasured: Map<String, double>.from(initialMeasured),
      photosOut: photosOut,
      coinName: selectedCoinName,
      coinDiameterMm: coinDiameterMm,
    ),
  );
}

class _HandShotStep {
  const _HandShotStep({
    required this.key,
    required this.hand,
    required this.shotType,
    required this.tabLabel,
    required this.bigTitle,
  });

  final String key; // lFourFinger | lThumb | rFourFinger | rThumb
  final String hand; // left | right
  final String shotType; // fourFinger | thumb
  final String tabLabel;
  final String bigTitle;
}

const List<_HandShotStep> _steps = <_HandShotStep>[
  _HandShotStep(
    key: 'lFourFinger',
    hand: 'left',
    shotType: 'fourFinger',
    tabLabel: '4 Fingers',
    bigTitle: 'Left Hand — 4 Fingers',
  ),
  _HandShotStep(
    key: 'lThumb',
    hand: 'left',
    shotType: 'thumb',
    tabLabel: 'Thumb',
    bigTitle: 'Left Thumb',
  ),
  _HandShotStep(
    key: 'rFourFinger',
    hand: 'right',
    shotType: 'fourFinger',
    tabLabel: '4 Fingers',
    bigTitle: 'Right Hand — 4 Fingers',
  ),
  _HandShotStep(
    key: 'rThumb',
    hand: 'right',
    shotType: 'thumb',
    tabLabel: 'Thumb',
    bigTitle: 'Right Thumb',
  ),
];

const Map<String, String> _fingerLabels = <String, String>{
  'thumb': 'Thumb',
  'index': 'Index',
  'middle': 'Middle',
  'ring': 'Ring',
  'pinky': 'Pinky',
};

class _FullHandMeasurementSheet extends StatefulWidget {
  const _FullHandMeasurementSheet({
    required this.initialMeasured,
    required this.photosOut,
    required this.coinName,
    required this.coinDiameterMm,
  });

  final Map<String, double> initialMeasured;
  final Map<String, Uint8List> photosOut;
  final String coinName;
  final double coinDiameterMm;

  @override
  State<_FullHandMeasurementSheet> createState() =>
      _FullHandMeasurementSheetState();
}

class _FullHandMeasurementSheetState extends State<_FullHandMeasurementSheet> {
  final ImagePicker _picker = ImagePicker();
  late final Map<String, double> _measured = Map<String, double>.from(
    widget.initialMeasured,
  );
  late String _coinName = widget.coinName;
  late double _coinDiameterMm = widget.coinDiameterMm;

  int _stepIndex = 0;
  final Set<String> _checkedOk = <String>{};
  bool _busy = false;
  List<String> _lastIssues = const [];

  void _log(String message) => debugPrint('[FullHandMeasurement] $message');

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeCoin() async {
    final next = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CoinSelectorPage(
          items: coinReferences,
          progressText: '${_checkedOk.length}/4',
          title: 'Select Coin',
          initialSelection: _coinName,
        ),
      ),
    );
    if (next == null || next.trim().isEmpty || !mounted) return;
    final diameter = coinReferences
        .firstWhere((c) => c.name == next, orElse: () => coinReferences.first)
        .diameterMm;
    setState(() {
      _coinName = next;
      _coinDiameterMm = diameter;
    });
  }

  Future<double?> _askManualMeasurement(String title) async {
    final ctrl = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.snow,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text('Enter $title (mm)'),
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
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              backgroundColor: AppColors.blackCat,
              foregroundColor: AppColors.snow,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return value;
  }

  Future<void> _showRetakeDialog(TwoShotCheckResult check) async {
    final coinDetected = check.coin?['detected'];
    final coinMsg = coinDetected == false
        ? 'Reference coin not detected. '
        : '';
    final issues = check.issues;
    final message = (check.message != null && check.message!.trim().isNotEmpty)
        ? check.message!
        : '$coinMsg${issues.isNotEmpty ? issues.join('\n') : 'Photo quality was not good enough. Please retake.'}';

    setState(() => _lastIssues = issues);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.snow,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('Retake Photo'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blackCat,
              foregroundColor: AppColors.snow,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Text('Retake'),
          ),
        ],
      ),
    );
  }

  Future<void> _captureCurrentStep() async {
    if (_busy) return;
    setState(() => _busy = true);
    final step = _steps[_stepIndex];
    try {
      _log('opening camera for ${step.key}');
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
        requestFullMetadata: false,
      );
      if (image == null) {
        _log('camera canceled for ${step.key}');
        return;
      }

      final bytes = await image.readAsBytes();
      widget.photosOut[step.key] = bytes;
      _log('captured photo for ${step.key}: ${bytes.lengthInBytes} bytes');

      final check = await FullHandMeasurementService.checkShot(
        imageBytes: bytes,
        hand: step.hand,
        shotType: step.shotType,
        coinName: _coinName,
        coinDiameterMm: _coinDiameterMm,
      );

      if (check == null) {
        _showSnack('Unable to reach measurement service. Please try again.');
        return;
      }
      if (!check.ok) {
        _log('check failed for ${step.key}: ${check.issues}');
        await _showRetakeDialog(check);
        return;
      }

      setState(() {
        _checkedOk.add(step.key);
        _lastIssues = const [];
      });

      final handSteps = _steps.where((s) => s.hand == step.hand);
      final handComplete = handSteps.every((s) => _checkedOk.contains(s.key));

      if (handComplete) {
        await _submitHand(step.hand);
      } else if (_stepIndex < _steps.length - 1) {
        setState(() => _stepIndex += 1);
      }
    } catch (e) {
      _log('capture failed for ${step.key}: $e');
      _showSnack('Unable to capture photo. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitHand(String hand) async {
    final prefix = hand == 'left' ? 'l' : 'r';
    final fourBytes = widget.photosOut['${prefix}FourFinger'];
    final thumbBytes = widget.photosOut['${prefix}Thumb'];
    if (fourBytes == null || thumbBytes == null) return;

    setState(() => _busy = true);
    try {
      final result = await FullHandMeasurementService.submitTwoShot(
        fourFingerBytes: fourBytes,
        thumbBytes: thumbBytes,
        hand: hand,
        coinName: _coinName,
        coinDiameterMm: _coinDiameterMm,
      );

      if (result == null || !result.ok) {
        _showSnack(
          result?.message ??
              'Measurement failed for the $hand hand. Please retake both photos.',
        );
        setState(() {
          _checkedOk.removeWhere((k) => k.startsWith(prefix));
          _stepIndex = _steps.indexWhere((s) => s.hand == hand);
        });
        return;
      }

      _applyMeasurements(hand, result.measurements);
      if (!mounted) return;
      await _showHandResults(hand, result);

      if (!mounted) return;
      if (hand == 'left') {
        setState(
          () => _stepIndex = _steps.indexWhere((s) => s.hand == 'right'),
        );
      } else {
        Navigator.of(context).pop(_measured);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyMeasurements(
    String hand,
    Map<String, FingerMeasurement>? measurements,
  ) {
    if (measurements == null) return;
    final prefix = hand == 'left' ? 'l' : 'r';
    for (final entry in _fingerLabels.entries) {
      final measurement = measurements[entry.key];
      if (measurement != null &&
          measurement.isDetected &&
          measurement.widthMm != null) {
        _measured['$prefix${entry.value}'] = measurement.widthMm!;
      }
    }
  }

  Future<void> _showHandResults(String hand, TwoShotResult result) async {
    final prefix = hand == 'left' ? 'l' : 'r';
    final handLabel = hand == 'left' ? 'Left' : 'Right';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.snow,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (rowCtx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(rowCtx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$handLabel Hand Results',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppColors.blackCat,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Auto-measured from your photos. You can override any finger manually.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.blackCatLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (result.issues != null && result.issues!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          result.issues!.join(', '),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    for (final apiKey in _fingerLabels.keys)
                      _resultRow(
                        rowCtx,
                        setSheetState,
                        apiKey: apiKey,
                        label: _fingerLabels[apiKey]!,
                        dimKey: '$prefix${_fingerLabels[apiKey]}',
                        measurement: result.measurements?[apiKey],
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blackCat,
                          foregroundColor: AppColors.snow,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        child: const Text('Continue'),
                      ),
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

  Widget _resultRow(
    BuildContext ctx,
    StateSetter setSheetState, {
    required String apiKey,
    required String label,
    required String dimKey,
    required FingerMeasurement? measurement,
  }) {
    final widthMm = _measured[dimKey];
    final lengthMm = measurement?.lengthMm;
    final notDetected = widthMm == null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat,
              ),
            ),
          ),
          Expanded(
            child: Text(
              notDetected
                  ? 'Not detected'
                  : '${widthMm.toStringAsFixed(1)}mm wide'
                        '${lengthMm != null ? ' × ${lengthMm.toStringAsFixed(1)}mm long' : ''}',
              style: TextStyle(
                color: notDetected ? Colors.red : AppColors.blackCat,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final manual = await _askManualMeasurement(label);
              if (manual == null || !manual.isFinite || manual <= 0) return;
              final rounded = (manual * 10).roundToDouble() / 10.0;
              setState(() => _measured[dimKey] = rounded);
              setSheetState(() {});
            },
            child: const Text('Enter Manually'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_stepIndex];
    final progressLabel = '${_checkedOk.length}/${_steps.length}';

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
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
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
                    final s = _steps[i];
                    final done = _checkedOk.contains(s.key);
                    final current = i == _stepIndex;
                    return InkWell(
                      onTap: () => setState(() => _stepIndex = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
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
                                : AppColors.blackCat.withValues(alpha: 0.12),
                          ),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Text(
                          s.tabLabel,
                          style: TextStyle(
                            color: current
                                ? AppColors.snow
                                : AppColors.blackCat,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemCount: _steps.length,
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
                        'Scan your ${step.bigTitle}',
                        textAlign: TextAlign.center,
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
                'Reference: $_coinName',
                style: const TextStyle(
                  color: AppColors.blackCat,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step.shotType == 'fourFinger'
                    ? 'Line up index, middle, ring, and pinky together with the coin.'
                    : 'Capture your thumb alone with the coin.',
                style: const TextStyle(
                  color: AppColors.blackCat,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_lastIssues.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _lastIssues.join(', '),
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.snow,
                  borderRadius: BorderRadius.zero,
                ),
                child: const Text(
                  'Captured photos will upload with your account when you sign up.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _captureCurrentStep,
                  icon: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    _busy
                        ? 'Measuring...'
                        : (_checkedOk.contains(step.key)
                              ? 'Re-image'
                              : 'Capture'),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    backgroundColor: AppColors.blackCat,
                    foregroundColor: AppColors.snow,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _changeCoin,
                child: const Text('Change Coin/Currency'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeasurementGuidePage extends StatelessWidget {
  const _MeasurementGuidePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              Expanded(
                child: SingleChildScrollView(
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
                              "You'll take 2 photos per hand: your 4 fingers together, "
                              "then your thumb alone, each with a coin for scale.",
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
                            'Position your hand flat on a table for maximum accuracy.',
                      ),
                      const _MeasureStepTile(
                        step: 2,
                        title: 'Use a Reference Coin',
                        subtitle:
                            'Place the coin next to your fingernails to use as a measurement guide.',
                      ),
                      const _MeasureStepTile(
                        step: 3,
                        title: 'Scan with Camera',
                        subtitle:
                            'Capture 4 fingers together, then your thumb alone, for each hand.',
                      ),
                      const _MeasureStepTile(
                        step: 4,
                        title: 'Review Your Results',
                        subtitle:
                            "We'll auto-fill all 5 fingers per hand; you can adjust any of them manually.",
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
    );
  }
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
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
                fontSize: 13,
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
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.blackCat.withValues(alpha: 0.72),
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
