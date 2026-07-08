import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../models/client_profile_models.dart';
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
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NailPreferencesInlineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldDims = oldWidget.initial.dimensions;
    final nextDims = widget.initial.dimensions;
    final sameDims =
        oldDims.lThumb == nextDims.lThumb &&
        oldDims.lIndex == nextDims.lIndex &&
        oldDims.lMiddle == nextDims.lMiddle &&
        oldDims.lRing == nextDims.lRing &&
        oldDims.lPinky == nextDims.lPinky &&
        oldDims.rThumb == nextDims.rThumb &&
        oldDims.rIndex == nextDims.rIndex &&
        oldDims.rMiddle == nextDims.rMiddle &&
        oldDims.rRing == nextDims.rRing &&
        oldDims.rPinky == nextDims.rPinky &&
        oldDims.lThumbNfc == nextDims.lThumbNfc &&
        oldDims.lIndexNfc == nextDims.lIndexNfc &&
        oldDims.lMiddleNfc == nextDims.lMiddleNfc &&
        oldDims.lRingNfc == nextDims.lRingNfc &&
        oldDims.lPinkyNfc == nextDims.lPinkyNfc &&
        oldDims.rThumbNfc == nextDims.rThumbNfc &&
        oldDims.rIndexNfc == nextDims.rIndexNfc &&
        oldDims.rMiddleNfc == nextDims.rMiddleNfc &&
        oldDims.rRingNfc == nextDims.rRingNfc &&
        oldDims.rPinkyNfc == nextDims.rPinkyNfc;
    final sameMeta =
        oldWidget.initial.shape == widget.initial.shape &&
        oldWidget.initial.length == widget.initial.length;
    if (sameDims && sameMeta) return;
    _syncFromInitial(widget.initial);
  }

  String _t(double? v) {
    if (v == null) return '';
    if (!v.isFinite) return '';
    return v.toStringAsFixed(1);
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

    return Container(
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
          const Text(
            'Nail Dimension (in mm) *',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.blackCat,
              fontFamily: 'Arialbold',
            ),
          ),
          const SizedBox(height: 14),

          if (widget.showNfcOptions) ...[
            Text(
              'NFC Eligible Designs marked with this checkbox can be upgraded with an NFC chip',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.blackCat.withValues(alpha: 0.70),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
          ],

          Row(
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

          const SizedBox(height: 16),

          const Center(
            child: Text(
              'Left Hand',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                fontFamily: 'Arialbold',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FingerRow(
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
            items: [
              _FingerItemData('lThumb', 'Thumb', lThumb),
              _FingerItemData('lIndex', 'Index', lIndex),
              _FingerItemData('lMiddle', 'Middle', lMiddle),
              _FingerItemData('lRing', 'Ring', lRing),
              _FingerItemData('lPinky', 'Pinky', lPinky),
            ],
          ),

          const SizedBox(height: 16),

          const Center(
            child: Text(
              'Right Hand',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                fontFamily: 'Arialbold',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FingerRow(
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
            items: [
              _FingerItemData('rThumb', 'Thumb', rThumb),
              _FingerItemData('rIndex', 'Index', rIndex),
              _FingerItemData('rMiddle', 'Middle', rMiddle),
              _FingerItemData('rRing', 'Ring', rRing),
              _FingerItemData('rPinky', 'Pinky', rPinky),
            ],
          ),

          const SizedBox(height: 18),

          const Text(
            'Choose Your Nail Shape *',
            style: TextStyle(fontSize: _titleFs, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 178,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: nailShapes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final s = nailShapes[i];
                  final selected = s == _shape;

                  return _ShapeCard(
                    label: s,
                    imageAsset: _shapeImage(s),
                    selected: selected,
                    useBlackModalStyle: widget.useBlackModalStyle,
                    onTap: () {
                      setState(() => _shape = s);
                      _emit();
                    },
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'Choose Your Nail Length *',
            style: TextStyle(fontSize: _titleFs, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),

          SizedBox(
            height: 158,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _supportedLengths.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final list = _supportedLengths;
                  final len = list[i];
                  final selected = _length == len;

                  return _LengthImageCard(
                    title: _lengthTitle(len),
                    //subtitle: _lengthSubtitle(len),
                    imageAsset: _lengthImage(len),
                    selected: selected,
                    useBlackModalStyle: widget.useBlackModalStyle,
                    onTap: () {
                      setState(() => _length = len);
                      _emit();
                    },
                    subtitle: '',
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

}

/// ---------------- UI helpers reused ----------------

class _FingerItemData {
  final String keyName;
  final String label;
  final TextEditingController controller;
  const _FingerItemData(this.keyName, this.label, this.controller);
}

class _FingerRow extends StatelessWidget {
  const _FingerRow({
    required this.items,
    required this.inputDecoration,
    required this.showDimensionImages,
    required this.showNfcOptions,
    required this.nfcSelections,
    required this.valueFor,
    required this.onNfcChanged,
  });

  final List<_FingerItemData> items;
  final InputDecoration Function() inputDecoration;
  final bool showDimensionImages;
  final bool showNfcOptions;
  final Set<String> nfcSelections;
  final double? Function(String value) valueFor;
  final void Function(String key, bool selected) onNfcChanged;

  bool _isNfcEligible(TextEditingController controller) {
    if (!showNfcOptions) return false;
    final value = valueFor(controller.text);
    return value != null && value.isFinite && value >= 8;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((f) {
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _FingerInput(
              label: f.label,
              controller: f.controller,
              inputDecoration: inputDecoration,
              showDimensionImages: showDimensionImages,
              showNfc: _isNfcEligible(f.controller),
              nfcSelected: nfcSelections.contains(f.keyName),
              onNfcChanged: (selected) => onNfcChanged(f.keyName, selected),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FingerInput extends StatelessWidget {
  const _FingerInput({
    required this.label,
    required this.controller,
    required this.inputDecoration,
    required this.showDimensionImages,
    required this.showNfc,
    required this.nfcSelected,
    required this.onNfcChanged,
  });

  final String label;
  final TextEditingController controller;
  final InputDecoration Function() inputDecoration;
  final bool showDimensionImages;
  final bool showNfc;
  final bool nfcSelected;
  final ValueChanged<bool> onNfcChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
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
          const SizedBox(height: 8),

          if (showDimensionImages) ...[
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.asset(
                'assets/images/nail_dimension.png',
                height: 78,
                width: 68,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return Container(
                    height: 78,
                    width: 68,
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
            child: TextField(
              controller: controller,
              readOnly: false,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              decoration: inputDecoration(),
            ),
          ),
          const SizedBox(height: 4),

          // Keep this row height for every finger.
          // If a nail is not NFC eligible, the hidden placeholder prevents
          // the mm label from jumping upward.
          SizedBox(
            height: 24,
            child: showNfc
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: 0.68,
                        child: Checkbox(
                          value: nfcSelected,
                          onChanged: (checked) =>
                              onNfcChanged(checked ?? false),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          activeColor: AppColors.blackCat,
                          checkColor: AppColors.snow,
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
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 2),
          const Text(
            'mm',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppColors.blackCat),
          ),
        ],
      ),
    );
  }
}

class _ShapeCard extends StatelessWidget {
  const _ShapeCard({
    required this.label,
    required this.imageAsset,
    required this.selected,
    required this.useBlackModalStyle,
    required this.onTap,
  });

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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        width: 118,
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
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.selected,
    required this.useBlackModalStyle,
    required this.onTap,
  });

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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        width: 182,
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
                height: 96,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  height: 96,
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
            const SizedBox(height: 8),
            Center(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackCat.withValues(alpha: 0.85),
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
    );
  }
}
