import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../models/client_profile_models.dart';
import '../utils/registration_input_utils.dart';
import 'package:flutter/gestures.dart';

/// Reusable inline editor for:
/// - Nail Dimensions (10 fingers)
/// - Nail Shape
/// - Nail Length
///
/// Use:
/// NailPreferencesInlineEditor(
///   initial: nailPrefs,
///   onChanged: (updated) => setState(() => nailPrefs = updated),
/// )
class NailPreferencesInlineEditor extends StatefulWidget {
  const NailPreferencesInlineEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    this.showMeasurementTips = true,
    this.showDimensionImages = true,
    this.nailDimensionBorderColor,
    this.useBlackModalStyle = false,
    this.showOuterContainer = true,
    this.showNfcOptions = false,
  });

  final NailPreferences initial;
  final ValueChanged<NailPreferences> onChanged;
  final bool showMeasurementTips;
  final bool showDimensionImages;
  final Color? nailDimensionBorderColor;
  final bool useBlackModalStyle;
  final bool showOuterContainer;
  final bool showNfcOptions;

  @override
  State<NailPreferencesInlineEditor> createState() =>
      _NailPreferencesInlineEditorState();
}

class _NailPreferencesInlineEditorState
    extends State<NailPreferencesInlineEditor> {
  static const List<NailLength> _supportedLengths = <NailLength>[
    NailLength.xlLong,
    NailLength.short,
    NailLength.medium,
    NailLength.long,
    NailLength.extraLong,
  ];
  bool _isSyncingFromParent = false;

  late final TextEditingController lThumb;
  late final TextEditingController lIndex;
  late final TextEditingController lMiddle;
  late final TextEditingController lRing;
  late final TextEditingController lPinky;

  late final TextEditingController rThumb;
  late final TextEditingController rIndex;
  late final TextEditingController rMiddle;
  late final TextEditingController rRing;
  late final TextEditingController rPinky;

  late final FocusNode lThumbFocus;
  late final FocusNode lIndexFocus;
  late final FocusNode lMiddleFocus;
  late final FocusNode lRingFocus;
  late final FocusNode lPinkyFocus;

  late final FocusNode rThumbFocus;
  late final FocusNode rIndexFocus;
  late final FocusNode rMiddleFocus;
  late final FocusNode rRingFocus;
  late final FocusNode rPinkyFocus;

  late String _shape;
  late NailLength _length;
  final Set<String> _nfcSelections = <String>{};
  // Smaller font sizes to match registration fields
  static const double _titleFs = 16; // section titles
  static const double _hintFs = 13; // hint text

  // Update these to match what you want in the UI.
  // If you already have a nailShapes list elsewhere, you can remove this and import it instead.

  @override
  void initState() {
    super.initState();

    final d = widget.initial.dimensions;

    lThumb = TextEditingController(text: _t(d.lThumb));
    lIndex = TextEditingController(text: _t(d.lIndex));
    lMiddle = TextEditingController(text: _t(d.lMiddle));
    lRing = TextEditingController(text: _t(d.lRing));
    lPinky = TextEditingController(text: _t(d.lPinky));

    rThumb = TextEditingController(text: _t(d.rThumb));
    rIndex = TextEditingController(text: _t(d.rIndex));
    rMiddle = TextEditingController(text: _t(d.rMiddle));
    rRing = TextEditingController(text: _t(d.rRing));
    rPinky = TextEditingController(text: _t(d.rPinky));

    lThumbFocus = FocusNode(debugLabel: 'leftThumbNailDimension');
    lIndexFocus = FocusNode(debugLabel: 'leftIndexNailDimension');
    lMiddleFocus = FocusNode(debugLabel: 'leftMiddleNailDimension');
    lRingFocus = FocusNode(debugLabel: 'leftRingNailDimension');
    lPinkyFocus = FocusNode(debugLabel: 'leftPinkyNailDimension');

    rThumbFocus = FocusNode(debugLabel: 'rightThumbNailDimension');
    rIndexFocus = FocusNode(debugLabel: 'rightIndexNailDimension');
    rMiddleFocus = FocusNode(debugLabel: 'rightMiddleNailDimension');
    rRingFocus = FocusNode(debugLabel: 'rightRingNailDimension');
    rPinkyFocus = FocusNode(debugLabel: 'rightPinkyNailDimension');

    _shape = _normalizeShape(widget.initial.shape);
    _length = _normalizeLength(widget.initial.length);
    _syncNfcSelectionsFromDimensions(d);

    for (final c in [
      lThumb,
      lIndex,
      lMiddle,
      lRing,
      lPinky,
      rThumb,
      rIndex,
      rMiddle,
      rRing,
      rPinky,
    ]) {
      c.addListener(_emit);
    }
  }

  @override
  void dispose() {
    lThumb.dispose();
    lIndex.dispose();
    lMiddle.dispose();
    lRing.dispose();
    lPinky.dispose();
    rThumb.dispose();
    rIndex.dispose();
    rMiddle.dispose();
    rRing.dispose();
    rPinky.dispose();

    lThumbFocus.dispose();
    lIndexFocus.dispose();
    lMiddleFocus.dispose();
    lRingFocus.dispose();
    lPinkyFocus.dispose();

    rThumbFocus.dispose();
    rIndexFocus.dispose();
    rMiddleFocus.dispose();
    rRingFocus.dispose();
    rPinkyFocus.dispose();

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NailPreferencesInlineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextDims = widget.initial.dimensions;
    final currentDims = _currentDims();
    final nextShape = _normalizeShape(widget.initial.shape);
    final nextLength = _normalizeLength(widget.initial.length);
    final matchesCurrentState =
        currentDims.lThumb == nextDims.lThumb &&
        currentDims.lIndex == nextDims.lIndex &&
        currentDims.lMiddle == nextDims.lMiddle &&
        currentDims.lRing == nextDims.lRing &&
        currentDims.lPinky == nextDims.lPinky &&
        currentDims.rThumb == nextDims.rThumb &&
        currentDims.rIndex == nextDims.rIndex &&
        currentDims.rMiddle == nextDims.rMiddle &&
        currentDims.rRing == nextDims.rRing &&
        currentDims.rPinky == nextDims.rPinky &&
        currentDims.lThumbNfc == nextDims.lThumbNfc &&
        currentDims.lIndexNfc == nextDims.lIndexNfc &&
        currentDims.lMiddleNfc == nextDims.lMiddleNfc &&
        currentDims.lRingNfc == nextDims.lRingNfc &&
        currentDims.lPinkyNfc == nextDims.lPinkyNfc &&
        currentDims.rThumbNfc == nextDims.rThumbNfc &&
        currentDims.rIndexNfc == nextDims.rIndexNfc &&
        currentDims.rMiddleNfc == nextDims.rMiddleNfc &&
        currentDims.rRingNfc == nextDims.rRingNfc &&
        currentDims.rPinkyNfc == nextDims.rPinkyNfc &&
        _shape == nextShape &&
        _length == nextLength;
    if (matchesCurrentState) return;
    _syncFromInitial(widget.initial);
  }

  String _t(double? v) {
    if (v == null) return '';
    if (!v.isFinite) return '';
    return v.toStringAsFixed(2);
  }

  double? _parse(String v) {
    final s = v.trim().replaceAll(RegExp(r'\s*mm$', caseSensitive: false), '');
    if (s.isEmpty) return null;
    final parsed = double.tryParse(s);
    if (parsed == null || !parsed.isFinite) return null;
    return parsed;
  }

  bool _isNfcEligible(double? value) {
    return value != null && value.isFinite && value >= 8;
  }

  bool _isNfcSelected(String key, double? value) {
    return widget.showNfcOptions &&
        _isNfcEligible(value) &&
        _nfcSelections.contains(key);
  }

  void _syncNfcSelectionsFromDimensions(NailDimensions d) {
    _nfcSelections
      ..clear()
      ..addAll(<String>[
        if (d.lThumbNfc) 'lThumb',
        if (d.lIndexNfc) 'lIndex',
        if (d.lMiddleNfc) 'lMiddle',
        if (d.lRingNfc) 'lRing',
        if (d.lPinkyNfc) 'lPinky',
        if (d.rThumbNfc) 'rThumb',
        if (d.rIndexNfc) 'rIndex',
        if (d.rMiddleNfc) 'rMiddle',
        if (d.rRingNfc) 'rRing',
        if (d.rPinkyNfc) 'rPinky',
      ]);
  }

  void _pruneIneligibleNfcSelections() {
    final values = <String, double?>{
      'lThumb': _parse(lThumb.text),
      'lIndex': _parse(lIndex.text),
      'lMiddle': _parse(lMiddle.text),
      'lRing': _parse(lRing.text),
      'lPinky': _parse(lPinky.text),
      'rThumb': _parse(rThumb.text),
      'rIndex': _parse(rIndex.text),
      'rMiddle': _parse(rMiddle.text),
      'rRing': _parse(rRing.text),
      'rPinky': _parse(rPinky.text),
    };
    _nfcSelections.removeWhere((key) => !_isNfcEligible(values[key]));
  }

  NailDimensions _currentDims() {
    final lThumbValue = _parse(lThumb.text);
    final lIndexValue = _parse(lIndex.text);
    final lMiddleValue = _parse(lMiddle.text);
    final lRingValue = _parse(lRing.text);
    final lPinkyValue = _parse(lPinky.text);
    final rThumbValue = _parse(rThumb.text);
    final rIndexValue = _parse(rIndex.text);
    final rMiddleValue = _parse(rMiddle.text);
    final rRingValue = _parse(rRing.text);
    final rPinkyValue = _parse(rPinky.text);
    return NailDimensions(
      lThumb: lThumbValue,
      lIndex: lIndexValue,
      lMiddle: lMiddleValue,
      lRing: lRingValue,
      lPinky: lPinkyValue,
      rThumb: rThumbValue,
      rIndex: rIndexValue,
      rMiddle: rMiddleValue,
      rRing: rRingValue,
      rPinky: rPinkyValue,
      lThumbNfc: _isNfcSelected('lThumb', lThumbValue),
      lIndexNfc: _isNfcSelected('lIndex', lIndexValue),
      lMiddleNfc: _isNfcSelected('lMiddle', lMiddleValue),
      lRingNfc: _isNfcSelected('lRing', lRingValue),
      lPinkyNfc: _isNfcSelected('lPinky', lPinkyValue),
      rThumbNfc: _isNfcSelected('rThumb', rThumbValue),
      rIndexNfc: _isNfcSelected('rIndex', rIndexValue),
      rMiddleNfc: _isNfcSelected('rMiddle', rMiddleValue),
      rRingNfc: _isNfcSelected('rRing', rRingValue),
      rPinkyNfc: _isNfcSelected('rPinky', rPinkyValue),
    );
  }

  void _emit() {
    if (_isSyncingFromParent) return;
    _pruneIneligibleNfcSelections();
    final updated = NailPreferences(
      dimensions: _currentDims(),
      shape: _shape,
      length: _length,
    );
    widget.onChanged(updated);
    if (mounted) setState(() {});
  }

  void _syncFromInitial(NailPreferences next) {
    final d = next.dimensions;
    _isSyncingFromParent = true;
    try {
      lThumb.text = _t(d.lThumb);
      lIndex.text = _t(d.lIndex);
      lMiddle.text = _t(d.lMiddle);
      lRing.text = _t(d.lRing);
      lPinky.text = _t(d.lPinky);

      rThumb.text = _t(d.rThumb);
      rIndex.text = _t(d.rIndex);
      rMiddle.text = _t(d.rMiddle);
      rRing.text = _t(d.rRing);
      rPinky.text = _t(d.rPinky);

      _shape = _normalizeShape(next.shape);
      _length = _normalizeLength(next.length);
      _syncNfcSelectionsFromDimensions(d);
    } finally {
      _isSyncingFromParent = false;
    }
  }

  String _normalizeShape(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return '';
    for (final shape in nailShapes) {
      if (shape.toLowerCase() == normalized.toLowerCase()) {
        return shape;
      }
    }
    return '';
  }

  NailLength _normalizeLength(NailLength length) {
    if (_supportedLengths.contains(length)) return length;
    return NailLength.none;
  }

  Future<void> _handleDimensionDone({
    required String semanticLabel,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) async {
    final raw = controller.text.trim();
    final parsed = _parse(raw);
    final spokenValue = parsed == null
        ? (raw.isEmpty ? 'No value entered' : raw)
        : '${parsed.toStringAsFixed(2)} millimeters';

    // Hide the keyboard without allowing the default "Done" action to move
    // focus away from the current dimension field.
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    if (!mounted) return;

    FocusScope.of(context).requestFocus(focusNode);

    SemanticsService.sendAnnouncement(
      View.of(context),
      '$semanticLabel, $spokenValue',
      Directionality.of(context),
    );

    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 110));
    if (!mounted) return;

    FocusScope.of(context).requestFocus(focusNode);
    focusNode.context
        ?.findRenderObject()
        ?.sendSemanticsEvent(FocusSemanticEvent());

    // One small retry helps TalkBack retain the field after the IME closes.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    FocusScope.of(context).requestFocus(focusNode);
    focusNode.context
        ?.findRenderObject()
        ?.sendSemanticsEvent(FocusSemanticEvent());
  }

  void _dismissDimensionKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  InputDecoration _miniDec() => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: widget.useBlackModalStyle ? AppColors.blackCat : AppColors.snow,
    hintText: '0.0',
    hintStyle: TextStyle(
      fontSize: _hintFs,
      color: AppColors.blackCat.withValues(alpha: 0.35),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(
        color:
            widget.nailDimensionBorderColor ??
            (widget.useBlackModalStyle
                ? AppColors.blackCat
                : AppColors.blackCat.withValues(alpha: 0.35)),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(
        color:
            widget.nailDimensionBorderColor ??
            (widget.useBlackModalStyle
                ? AppColors.blackCat
                : AppColors.blackCat.withValues(alpha: 0.35)),
        width: 1.6,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final dims = _currentDims();

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
      padding: widget.showOuterContainer
          ? const EdgeInsets.fromLTRB(16, 16, 16, 14)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: widget.showOuterContainer
            ? (widget.useBlackModalStyle ? AppColors.blackCat : AppColors.snow)
            : Colors.transparent,
        borderRadius: BorderRadius.zero,
        border: widget.showOuterContainer
            ? Border.all(
                color:
                    widget.nailDimensionBorderColor ??
                    (widget.useBlackModalStyle
                        ? AppColors.blackCat
                        : AppColors.blackCat.withValues(alpha: 0.35)),
              )
            : null,
        boxShadow: widget.showOuterContainer
            ? [
                BoxShadow(
                  color: AppColors.blackCat.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            sortKey: OrdinalSortKey(1),
            label: 'Nail Dimension in millimeters, required',
            child: const ExcludeSemantics(
              child: Text(
                'Nail Dimension (in mm) *',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.blackCat,
                  fontFamily: 'Arialbold',
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          if (widget.showNfcOptions) ...[
            Semantics(
              sortKey: const OrdinalSortKey(2),
              label:
                  'NFC eligible designs marked with this checkbox can be upgraded with an NFC chip',
              child: ExcludeSemantics(
                child: Text(
                  'NFC Eligible Designs marked with this checkbox can be upgraded with an NFC chip',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blackCat.withValues(alpha: 0.70),
                    height: 1.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          Semantics(
            sortKey: const OrdinalSortKey(3),
            label: 'Filled ${dims.filledCount} of 10',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Text(
                    'Filled',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.blackCat,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '${dims.filledCount}/10',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.blackCat,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Semantics(
            header: true,
            sortKey: OrdinalSortKey(4),
            label: 'Left Hand',
            child: const ExcludeSemantics(
              child: Center(
                child: Text(
                  'Left Hand',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    fontFamily: 'Arialbold',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FingerRow(
            semanticOrderStart: 5,
            inputDecoration: _miniDec,
            showDimensionImages: widget.showDimensionImages,
            showNfcOptions: widget.showNfcOptions,
            nfcSelections: _nfcSelections,
            valueFor: _parse,
            onNfcChanged: (key, selected) {
              setState(() {
                if (selected) {
                  _nfcSelections.add(key);
                } else {
                  _nfcSelections.remove(key);
                }
              });
              _emit();
            },
            onDimensionDone: (label, controller, focusNode) =>
                _handleDimensionDone(
                  semanticLabel: label,
                  controller: controller,
                  focusNode: focusNode,
                ),
            items: [
              _FingerItemData(
                'lThumb',
                'Thumb',
                'Left hand thumb nail dimension in millimeters',
                lThumb,
                lThumbFocus,
              ),
              _FingerItemData(
                'lIndex',
                'Index',
                'Left hand index nail dimension in millimeters',
                lIndex,
                lIndexFocus,
              ),
              _FingerItemData(
                'lMiddle',
                'Middle',
                'Left hand middle nail dimension in millimeters',
                lMiddle,
                lMiddleFocus,
              ),
              _FingerItemData(
                'lRing',
                'Ring',
                'Left hand ring nail dimension in millimeters',
                lRing,
                lRingFocus,
              ),
              _FingerItemData(
                'lPinky',
                'Pinky',
                'Left hand pinky nail dimension in millimeters',
                lPinky,
                lPinkyFocus,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Semantics(
            header: true,
            sortKey: OrdinalSortKey(10),
            label: 'Right Hand',
            child: const ExcludeSemantics(
              child: Center(
                child: Text(
                  'Right Hand',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    fontFamily: 'Arialbold',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FingerRow(
            semanticOrderStart: 11,
            inputDecoration: _miniDec,
            showDimensionImages: widget.showDimensionImages,
            showNfcOptions: widget.showNfcOptions,
            nfcSelections: _nfcSelections,
            valueFor: _parse,
            onNfcChanged: (key, selected) {
              setState(() {
                if (selected) {
                  _nfcSelections.add(key);
                } else {
                  _nfcSelections.remove(key);
                }
              });
              _emit();
            },
            onDimensionDone: (label, controller, focusNode) =>
                _handleDimensionDone(
                  semanticLabel: label,
                  controller: controller,
                  focusNode: focusNode,
                ),
            items: [
              _FingerItemData(
                'rThumb',
                'Thumb',
                'Right hand thumb nail dimension in millimeters',
                rThumb,
                rThumbFocus,
              ),
              _FingerItemData(
                'rIndex',
                'Index',
                'Right hand index nail dimension in millimeters',
                rIndex,
                rIndexFocus,
              ),
              _FingerItemData(
                'rMiddle',
                'Middle',
                'Right hand middle nail dimension in millimeters',
                rMiddle,
                rMiddleFocus,
              ),
              _FingerItemData(
                'rRing',
                'Ring',
                'Right hand ring nail dimension in millimeters',
                rRing,
                rRingFocus,
              ),
              _FingerItemData(
                'rPinky',
                'Pinky',
                'Right hand pinky nail dimension in millimeters',
                rPinky,
                rPinkyFocus,
              ),
            ],
          ),

          const SizedBox(height: 18),

          Semantics(
            header: true,
            sortKey: OrdinalSortKey(17),
            label: 'Choose Your Nail Shape',
            onDidGainAccessibilityFocus: _dismissDimensionKeyboard,
            child: const ExcludeSemantics(
              child: Text(
                'Choose Your Nail Shape *',
                style: TextStyle(fontSize: _titleFs, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            container: true,
            explicitChildNodes: true,
            sortKey: OrdinalSortKey(18),
            child: SizedBox(
              height: 162,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: List<Widget>.generate(
                      nailShapes.length,
                      (i) {
                        final s = nailShapes[i];
                        final selected = s == _shape;

                        return Padding(
                          padding: EdgeInsets.only(
                            right: i == nailShapes.length - 1 ? 0 : 12,
                          ),
                          child: _ShapeCard(
                            semanticOrder: i.toDouble(),
                            label: s,
                            imageAsset: _shapeImage(s),
                            selected: selected,
                            useBlackModalStyle: widget.useBlackModalStyle,
                            onTap: () {
                              setState(() => _shape = s);
                              _emit();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          Semantics(
            header: true,
            sortKey: OrdinalSortKey(30),
            label: 'Choose Your Nail Length',
            child: const ExcludeSemantics(
              child: Text(
                'Choose Your Nail Length *',
                style: TextStyle(fontSize: _titleFs, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Semantics(
            container: true,
            explicitChildNodes: true,
            sortKey: OrdinalSortKey(31),
            child: SizedBox(
              height: 158,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: List<Widget>.generate(
                      _supportedLengths.length,
                      (i) {
                        final len = _supportedLengths[i];
                        final selected = _length == len;

                        return Padding(
                          padding: EdgeInsets.only(
                            right: i == _supportedLengths.length - 1 ? 0 : 12,
                          ),
                          child: _LengthImageCard(
                            semanticOrder: i.toDouble(),
                            title: _lengthTitle(len),
                            imageAsset: _lengthImage(len),
                            selected: selected,
                            useBlackModalStyle: widget.useBlackModalStyle,
                            onTap: () {
                              setState(() => _length = len);
                              _emit();
                            },
                            subtitle: '',
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// ---------------- UI helpers reused ----------------

class _FingerItemData {
  final String keyName;
  final String label;
  final String semanticLabel;
  final TextEditingController controller;
  final FocusNode focusNode;

  const _FingerItemData(
    this.keyName,
    this.label,
    this.semanticLabel,
    this.controller,
    this.focusNode,
  );
}

class _FingerRow extends StatelessWidget {
  const _FingerRow({
    required this.semanticOrderStart,
    required this.items,
    required this.inputDecoration,
    required this.showDimensionImages,
    required this.showNfcOptions,
    required this.nfcSelections,
    required this.valueFor,
    required this.onNfcChanged,
    required this.onDimensionDone,
  });

  final double semanticOrderStart;
  final List<_FingerItemData> items;
  final InputDecoration Function() inputDecoration;
  final bool showDimensionImages;
  final bool showNfcOptions;
  final Set<String> nfcSelections;
  final double? Function(String value) valueFor;
  final void Function(String key, bool selected) onNfcChanged;
  final Future<void> Function(
    String semanticLabel,
    TextEditingController controller,
    FocusNode focusNode,
  ) onDimensionDone;

  bool _isNfcEligible(TextEditingController controller) {
    if (!showNfcOptions) return false;
    final value = valueFor(controller.text);
    return value != null && value.isFinite && value >= 8;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      sortKey: OrdinalSortKey(semanticOrderStart),
      child: Row(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final f = entry.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == items.length - 1 ? 0 : 6,
              ),
              child: _FingerInput(
              // Sort locally inside this hand's semantics group.
              semanticOrder: index.toDouble(),
              nfcSemanticOrder: (items.length + index).toDouble(),
              label: f.label,
              semanticLabel: f.semanticLabel,
              nfcSemanticLabel: f.semanticLabel.replaceFirst(
                ' nail dimension in millimeters',
                ' NFC chip checkbox',
              ),
              controller: f.controller,
              focusNode: f.focusNode,
              inputDecoration: inputDecoration,
              onDimensionDone: () => onDimensionDone(
                f.semanticLabel,
                f.controller,
                f.focusNode,
              ),
              showDimensionImages: showDimensionImages,
              showNfc: _isNfcEligible(f.controller),
              nfcSelected: nfcSelections.contains(f.keyName),
              onNfcChanged: (selected) => onNfcChanged(f.keyName, selected),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FingerInput extends StatelessWidget {
  const _FingerInput({
    required this.semanticOrder,
    required this.nfcSemanticOrder,
    required this.label,
    required this.semanticLabel,
    required this.nfcSemanticLabel,
    required this.controller,
    required this.focusNode,
    required this.inputDecoration,
    required this.onDimensionDone,
    required this.showDimensionImages,
    required this.showNfc,
    required this.nfcSelected,
    required this.onNfcChanged,
  });

  final double semanticOrder;
  final double nfcSemanticOrder;
  final String label;
  final String semanticLabel;
  final String nfcSemanticLabel;
  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration Function() inputDecoration;
  final VoidCallback onDimensionDone;
  final bool showDimensionImages;
  final bool showNfc;
  final bool nfcSelected;
  final ValueChanged<bool> onNfcChanged;

  @override
  Widget build(BuildContext context) {
    void updateNfcSelection(bool selected) {
      onNfcChanged(selected);
      final textDirection = Directionality.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        SemanticsService.sendAnnouncement(
          View.of(context),
          '$nfcSemanticLabel, ${selected ? 'checked' : 'not checked'}',
          textDirection,
        );
      });
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: SizedBox(
            height: 18,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackCat,
                  fontFamily: 'Arialbold',
                ),
              ),
            ),
          ),
          ),
          const SizedBox(height: 8),

          if (showDimensionImages) ...[
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.asset(
                'assets/images/nail_dimension.png',
                height: 78,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 140,
                errorBuilder: (_, _, _) {
                  return Container(
                    height: 78,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.blackCat.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      size: 18,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

          SizedBox(
            height: 40,
            child: MergeSemantics(
              child: Semantics(
                sortKey: OrdinalSortKey(semanticOrder),
                label: semanticLabel,
                value: controller.text.trim().isEmpty
                    ? 'Not entered'
                    : '${controller.text.trim()} millimeters',
                textField: true,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: false,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  // Suppress EditableText's default Done behavior, which
                  // otherwise unfocuses the field and can send TalkBack to
                  // the modal Close button.
                  onEditingComplete: () {},
                  onSubmitted: (_) => onDimensionDone(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: inputDecoration(),
                  inputFormatters: <TextInputFormatter>[
                    NailDimensionTextInputFormatter(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Keep this row height for every finger.
          // If a nail is not NFC eligible, the hidden placeholder prevents
          // the mm label from jumping upward.
          SizedBox(
            height: 24,
            child: showNfc
                ? Semantics(
                    sortKey: OrdinalSortKey(nfcSemanticOrder),
                    label: nfcSemanticLabel,
                    checked: nfcSelected,
                    onTap: () => updateNfcSelection(!nfcSelected),
                    child: ExcludeSemantics(
                      child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Transform.scale(
                          scale: 0.68,
                          child: Checkbox(
                            value: nfcSelected,
                            onChanged: (checked) =>
                                updateNfcSelection(checked ?? false),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            activeColor: AppColors.blackCat,
                            checkColor: AppColors.snow,
                          ),
                        ),
                      ),
                      const SizedBox(width: 1),
                      const Text(
                        'NFC',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blackCat,
                        ),
                      ),
                    ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 2),
          const ExcludeSemantics(
            child: Text(
              'mm',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.blackCat),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShapeCard extends StatelessWidget {
  const _ShapeCard({
    required this.semanticOrder,
    required this.label,
    required this.imageAsset,
    required this.selected,
    required this.useBlackModalStyle,
    required this.onTap,
  });

  final double semanticOrder;
  final String label;
  final String imageAsset;
  final bool selected;
  final bool useBlackModalStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = useBlackModalStyle
        ? AppColors.blackCat.withValues(alpha: 0.35)
        : AppColors.snow;
    final border = useBlackModalStyle
        ? AppColors.blackCat
        : (selected
              ? AppColors.blackCat
              : AppColors.blackCat.withValues(alpha: 0.10));

    return Semantics(
      sortKey: OrdinalSortKey(semanticOrder),
      button: true,
      label: 'Nail shape: $label',
      selected: selected,
      child: ExcludeSemantics(
        child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        width: 108,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: border, width: selected ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Container(
              height: 108,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.snow,
                borderRadius: BorderRadius.zero,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Image.asset(
                  imageAsset,
                  fit: BoxFit.contain,
                  cacheWidth: 240,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.front_hand_outlined,
                    size: 24,
                    color: useBlackModalStyle
                        ? AppColors.blackCat
                        : (selected
                              ? AppColors.blackCat
                              : AppColors.blackCat.withValues(alpha: 0.55)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackCat.withValues(alpha: 0.85),
                    height: 1.15,
                  ),
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
}

String _lengthTitle(NailLength l) {
  switch (l) {
    case NailLength.none:
      return 'Select';
    case NailLength.xlLong:
      return 'Extra Short';
    case NailLength.short:
      return 'Short';
    case NailLength.medium:
      return 'Medium';
    case NailLength.long:
      return 'Long';
    case NailLength.extraLong:
      return 'Extra Long';
  }
}

/*String _lengthSubtitle(NailLength l) {
  switch (l) {
    case NailLength.none:
      return '';
    case NailLength.short:
      return 'Just past tip';
    case NailLength.medium:
      return 'Classic';
    case NailLength.long:
      return 'Extended';
    case NailLength.extraLong:
      return 'Statement';
    case NailLength.xlLong:
      return 'Maximum';
  }
}*/

String _lengthImage(NailLength l) {
  switch (l) {
    case NailLength.none:
      return 'assets/images/Short.png';
    case NailLength.short:
      return 'assets/images/Short.png';
    case NailLength.medium:
      return 'assets/images/Medium.png';
    case NailLength.long:
      return 'assets/images/Long.png';
    case NailLength.extraLong:
      return 'assets/images/Extra_long.png';
    case NailLength.xlLong:
      return 'assets/images/Extra_shot.png';
  }
}

String _shapeImage(String label) {
  switch (label.trim().toLowerCase()) {
    case 'almond':
      return 'assets/images/Almond.png';
    case 'coffin':
      return 'assets/images/Coffin.png';
    case 'square':
      return 'assets/images/Square.png';
    case 'round':
      return 'assets/images/Round.png';
    case 'stiletto':
      return 'assets/images/Stiletto.png';
    case 'oval':
      return 'assets/images/Oval.png';
    default:
      return 'assets/images/Square.png';
  }
}

class _LengthImageCard extends StatelessWidget {
  const _LengthImageCard({
    required this.semanticOrder,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.selected,
    required this.useBlackModalStyle,
    required this.onTap,
  });

  final double semanticOrder;
  final String title;
  final String subtitle;
  final String imageAsset;
  final bool selected;
  final bool useBlackModalStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = useBlackModalStyle
        ? AppColors.blackCat.withValues(alpha: 0.35)
        : AppColors.snow;
    final border = useBlackModalStyle
        ? AppColors.blackCat
        : (selected
              ? AppColors.blackCat
              : AppColors.blackCat.withValues(alpha: 0.10));

    return Semantics(
      sortKey: OrdinalSortKey(semanticOrder),
      button: true,
      label: 'Nail length: $title',
      selected: selected,
      child: ExcludeSemantics(
        child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        width: 148,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: border, width: selected ? 1.6 : 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.blackCat.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.asset(
                imageAsset,
                height: 108,
                width: double.infinity,
                fit: BoxFit.contain,
                cacheWidth: 400,
                errorBuilder: (_, _, _) => Container(
                  height: 108,
                  decoration: BoxDecoration(
                    color: AppColors.blackCat.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.zero,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackCat.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),

            /*const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.blackCat.withValues(alpha: 0.60),
                height: 1.15,
              ),
            ),*/
          ],
        ),
      ),
        ),
      ),
    );
  }
}
